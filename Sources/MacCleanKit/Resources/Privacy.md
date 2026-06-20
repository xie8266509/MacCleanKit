# MacCleanKit Privacy

MacCleanKit scans local file paths and metadata on this Mac to show cleanup candidates.

- No analytics are sent by this prototype.
- No scan results are uploaded.
- Operation logs, size cache, startup backups, and diagnostics are stored locally in `~/Library/Application Support/MacCleanKit`.
- Diagnostics exports are created only when the user clicks Export Diagnostics.
- Automatic updates require a configured Sparkle feed URL and public EdDSA key.

Deleting files moves them to Trash after confirmation.
