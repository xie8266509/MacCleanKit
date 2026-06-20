# Security Policy

MacCleanKit is a local macOS cleanup utility. Treat file deletion, startup item changes, and permission prompts as security-sensitive areas.

## Reporting

Please report vulnerabilities through GitHub Security Advisories if available, or open a private report with enough detail to reproduce the issue.

## Scope

Security-sensitive issues include:

- Permanent deletion instead of Trash movement.
- Unsafe default-selected cleanup rules.
- Bypassing system path protections.
- Startup item disable/restore corruption.
- Unbounded external process execution.

Do not include personal files, logs, or sensitive paths in public issues.

