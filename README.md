# bee-data

Automated nightly sync of your [Bee](https://www.bee.computer/) wearable data to local markdown files, with daily snapshots archived for historical access.

Bee is an AI wearable that captures conversations, facts, todos, and daily summaries. This repo gives you a reliable local copy of all that data so you can build on top of it — search it, feed it to AI tools, or integrate it into your own workflows.

## What it does

- Runs `bee sync` nightly via a macOS LaunchAgent
- Saves current data to `current/` (conversations, daily summaries, facts, todos)
- Archives a dated snapshot to `archive/YYYY-MM-DD/` each night
- Retries automatically (5 attempts with exponential backoff) if the Bee API drops the connection
- Logs everything to `sync.log`

## Data structure

After syncing, your `current/` directory looks like this:

```
current/
  conversations/     # One folder per conversation date, markdown files inside
    2026-04-11/
      conversation-123.md
  daily/             # One folder per day with a daily summary
    2026-04-11/
      summary.md
  facts.md           # All extracted facts about you
  todos.md           # Your captured todos
```

Each night, the entire `current/` directory is also copied to `archive/YYYY-MM-DD/` so you have point-in-time snapshots.

## Setup

### Prerequisites

- macOS (uses LaunchAgent for scheduling and Keychain for auth)
- [Bee CLI](https://www.bee.computer/) (`@beeai/cli`) installed and on your PATH
- A Bee account with an active wearable

### 1. Clone and configure paths

```bash
git clone https://github.com/YOUR_USER/bee-data.git ~/AI/bee-data
chmod +x ~/AI/bee-data/sync.sh
```

> **Note:** The default paths assume `~/AI/bee-data`. If you put it somewhere else, update `BEE_DATA_DIR` at the top of `sync.sh` and the paths in the LaunchAgent plist.

### 2. Authenticate with Bee

```bash
bee login
```

This stores your token in the macOS Keychain. You need to run this from a GUI terminal session (not SSH) because Keychain requires the user's login session context.

Verify it worked:

```bash
bee status
```

### 3. Test the sync

```bash
~/AI/bee-data/sync.sh
```

You should see output like:

```
Bee Sync: 2026-04-12T05:00:02Z
Checking authentication...
Auth OK.
Syncing from Bee... (attempt 1/5)
Synced 673 files to current/.
Archiving to /Users/you/AI/bee-data/archive/2026-04-12/...
Archive complete.
Bee Sync complete: 673 files archived to 2026-04-12
```

### 4. Install the LaunchAgent (nightly automation)

Create `~/Library/LaunchAgents/com.bee.sync.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bee.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-l</string>
        <string>-c</string>
        <string>/Users/YOUR_USER/AI/bee-data/sync.sh</string>
    </array>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USER/AI/bee-data/sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USER/AI/bee-data/sync.log</string>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>23</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

Replace `YOUR_USER` with your macOS username, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.bee.sync.plist
```

To trigger a sync manually at any time:

```bash
launchctl kickstart gui/$(id -u)/com.bee.sync
```

### 5. Verify it's scheduled

```bash
launchctl list | grep bee
```

You should see `com.bee.sync` in the output.

## Troubleshooting

### "Bee auth is stale"

The Keychain token has expired. Re-authenticate from a **GUI terminal** (not SSH):

```bash
bee login
```

Then verify with `bee status`. If you're remoting in, use Screen Sharing or a VNC session — SSH cannot access the login Keychain.

### Socket connection errors

The Bee API occasionally drops connections. The sync script retries up to 5 times with exponential backoff (30s, 60s, 120s, 240s between attempts). If all 5 fail, check:

- Your internet connection
- Whether the Bee API is having issues
- `sync.log` for details

### Sync ran but data looks stale

Check `sync.log` and `.last-sync` for the last successful sync timestamp. If the data hasn't changed, you may not have worn the Bee recently — the sync still succeeds, it just pulls the same data.

## Using with Claude Code

Point Claude Code at this repo or the `current/` directory to give it access to your Bee data:

```bash
cd ~/AI/bee-data
claude
```

Claude can then read your conversations, daily summaries, facts, and todos to help with recall, analysis, or building tools on top of your data.

## Files in this repo

| File | Purpose |
|---|---|
| `sync.sh` | Main sync script with retry logic |
| `AUTH-NOTES.md` | Notes on how Bee CLI auth works with macOS Keychain |
| `.gitignore` | Excludes personal data (`current/`, `archive/`, logs) |
| `README.md` | This file |
