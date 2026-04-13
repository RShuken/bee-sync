# Bee CLI Auth Notes

## Auth type
macOS Keychain (generic password)
- Service: bee-cli
- Account: token:prod
- Keychain: ~/Library/Keychains/login.keychain-db

## Key constraint
Keychain items require GUI session context to access.
SSH and cron CANNOT access the token (error -25308: errSecInteractionNotAllowed).
Solution: Use LaunchAgent (com.bee.sync) which runs in gui/501 domain.

## Re-auth procedure
If sync.sh fails with auth error:
1. SSH into Mini: ssh 4c
2. Open interactive session or use Screen Sharing
3. Run: bee login
4. Follow browser/Apple Sign-In prompts
5. Verify: bee status (from GUI terminal, not SSH)

## On-demand sync trigger (from laptop)
ssh 4c "launchctl kickstart gui/501/com.bee.sync"

## Installed version
@beeai/cli 0.6.0

## Nightly schedule
LaunchAgent: com.bee.sync
Plist: ~/Library/LaunchAgents/com.bee.sync.plist
Schedule: 11:00 PM daily
Log: ~/AI/bee-data/sync.log
