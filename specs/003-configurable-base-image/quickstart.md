# Quickstart: Configurable Base Image

## Local Development

### Standard Build (Default)
Builds using `ghcr.io/ublue-os/bluefin-dx:stable`.
```bash
just build
```

### Custom Base Image
Builds using a specified upstream image (e.g., Aurora).
```bash
BASE_IMAGE="ghcr.io/ublue-os/aurora-dx:stable" just build
```

## CI/CD (GitHub Actions)

1. Go to the **Actions** tab in the repository.
2. Select the **Build container image** workflow.
3. Click **Run workflow**.
4. (Optional) Enter a custom image reference in the **Base image** field.
5. Click **Run workflow**.

## Verification

Check the build logs for the `FROM` instruction or the `ARG BASE_IMAGE` output to confirm the correct image was used.
