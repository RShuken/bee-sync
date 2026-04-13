#!/bin/zsh
set -euo pipefail

# Bee Data Sync Script
# Syncs all Bee wearable data to local archive
# Usage: ~/AI/bee-data/sync.sh

BEE_DATA_DIR="${BEE_DATA_DIR:-$(cd "$(dirname "$0")" && pwd)}"
CURRENT_DIR="$BEE_DATA_DIR/current"
ARCHIVE_DIR="$BEE_DATA_DIR/archive"
LAST_SYNC_FILE="$BEE_DATA_DIR/.last-sync"
TODAY=$(date +%Y-%m-%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "Bee Sync: $NOW"

# Auth check
echo "Checking authentication..."
if ! bee status > /dev/null 2>&1; then
    echo "ERROR: Bee auth is stale. Run bee login interactively to re-authenticate."
    exit 1
fi
echo "Auth OK."

# Staleness check
if [[ -f "$LAST_SYNC_FILE" ]]; then
    LAST_SYNC=$(cat "$LAST_SYNC_FILE")
    LAST_SYNC_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_SYNC" +%s 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    HOURS_SINCE=$(( (NOW_EPOCH - LAST_SYNC_EPOCH) / 3600 ))
    if (( HOURS_SINCE > 36 )); then
        echo "WARNING: Last successful sync was $HOURS_SINCE hours ago ($LAST_SYNC)."
    fi
fi

# Sync from Bee (with retries for transient failures)
MAX_RETRIES=5
RETRY_DELAY=30
SYNC_EXIT=1

for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    echo "Syncing from Bee... (attempt $ATTEMPT/$MAX_RETRIES)"
    bee sync --output "$CURRENT_DIR" 2>&1
    SYNC_EXIT=$?

    if [[ $SYNC_EXIT -eq 0 ]]; then
        break
    fi

    if [[ $ATTEMPT -lt $MAX_RETRIES ]]; then
        echo "Sync failed (exit $SYNC_EXIT). Retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
        RETRY_DELAY=$((RETRY_DELAY * 2))
    fi
done

if [[ $SYNC_EXIT -ne 0 ]]; then
    echo "ERROR: bee sync failed after $MAX_RETRIES attempts (last exit code $SYNC_EXIT)"
    exit $SYNC_EXIT
fi

# Count synced files
FILE_COUNT=$(find "$CURRENT_DIR" -type f | wc -l | tr -d " ")
echo "Synced $FILE_COUNT files to current/."

# Archive today snapshot
echo "Archiving to $ARCHIVE_DIR/$TODAY/..."
mkdir -p "$ARCHIVE_DIR/$TODAY"
rsync -a --delete "$CURRENT_DIR/" "$ARCHIVE_DIR/$TODAY/"
echo "Archive complete."

# Update last-sync timestamp
echo "$NOW" > "$LAST_SYNC_FILE"

# Phase 2 hook (placeholder)
# $BEE_DATA_DIR/embed.sh "$ARCHIVE_DIR/$TODAY" 2>&1

echo "Bee Sync complete: $FILE_COUNT files archived to $TODAY"
