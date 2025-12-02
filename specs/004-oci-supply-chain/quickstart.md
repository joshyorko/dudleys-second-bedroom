# Quickstart: Verifying Dudley Images

## Prerequisites
- `cosign` (v2.0+)
- `oras` (v1.0+)
- `jq`

## 1. Verify Image Signature

### Key-based Verification
```bash
cosign verify --key cosign.pub ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

### Keyless Verification (OIDC)
```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/joshyorko/dudleys-second-bedroom/.github/workflows/build.yml" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

## 2. Inspect SBOM
```bash
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq .
```

## 3. Verify Provenance
```bash
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq .payload | base64 -d | jq .
```

## 4. Access Build Metadata
```bash
# Get the image digest
DIGEST=$(skopeo inspect docker://ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq -r .Digest | cut -d: -f2)

# Pull metadata
oras pull ghcr.io/joshyorko/dudleys-second-bedroom:sha256-${DIGEST}.metadata
tar -xvf metadata.tar.gz
```
