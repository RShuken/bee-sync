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

### 2. Log in to Bee

```bash
bee login
```

This opens your browser for authentication and stores the token in your macOS Keychain.

Verify it worked:

```bash
bee status
```

### 3. Clone this repo

```bash
git clone https://github.com/RShuken/bee-sync.git ~/bee-sync
cd ~/bee-sync
chmod +x sync.sh
```

### 4. Run your first sync

The script auto-detects its own directory, so no path configuration needed. Just run it:

```bash
./sync.sh
```

You should see:

```
Bee Sync: 2026-04-12T05:00:02Z
Checking authentication...
Auth OK.
Syncing from Bee... (attempt 1/5)
Synced 673 files to current/.
Archiving to /Users/you/bee-sync/archive/2026-04-12/...
Archive complete.
Bee Sync complete: 673 files archived to 2026-04-12
```

### 5. Set up nightly automation

Copy the included LaunchAgent plist to your LaunchAgents directory:

```bash
cp com.bee.sync.plist ~/Library/LaunchAgents/
```

Edit it to match your username and paths:

```bash
nano ~/Library/LaunchAgents/com.bee.sync.plist
```

Replace every instance of `YOUR_USER` with your macOS username (run `whoami` if unsure).

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.bee.sync.plist
```

Verify it's scheduled:

```bash
launchctl list | grep bee
```

The sync runs at **11:00 PM local time** every night. To change the time, edit the `Hour` and `Minute` values in the plist.

### 6. Trigger a sync manually (anytime)

```bash
launchctl kickstart gui/$(id -u)/com.bee.sync
```

Or just run the script directly:

```bash
~/bee-sync/sync.sh
```

## How the retry logic works

The Bee API occasionally drops socket connections mid-sync. Instead of failing silently and leaving you with stale data, the script:

1. Attempts the sync
2. If it fails, waits 30 seconds and tries again
3. Doubles the wait each time (30s, 60s, 120s, 240s)
4. Gives up after 5 attempts and logs the failure

This handles the transient network issues that would otherwise cause missed days.

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

You can also build tools on top of this — the data is just markdown files.

## Troubleshooting

### "Bee auth is stale"

Your Keychain token has expired. Run `bee login` again from a **GUI terminal session** (Terminal.app, iTerm, etc.). This will not work over SSH because macOS Keychain requires the GUI login session.

If you access your Mac remotely, use Screen Sharing or VNC — not SSH.

### All 5 retry attempts failed

Check `sync.log` for the error details. Common causes:

- **No internet** — the Mac was asleep or offline
- **Bee API outage** — wait and it'll catch up on the next run
- **Auth expired** — check if `bee status` works; re-login if needed

### Missing days in the archive

The archive is named by the date when the sync *runs*, not the date of the data. If a sync fails and the next night succeeds, you'll have a gap in archive folder names but no actual data loss — `current/` always has the latest.

### Sync works manually but not from LaunchAgent

The LaunchAgent runs in the GUI session domain, which is required for Keychain access. Make sure:

1. The plist paths match your actual setup
2. You loaded it with `launchctl load` (not `bootstrap`)
3. The Mac is not asleep at sync time (or enable Power Nap)

## Requirements

- macOS (uses LaunchAgent + Keychain)
- [Bee CLI](https://www.bee.computer/) (`@beeai/cli`)
- A Bee account with an active wearable
- Node.js (for the Bee CLI)

## Files

| File | Purpose |
|---|---|
| `sync.sh` | Sync script with retry logic and daily archiving |
| `com.bee.sync.plist` | macOS LaunchAgent for nightly automation |
| `AUTH-NOTES.md` | How Bee CLI auth works with macOS Keychain |

## License

MIT
