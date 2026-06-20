# Contributing

Thanks for your interest in MacCleanKit.

## Development

```bash
swift build
SKIP_UI_SMOKE=1 Scripts/run-tests.sh
```

For local UI/package verification on macOS:

```bash
Scripts/run-tests.sh
```

## Safety Rules

- Destructive behavior must move items to Trash, never permanently delete files.
- System paths, Apple core apps, running apps, and protected roots must stay blocked by default.
- Cleanup rules must be review-first. Do not default-select user documents, media folders, or protected paths.
- Any new external process call must use timeout protection.

## Pull Requests

- Keep changes focused.
- Update `README.md` or `docs/` when user-facing behavior changes.
- Run the relevant checks before submitting.

