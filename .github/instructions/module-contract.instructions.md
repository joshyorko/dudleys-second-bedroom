---
description: How to author Dudley build modules that comply with the orchestrator contract
applyTo: build_files/**/*.sh
---

# Build Module Contract

## Scope
These instructions apply to any executable script placed under `build_files/` that participates in the modular build pipeline. Utilities under `build_files/shared/utils/` are covered separately.

## Required Header
Every module **must** begin with the standard header, followed immediately by strict error handling:

```
#!/usr/bin/env bash
# Purpose: <what this module configures>
# Category: <shared|desktop|developer|user-hooks>
# Dependencies: <comma-separated module filenames or 'none'>
# Parallel-Safe: <yes|no>
# Cache-Friendly: <yes|no>
set -euo pipefail
```

Keep header values accurate—automation depends on them for scheduling, dependency resolution, and validation. Use `set -x` temporarily while debugging but remove it before committing unless tracing is genuinely required.

## Execution Rules
- Place modules in the directory that matches the declared category; `tests/validate-modules.sh` enforces this mapping.
- Grant execute permission (`chmod +x`) or the orchestrator will skip the script.
- Execution order within a category is alphabetical. Use numeric prefixes (e.g., `20-configure.sh`) to control sequencing when necessary.
- Declare dependencies using filenames (without path). The orchestrator interprets missing dependencies as a signal to skip with exit code `2`.

## Logging & Exit Codes
- Prefix log output with `[MODULE:category/name]` for consistent debugging.
- Return `exit 0` for success, `exit 2` for intentional skips, and reserve all other non-zero values for hard failures.
- Treat warnings as actionable; if a command can fail, guard it and emit context-rich messages.

## Utilities & Reuse
- Source helpers from `/ctx/build_files/shared/utils/*.sh` instead of re-implementing logic.
- Never execute utility files directly—they are meant to be sourced within the current shell.
- Prefer functions for reusable logic; define them near the top of the file and document assumptions.

## Validation Checklist
- Run `tests/validate-modules.sh` after adding or modifying a module.
- Follow up with `just lint` (shellcheck) and `just format` (shfmt) to enforce style and formatting.
- When touching dependencies or cross-module behavior, run `just check` to exercise the full validation suite.

## Learnings
- Always emit `exit 2` when skipping due to unmet dependencies; `exit 0` hides the reason for skipping. (1)
- Utilities do not need execute permissions because they are sourced; setting `+x` can mislead other contributors. (1)
- Parallel-safe modules **must not** mutate shared files or directories without locking; rework the logic if this happens. (1)
