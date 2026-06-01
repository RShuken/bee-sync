#!/bin/zsh
set -euo pipefail

# bee-sync setup script
# Run this ONCE from a GUI terminal (Terminal.app, iTerm) to:
#   1. Verify Bee CLI is installed and authenticated
#   2. Cache the Keychain token for non-GUI access (SSH, cron, Claude Code)
#   3. Install the LaunchAgent for nightly syncing
#   4. Run a test sync

BEE_DATA_DIR="${BEE_DATA_DIR:-$(cd "$(dirname "$0")" && pwd)}"
BEE_CONFIG_DIR="${BEE_CONFIG_DIR:-$HOME/.bee}"
BEE_TOKEN_FILE="$BEE_CONFIG_DIR/token-prod"
PLIST_NAME="com.bee.sync"
PLIST_SRC="$BEE_DATA_DIR/$PLIST_NAME.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
echo "=== bee-sync setup ==="
echo ""

# Step 1: Check Bee CLI
echo "[1/5] Checking Bee CLI..."
if ! command -v bee &> /dev/null; then
    echo "ERROR: Bee CLI not found. Install it with: npm install -g @beeai/cli"
    exit 1
fi
echo "  Found: $(bee version 2>&1 || echo 'unknown version')"

# Step 2: Check authentication
echo "[2/5] Checking Bee authentication..."
if ! bee status > /dev/null 2>&1; then
    echo "  Not authenticated. Running 'bee login'..."
    bee login
    if ! bee status > /dev/null 2>&1; then
        echo "ERROR: Authentication failed. Please try 'bee login' manually."
        exit 1
    fi
fi
echo "  Authenticated."

# Step 3: Cache token for non-GUI access
echo "[3/5] Caching token for non-GUI access..."
KEYCHAIN_TOKEN=$(security find-generic-password -s "bee-cli" -a "token:prod" -w 2>&1) || true
if [[ -n "$KEYCHAIN_TOKEN" && "$KEYCHAIN_TOKEN" != *"could not be found"* && "$KEYCHAIN_TOKEN" != *"SecKeychainSearchCopyNext"* ]]; then
    mkdir -p "$BEE_CONFIG_DIR"
    echo -n "$KEYCHAIN_TOKEN" > "$BEE_TOKEN_FILE"
    chmod 600 "$BEE_TOKEN_FILE"
    echo "  Token cached to $BEE_TOKEN_FILE"
else
    echo "  WARNING: Could not extract token from Keychain."
    echo "  The sync will still work from the LaunchAgent (GUI session),"
    echo "  but won't work from SSH or Claude Code without a cached token."
    echo "  If Keychain prompted you, approve access and re-run this script."
fi

# Step 4: Install LaunchAgent
echo "[4/5] Installing LaunchAgent..."
if [[ ! -f "$PLIST_SRC" ]]; then
    echo "ERROR: $PLIST_SRC not found. Are you running this from the bee-sync directory?"
    exit 1
fi

# Generate plist with correct paths
sed "s|__BEE_DATA_DIR__|$BEE_DATA_DIR|g" "$PLIST_SRC" > "$PLIST_DST"
echo "  Installed to $PLIST_DST"

# Unload if already loaded, then load
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "  LaunchAgent loaded (syncs nightly at 11:00 PM)."

# Step 5: Test sync
echo "[5/5] Running test sync..."
echo ""
"$BEE_DATA_DIR/sync.sh"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Your Bee data syncs every night at 11:00 PM."
echo "Manual sync:  $BEE_DATA_DIR/sync.sh"
echo "Force sync:   launchctl kickstart gui/\$(id -u)/$PLIST_NAME"
echo "View logs:    tail -f $BEE_DATA_DIR/sync.log"
