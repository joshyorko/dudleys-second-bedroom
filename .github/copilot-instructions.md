# Dudley's Second Bedroom · Copilot Instructions

## Mission Brief
Dudley's Second Bedroom is a custom Universal Blue Fedora Atomic remix with a modular build system, declarative configuration, and a content-versioned first-boot experience. These instructions give Copilot (and you) the canonical project context, required validation steps, and the guardrails needed to propose safe changes.

## Repository Atlas
- `Containerfile`: Multi-stage build definition (`ctx` → `base`) that orchestrates module execution.
- `build_files/`: Home of all build-time modules and utilities.
  - `shared/`: Core platform modules plus `build-base.sh`, which discovers and runs other modules.
  - `desktop/`, `developer/`, `user-hooks/`: Category-specific modules executed after `shared/`.
  - `shared/utils/`: Bash helpers that are sourced (not executed) by modules.
- `system_files/`: Files and directories copied verbatim into the image before modules run.
- `custom_wallpapers/`: Wallpaper assets included in the image and tracked for content versioning.
- `packages.json`: Declarative package install/remove lists consumed by `build_files/shared/package-install.sh`.
- `tests/`: Validation scripts (`validate-modules.sh`, `validate-packages.sh`, `run-all-tests.sh`, etc.).
- `docs/` and `specs/`: Architecture references, implementation plans, and design notes.

## Build Pipeline Overview
The Containerfile stages look like this:

1. **`ctx` stage** – Copies the repository into `/ctx` and sets up core tooling.
2. **`base` stage** – Sources `/ctx/build_files/shared/build-base.sh`, which:
	- Runs shared modules first, then desktop, developer, and user-hooks in alphabetical order.
	- Maintains a consistent working directory (`/usr/share/dudley`) for modules.
3. **Manifest & Signing** – `generate-manifest.sh` computes content hashes and writes `/etc/dudley/build-manifest.json`, then optional signing happens.

Keep modules idempotent and avoid hard-coded paths outside `/ctx` or the image filesystem.

## Modular Build System Essentials

### Module Discovery
- Modules are auto-discovered by path and filename; only scripts with execute permission (`chmod +x`) are run.
- Execution order is alphabetical within each category directory. Prefix filenames with numbers (e.g., `10-setup.sh`) if strict ordering is required.

### Module Header Contract
Every module **must** start with the standard header followed by `set -euo pipefail` (optionally `set -x` while debugging):

```
#!/usr/bin/env bash
# Purpose: <succinct summary>
# Category: <shared|desktop|developer|user-hooks>
# Dependencies: <comma-separated module names or 'none'>
# Parallel-Safe: <yes|no>
# Cache-Friendly: <yes|no>
set -euo pipefail
```

The header is validated by `tests/validate-modules.sh`. Missing or malformed fields will fail the check.

### Logging & Exit Codes
- Log messages should use `[MODULE:category/name]` as a prefix for consistent build logs.
- Return `exit 2` to signal an intentional skip (e.g., dependency unmet); the orchestrator interprets this as a non-error.
- Any other non-zero exit code is treated as failure and halts the build.

### Utilities
- Source helpers from `build_files/shared/utils/*.sh` (`source /ctx/build_files/shared/utils/<file>.sh`).
- Utilities are not executable scripts; never call them via subshell.
- Add new helper functions to utilities instead of duplicating logic across modules.

## Content Versioning System

### How Hashes Are Computed
- `build_files/shared/utils/generate-manifest.sh` calls `compute_content_hash` across tracked assets (user hooks, wallpapers, configuration files).
- Hashes are stored in `/etc/dudley/build-manifest.json` and embedded into hook filenames.

### Hook Authoring
- Hook scripts live in `build_files/user-hooks/` but are installed into `/usr/share/ublue-os/user-setup.hooks.d/` during build.
- Use the `__CONTENT_VERSION__` placeholder inside hook filenames or bodies where versioning is required; the manifest stage replaces it with the computed hash.
- When adding new files that should influence a hook's hash, extend the dependency list in `generate-manifest.sh` and ensure the Containerfile replacement block knows how to substitute the hash.
- Hooks run on **first boot**; keep them idempotent and guard any operations that should only occur once.

## Declarative Configuration Sources
- **Packages:** Edit `packages.json` to add/remove RPMs. Always run `just validate-packages` after modifications to catch duplicates or conflicts.
- **Flatpaks:** Managed via `flatpaks/system-flatpaks*.list`. Modules consume these lists during build.
- **VS Code Extensions:** Declared in `vscode-extensions.list`. Blank lines and `#` comments are ignored.
- **Wallpapers:** Any image added to `custom_wallpapers/` automatically factors into the wallpaper hook hash.

## Mandatory Validation Workflow
Treat these commands as non-negotiable whenever relevant files change:

1. `just check` – Runs linting, formatting validation, package checks, and module validation.
2. Run targeted scripts when working in specific areas:
	- `just lint` and `just format` after touching shell scripts.
	- `tests/validate-modules.sh` after adding or modifying a module.
	- `tests/run-all-tests.sh` or individual scripts (`test-content-versioning.sh`, `test-manifest-generation.sh`) when altering manifest logic or hooks.
	- `tests/verify-build.sh <image:tag>` after producing a build to confirm expected OSTree artifacts.

Never declare work complete if `just check` (or any required validation) reports errors.

## Testing & Build Commands
- **Build image:** `just build`
- **Build bootable media:** `just build-iso`, `just build-qcow2`, `just build-raw`
- **Full test sweep:** `tests/run-all-tests.sh`
- **Content versioning regression:** `tests/test-content-versioning.sh`
- **Manifest verification:** `tests/test-manifest-generation.sh`

Always inspect build logs for warnings even if commands exit successfully.

## Shell Scripting Standards
- Use `#!/usr/bin/env bash` shebangs alongside `set -euo pipefail`.
- Prefer functions over inline command sequences when logic is reusable.
- Quote variable expansions (`"${VAR}"`) and use `[[ ... ]]` for conditionals.
- Use `readarray` and `mapfile` instead of subshell loops when parsing lists.
- Run `shellcheck` (via `just lint`) to catch common mistakes and `shfmt` (via `just format`) to maintain consistent formatting.
- Place temporary files under `/tmp` and remove them before exit to keep builds clean.

## Copilot Instruction Layers
- **Global instructions (this file):** Repository-wide guidance.
- **Domain instructions:** Lives in `.github/instructions/*.instructions.md` and cover specific topics such as module contracts, content versioning, and shell scripting best practices.
- **Task prompts:** Lives in `.github/prompts/*.prompt.md` and provide structured workflows for common tasks (e.g., scaffolding a module, validating the build).
- **Specialized agents:** Added as needed under `.github/agents/` with explicit tool requirements.

When proposing changes, reference the appropriate instruction or prompt so that downstream agents inherit the right context automatically.

## Observability & Troubleshooting
- Run `/usr/bin/dudley-build-info` inside the finished image to inspect build metadata, including content hashes and source commit SHAs.
- Build logs surface with the `[MODULE:category/name]` prefix—search for it when diagnosing failures.
- For hook issues, compare the manifest hash with the hook's embedded version to ensure they match.

## Key Reminders
- Keep modules idempotent; they may rerun during incremental builds.
- Avoid mutating global state across modules—write shared data to predictable locations.
- Prefer declarative inputs (`packages.json`, lists, configs) over imperative package installs inside modules.
- Document complex behavior in `docs/` or `specs/` to preserve tribal knowledge.
- When in doubt, run the relevant validation script before pushing changes.
