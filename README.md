# bee-sync

A nightly sync for your [bee.computer](https://www.bee.computer/) that just works.

Bee is an AI wearable that captures your conversations, facts, todos, and daily summaries throughout the day. This repo syncs all of that data to local markdown files every night so you own it, can search it, feed it to AI tools, or build on top of it.

## Why

The Bee app is great, but your data lives on their servers. This gives you:

- **A local copy** of everything Bee knows about you, in plain markdown
- **Daily snapshots** so you can see how your data changes over time
- **Resilient syncing** with automatic retries when the Bee API hiccups
- **A foundation to build on** — pipe your data into Claude, embeddings, search, whatever you want

## What you get

After the first sync, your directory looks like this:

```
bee-sync/
  current/
    conversations/        # Markdown files organized by date
      2026-04-11/
        conversation-123.md
    daily/                # Daily summaries from Bee
      2026-04-11/
        summary.md
    facts.md              # Everything Bee has learned about you
    todos.md              # Your captured todos
  archive/
    2026-04-11/           # Nightly snapshot (full copy of current/)
    2026-04-10/
    ...
  sync.log                # Append-only log of every sync run
```

## Quick start

### 1. Install the Bee CLI

```bash
npm install -g @beeai/cli
```

### 2. Clone this repo

```bash
git clone https://github.com/RShuken/bee-sync.git ~/bee-sync
cd ~/bee-sync
```

### 3. Run setup

The setup script handles everything — authentication, token caching, LaunchAgent installation, and a test sync:

```bash
./setup.sh
```

This will:
1. Check that the Bee CLI is installed
2. Log you in to Bee if needed (opens your browser)
3. Cache your auth token so syncing works from any context (SSH, cron, Claude Code)
4. Install a LaunchAgent for nightly syncing at 11:00 PM
5. Run a test sync to make sure everything works

**Important:** Run this from a GUI terminal (Terminal.app, iTerm, etc.) — not over SSH. The initial setup needs access to the macOS Keychain, which requires a GUI session.

That's it. You're done.

## How it works

### Nightly sync

The LaunchAgent runs `sync.sh` every night at 11:00 PM. The script:

1. Checks authentication (Keychain or cached token)
2. Runs `bee sync` to pull all your data into `current/`
3. Copies `current/` to `archive/YYYY-MM-DD/` for a dated snapshot
4. Logs everything to `sync.log`

### Retry logic

The Bee API occasionally drops socket connections mid-sync. Instead of failing and leaving you with stale data, the script:

1. Attempts the sync
2. If it fails, waits 30 seconds and tries again
3. Doubles the wait each time (30s, 60s, 120s, 240s)
4. Gives up after 5 attempts and logs the failure

This handles the transient network issues that would otherwise cause missed days.

### Token caching

Bee CLI stores auth tokens in the macOS Keychain, which only works in GUI sessions. The setup script extracts your token and caches it to `~/.bee/token-prod` so syncing works everywhere — from SSH, Claude Code, or any non-GUI context.

## Manual sync

Trigger a sync anytime:

```bash
~/bee-sync/sync.sh
```

Or through the LaunchAgent:

```bash
launchctl kickstart gui/$(id -u)/com.bee.sync
```

## Using with Claude Code

This is where it gets fun. Point Claude Code at your synced data:

```bash
cd ~/bee-sync
claude
```

Now Claude has access to your conversations, daily summaries, facts, and todos. You can ask things like:

- "What did I talk about last Tuesday?"
- "Summarize my week"
- "What are all the action items I mentioned this month?"
- "What facts does Bee know about me related to work?"

You can also build on top of this — the data is just markdown files.

## Troubleshooting

### Setup says "Could not extract token from Keychain"

macOS may prompt you to allow Keychain access. Look for a system dialog asking for your password. Approve it and re-run `./setup.sh`.

If you're over SSH, you must run setup from a GUI session (Terminal.app, Screen Sharing, VNC).

### Auth expired

Tokens expire periodically. Re-run the setup script from a GUI terminal:

```bash
cd ~/bee-sync
./setup.sh
```

This will re-authenticate and update the cached token.

### All 5 retry attempts failed

Check `sync.log` for error details. Common causes:

- **No internet** — the Mac was asleep or offline
- **Bee API outage** — wait and it'll catch up on the next run
- **Auth expired** — re-run `./setup.sh`

### Missing days in the archive

The archive is named by the date when the sync *runs*, not the date of the data. If a sync fails and the next night succeeds, you'll have a gap in archive folder names but no actual data loss — `current/` always has the latest.

### Sync works manually but not from LaunchAgent

Make sure:

1. You ran `./setup.sh` (it installs the LaunchAgent with correct paths)
2. The Mac is not asleep at sync time (enable Power Nap in System Settings > Energy)
3. Check `sync.log` for errors

## Requirements

- macOS (uses LaunchAgent + Keychain)
- [Bee CLI](https://www.bee.computer/) (`@beeai/cli`)
- A Bee account with an active wearable
- Node.js (for the Bee CLI)

## Files

| File | Purpose |
|---|---|
| `setup.sh` | One-time setup: auth, token caching, LaunchAgent install |
| `sync.sh` | Sync script with retry logic and daily archiving |
| `com.bee.sync.plist` | macOS LaunchAgent template for nightly automation |
| `AUTH-NOTES.md` | Technical notes on how Bee CLI auth works with macOS Keychain |

## License

MIT
