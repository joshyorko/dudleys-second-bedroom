# Dudley's Second Bedroom – AI Agent Playbook

## Architecture at a Glance
- Multi-stage Containerfile (`ctx` → `base`) with `/ctx/build_files/shared/build-base.sh` orchestrating modules in shared → desktop → developer → user-hooks order.
- Modules are auto-discovered; keep scripts in the correct category folder and rely on alphabetical naming for execution order. Utilities under `build_files/shared/utils` are sourced, not executed.

## Module Conventions
- Every module must include the standard header (`Purpose`, `Category`, `Dependencies`, `Parallel-Safe`, etc.) plus `set -euo[x] pipefail`; `tests/validate-modules.sh` enforces this alongside category/path alignment.
- Log with the `[MODULE:category/name]` prefix like `build_files/shared/build-base.sh` does, and exit `2` for intentional skips so the orchestrator can keep going.

## Content Versioning & Hooks
- User hooks live in `build_files/user-hooks` but run at first boot; builds only install them under `/usr/share/ublue-os/user-setup.hooks.d/`.
- Content hashes are computed in `build_files/shared/utils/generate-manifest.sh` via `compute_content_hash`; add new hook dependencies there and extend the placeholder replacement block in the `Containerfile`.
- Hook scripts embed `__CONTENT_VERSION__` placeholders that become hash values; runtime gating relies on Universal Blue’s `version-script`. The resulting manifest ships at `/etc/dudley/build-manifest.json` and feeds the `dudley-build-info` CLI.

## Configuration Data
- `packages.json` drives installs/removals; run `just validate-packages` after edits to catch duplicates or conflicts before building.
- Wallpapers are any images in `custom_wallpapers/`; the wallpaper hook hash includes image bytes, so asset tweaks alone trigger new versions.
- VS Code extensions are declared in `/vscode-extensions.list`; comment lines (`#`) and blanks are ignored when counting extensions for manifest metadata.

## Build & Test Workflow
- Primary validation: `just check` (syntax, lint, package and module checks). Use `just lint` for shellcheck and `just format` for shfmt when touching Bash.
- Build container images with `just build`; it injects `SHA_HEAD_SHORT` so manifests report the source commit. For bootable media use `just build-iso`, `build-qcow2`, or `build-raw`.
- Content-versioning tests live under `tests/`; run `tests/run-all-tests.sh` for the full suite or targeted scripts like `tests/test-content-versioning.sh` and `tests/test-manifest-generation.sh` while iterating.
- After introducing a new module, re-run `tests/validate-modules.sh` and consider `tests/verify-build.sh <image:tag>` to ensure expected OSTree artifacts are present.

## Tips & Integration Points
- The build context is mounted at `/ctx`; avoid hardcoding host paths in modules so they work inside the containerized build.
- Cleanup/signing happen through `build_files/shared/cleanup.sh` and `build_files/shared/signing.sh`; keep heavy operations idempotent to preserve BuildKit caching.
- Runtime overrides (dconf, schemas, wallpapers) are staged under `system_files/`; anything there is copied before modules run, so configure assets in that tree.
- Never hand-edit hook versions—hashes are injected during the manifest stage and surfaced via `/usr/bin/dudley-build-info` for inspection.
