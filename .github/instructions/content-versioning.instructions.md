---
description: Guidance for hook authors and manifest maintainers working with the content hash system
applyTo: build_files/user-hooks/**
---

# Content Versioning Pattern

## Overview
Dudley's first-boot experience is guarded by content hashes that detect meaningful changes across hooks, wallpapers, and configuration payloads. Hashes are generated during the build and substituted into hook filenames and metadata so that the system reruns only when the payload changes.

## Hash Generation
- `build_files/shared/utils/generate-manifest.sh` aggregates all tracked assets and calls `compute_content_hash` to produce deterministic hashes.
- The resulting manifest is written to `/etc/dudley/build-manifest.json` and mirrored in `/usr/share/ublue-os/user-setup.hooks.d/` filenames.
- When adding new assets that should affect a hook's hash, extend the appropriate `compute_content_hash` invocation and ensure the asset is copied into the final image prior to manifest generation.

## Hook Authoring Checklist
- Store hook sources under `build_files/user-hooks/` with executable permissions.
- Embed the `__CONTENT_VERSION__` placeholder anywhere the runtime should receive the hash (commonly in the filename or log output).
- Keep hooks idempotent—they may rerun on recovery boots. Use guard files or system queries before mutating user state.
- When a hook depends on staged assets (e.g., wallpapers), verify that the asset paths align with `system_files/` or module outputs.

## Updating Dependencies
- If a hook depends on new files, update both the manifest generator and the Containerfile section responsible for placeholder substitution.
- Use relative paths from `/ctx` when referencing files in build-time scripts to maintain container compatibility.

## Validation & Testing
- After modifying hooks or manifest logic, run:
  - `tests/test-content-versioning.sh` to verify hash stability and substitution.
  - `tests/test-manifest-generation.sh` to ensure manifest schema compliance.
  - `just check` for the full validation sweep.
- Inspect `/usr/bin/dudley-build-info` in a built image to confirm the new content version values.

## Learnings
- Forgetting to update the Containerfile replacement block leaves `__CONTENT_VERSION__` in the final image—search for the placeholder after every change. (1)
- Hooks that touch user home directories must tolerate repeated execution; add guards before destructive actions. (1)
- Keep manifest dependency lists sorted to avoid non-deterministic hash diffs across builds. (1)
