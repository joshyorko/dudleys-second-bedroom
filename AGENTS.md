# Repository Guidelines

## Project Structure & Module Organization
This repository builds a customized Universal Blue / Bluefin image rather than a traditional app. Core build logic lives in `build_files/`: `shared/` for common image steps, `desktop/` for GNOME and theme changes, `developer/` for dev tooling, and `user-hooks/` for first-login actions such as `10-wallpaper-enforcement.sh`. Runtime assets live in `custom_wallpapers/`, `flatpaks/`, `system_files/`, and `disk_config/`. Tests and repro scripts live in `tests/` and `tests/reproductions/`. CI definitions and contributor-facing shell instructions live under `.github/`.

## Build, Test, and Development Commands
Use `just` as the main entrypoint:

- `just check` runs syntax checks, ShellCheck, package validation, and module validation.
- `just test-unit` runs hash and manifest unit tests.
- `just test-integration` validates hook integration behavior.
- `just test-all` runs the complete local test sweep.
- `just build localhost/dudleys-second-bedroom latest` builds the container image with Podman.
- `just verify-build localhost/dudleys-second-bedroom latest` checks the built image contents.
- `just build-qcow2` or `just build-iso` builds bootable artifacts from `disk_config/`.

## Coding Style & Naming Conventions
Most repo code is Bash. Start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`. Format shell with `just format` (`shfmt`) and lint with `just lint` (`shellcheck -x -e SC1091`). The repo standard is 2-space indentation. Keep module filenames descriptive and kebab-case; use numeric prefixes when order matters, for example `20-vscode-extensions.sh`. New `build_files/` modules must include the metadata header described in `.github/instructions/module-contract.instructions.md`.

## Testing Guidelines
Add or update a focused shell test whenever you change build utilities, manifest generation, or user hooks. Place unit-style coverage beside existing scripts in `tests/`, and store one-off bug repros in `tests/reproductions/`. Run at least `just check` and the most relevant test target before opening a PR; use `just test-all` for changes that touch shared utilities, hooks, or the `Containerfile`.

## Commit & Pull Request Guidelines
Recent history follows Conventional Commit prefixes such as `chore:`, `chore(deps):`, `fix:`, and `feat:`; keep subject lines short and imperative. PRs should describe the user-visible build impact, list the local commands you ran, and link any related issue. Include screenshots only when changing desktop UX, wallpapers, or other visual defaults. Treat signing files, image metadata, and workflow changes as sensitive and call them out explicitly in review.
