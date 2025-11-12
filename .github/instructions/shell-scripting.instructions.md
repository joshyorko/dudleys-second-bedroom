---
description: Bash style, tooling, and safety expectations for Dudley shell scripts
applyTo: **/*.sh
---

# Shell Scripting Standards

## Core Expectations
- Start every script with `#!/usr/bin/env bash` and immediately enable `set -euo pipefail`.
- Prefer explicit functions and descriptive names over long inline command sequences.
- Quote variable expansions (`"${VAR}"`) and use `[[ ... ]]` for conditionals to avoid globbing surprises.
- Use `mapfile`/`readarray` instead of command-substitution loops for reading files.
- When parsing JSON, rely on `jq`; for configuration lists, prefer declarative files over inline arrays.

## Formatting & Tooling
- Run `just format` to apply `shfmt` formatting; the repo standard is 2-space indentation.
- Run `just lint` to execute `shellcheck` and address all warnings unless a false positive is documented.
- Avoid trailing whitespace and keep line length under 120 characters.

## Error Handling
- Wrap risky commands with helpful error messages, e.g., `if ! some_command; then echo "[MODULE:shared/foo] failed"; exit 1; fi`.
- Use temporary files under `/tmp` and clean them up in `trap` handlers when scripts exit.
- Reserve `set -x` for active debugging sessions and remove it before committing.

## Logging Conventions
- Modules: Prefix with `[MODULE:category/name]`.
- Utilities: Prefix with `[UTIL:filename]` when emitting messages.
- Errors: Include actionable hints (e.g., which dependency failed) and next steps.

## Validation Checklist
- `just lint` — static analysis via shellcheck.
- `just format` — formatting via shfmt.
- `just check` — full validation including syntax checks across the project.

## Learnings
- Always quote glob patterns when copying files; unquoted globs yield surprising deletions on empty matches. (1)
- Prefer `[[ -n ${VAR:-} ]]` for checks to avoid unbound variable errors under `set -u`. (1)
- Document environment assumptions (e.g., required binaries) at the top of the script to save debugging time. (1)
