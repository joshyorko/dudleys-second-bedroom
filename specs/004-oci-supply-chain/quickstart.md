# Quickstart: Verifying Dudley Images

This guide demonstrates how to verify the integrity, provenance, and authenticity of Dudley container images using industry-standard supply chain security tools.

## Prerequisites

- `cosign` (v2.0+) - Container image signing and verification
- `oras` (v1.0+) - OCI Registry as Storage for metadata artifacts
- `skopeo` - Container image inspection
- `jq` - JSON processing

### Install Prerequisites

```bash
# Install cosign
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Install oras
curl -sSfL https://github.com/oras-project/oras/releases/latest/download/oras_1.2.0_linux_amd64.tar.gz | tar xz -C /usr/local/bin oras

# Install skopeo and jq (Fedora/RHEL)
sudo dnf install -y skopeo jq
```

## 1. Verify Image Signature

Dudley images are signed using both key-based and keyless (OIDC) methods for maximum flexibility.

### Key-based Verification

Use the project's public key (`cosign.pub`) to verify the signature:

```bash
# Download the public key
curl -sSfL https://raw.githubusercontent.com/joshyorko/dudleys-second-bedroom/main/cosign.pub -o cosign.pub

# Verify signature
cosign verify --key cosign.pub ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

### Keyless Verification (OIDC)

Verify using GitHub Actions' OIDC identity without needing any keys:

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/joshyorko/dudleys-second-bedroom/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

This method verifies that the image was signed by a GitHub Actions workflow in the official repository.

## 2. Inspect SBOM (Software Bill of Materials)

The SBOM lists all packages and dependencies included in the image:

```bash
# Download and pretty-print the SBOM
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq .

# Save SBOM to file for analysis
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest > dudley-sbom.spdx.json

# List all packages in the SBOM
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest | \
  jq -r '.packages[]?.name // empty' | sort | uniq
```

## 3. Verify Provenance Attestation

Verify the SLSA provenance to confirm where and how the image was built:

```bash
# Verify provenance attestation exists
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest

# Extract and view provenance details
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest | \
  jq -r '.payload' | base64 -d | jq .

# View specific provenance fields
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest | \
  jq -r '.payload' | base64 -d | jq '.predicate.invocation.configSource'
```

The provenance includes:
- **Builder ID**: Identifies the build system (`gh-action/dudley-build`)
- **Build Type**: URI describing the build process
- **Config Source**: Repository URI, Git SHA, and workflow entry point
- **Materials**: Source repository and commit digest

## 4. Access Build Metadata (ORAS)

Each image has associated build metadata (specs, docs, build_files) stored as an OCI artifact.

### Discover Available Artifacts

```bash
# Get the image digest
IMAGE="ghcr.io/joshyorko/dudleys-second-bedroom:latest"
DIGEST=$(skopeo inspect "docker://$IMAGE" | jq -r '.Digest' | cut -d: -f2)
echo "Image digest: sha256:$DIGEST"

# List all artifacts referencing this image
oras discover "$IMAGE" --format json | jq .
```

### Pull Build Metadata

```bash
# Construct the metadata tag
METADATA_TAG="sha256-${DIGEST}.metadata"
METADATA_REF="ghcr.io/joshyorko/dudleys-second-bedroom:${METADATA_TAG}"

# Pull the metadata artifact
mkdir -p dudley-metadata
oras pull "$METADATA_REF" --output dudley-metadata

# Extract the archive
cd dudley-metadata
tar -xzvf metadata.tar.gz

# Now you have access to:
# - specs/    - Feature specifications
# - docs/     - Documentation
# - build_files/ - Build modules and scripts
```

### Inspect Metadata Contents

```bash
# List contents of the metadata archive
tar -tzf metadata.tar.gz

# Extract specific files
tar -xzf metadata.tar.gz specs/004-oci-supply-chain/spec.md
```

## 5. Automated Verification Script

Use the project's verification script for comprehensive checks:

```bash
# Clone the repository to get the verification script
git clone https://github.com/joshyorko/dudleys-second-bedroom.git
cd dudleys-second-bedroom

# Run all verifications
./tests/verify-supply-chain.sh verify-all ghcr.io/joshyorko/dudleys-second-bedroom:latest

# Or run individual checks
./tests/verify-supply-chain.sh verify-sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest
./tests/verify-supply-chain.sh verify-provenance ghcr.io/joshyorko/dudleys-second-bedroom:latest
./tests/verify-supply-chain.sh verify-metadata ghcr.io/joshyorko/dudleys-second-bedroom:latest
./tests/verify-supply-chain.sh verify-signature-key ghcr.io/joshyorko/dudleys-second-bedroom:latest cosign.pub
./tests/verify-supply-chain.sh verify-signature-oidc ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

## 6. Enforce Signature Policy (Advanced)

For system administrators who want to enforce signature verification on all image pulls, see:
- [docs/SIGNATURE-VERIFICATION.md](../../docs/SIGNATURE-VERIFICATION.md) - Full setup guide
- [docs/signature-policy/](../../docs/signature-policy/) - Example policy files

## Troubleshooting

### "No signatures found"

Ensure you're checking a tagged image from the main branch. Pull request builds are not signed.

### "Certificate verification failed"

For keyless verification, ensure the identity regexp matches the workflow path exactly, including the branch reference.

### "SBOM not found"

SBOM is only attached to images built from the main branch. PR/test builds do not include SBOMs.

### "Metadata artifact not found"

Check that you're using the correct digest. The metadata tag format is `sha256-<digest>.metadata`.
