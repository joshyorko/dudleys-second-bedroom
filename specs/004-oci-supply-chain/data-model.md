# Data Model: OCI Supply Chain Artifacts

## Entities

### 1. Container Image
- **Type**: OCI Image Manifest (`application/vnd.oci.image.manifest.v1+json`)
- **Identifier**: Digest (`sha256:...`)
- **Tags**: `latest`, `YYYYMMDD`, etc.
- **Description**: The bootable OS image.

### 2. SBOM (Software Bill of Materials)
- **Type**: SPDX JSON (`application/spdx+json`)
- **Association**: Attached to Image via `cosign attach sbom`.
- **Content**: List of all RPMs, files, and dependencies in the image.

### 3. Provenance Attestation
- **Type**: SLSA Provenance v0.2 (`application/vnd.in-toto+json`)
- **Association**: Attached to Image via `cosign attest`.
- **Content**: Builder ID (GitHub Actions), Build Config (Workflow), Source (Git SHA).

### 4. Metadata Artifact
- **Type**: OCI Artifact (`application/vnd.dudley.metadata.v1`)
- **Identifier**: Tagged as `sha256-<IMAGE_DIGEST>.metadata`.
- **Content**: `metadata.tar.gz` containing:
  - `specs/`
  - `docs/`
  - `build_files/`

### 5. Signatures
- **Type**: Cosign Signature (`application/vnd.dev.cosign.simplesigning.v1+json`)
- **Association**: Linked to Image digest.
- **Variants**:
  - **Key-based**: Signed with project private key.
  - **Keyless**: Signed with GitHub OIDC identity.

## Relationships

```mermaid
graph TD
    Image[Container Image]
    SBOM[SBOM (SPDX)]
    Prov[Provenance (SLSA)]
    Meta[Metadata Artifact]
    SigKey[Signature (Key)]
    SigOIDC[Signature (OIDC)]

    Image -->|Has Attachment| SBOM
    Image -->|Has Attestation| Prov
    Image -->|Signed By| SigKey
    Image -->|Signed By| SigOIDC
    Meta -.->|Refers to| Image
```
