# Signature Verification Guide

This guide explains how to verify Dudley container images and enforce signature policies on your systems.

## Overview

Dudley images are signed using two methods for maximum flexibility:

1. **Key-based signing**: Uses a traditional public/private key pair. Best for air-gapped environments or organizations that prefer managing their own trust anchors.

2. **Keyless (OIDC) signing**: Uses GitHub Actions' OIDC identity through Sigstore. No key management required; verification is based on the build workflow identity.

Both signatures are attached to every production image built from the `main` branch.

## Quick Verification

### Verify with Public Key

```bash
# Download the public key
curl -sSfL https://raw.githubusercontent.com/joshyorko/dudleys-second-bedroom/main/cosign.pub -o cosign.pub

# Verify the image
cosign verify --key cosign.pub ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

### Verify with OIDC (Keyless)

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/joshyorko/dudleys-second-bedroom/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

## Enforcing Signature Policy on Fedora Atomic / bootc

To ensure only signed images can be booted or switched to, configure the container signature policy.

### Step 1: Install the Public Key

```bash
# Create the PKI directory if it doesn't exist
sudo mkdir -p /etc/pki/containers

# Download and install the Dudley public key
curl -sSfL https://raw.githubusercontent.com/joshyorko/dudleys-second-bedroom/main/cosign.pub \
  | sudo tee /etc/pki/containers/dudley-cosign.pub > /dev/null
```

### Step 2: Configure registries.d

Create the registries.d configuration file:

```bash
sudo tee /etc/containers/registries.d/dudley.yaml << 'EOF'
docker:
  ghcr.io/joshyorko/dudleys-second-bedroom:
    use-sigstore-attachments: true
    sigstore:
      public-key-file: /etc/pki/containers/dudley-cosign.pub
EOF
```

### Step 3: Update Signature Policy

Edit `/etc/containers/policy.json` to require signatures for Dudley images:

```json
{
  "default": [
    {
      "type": "reject"
    }
  ],
  "transports": {
    "docker": {
      "ghcr.io/joshyorko/dudleys-second-bedroom": [
        {
          "type": "sigstoreSigned",
          "keyPath": "/etc/pki/containers/dudley-cosign.pub",
          "signedIdentity": {
            "type": "matchRepository"
          }
        }
      ],
      "": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  }
}
```

> **Warning**: The default policy above rejects all unsigned images. Adjust the policy for your environment.

### Step 4: Test the Configuration

```bash
# This should succeed for signed images
sudo bootc switch ghcr.io/joshyorko/dudleys-second-bedroom:latest

# This should fail for unsigned or incorrectly signed images
sudo bootc switch some-unsigned-image:latest
```

## Keyless Verification Policy

To use OIDC (keyless) verification instead of key-based, you'll need the Sigstore trust root:

### Step 1: Install Sigstore Trust Root

```bash
# Download Fulcio CA certificate
curl -sSfL https://fulcio.sigstore.dev/api/v1/rootCert \
  | sudo tee /etc/pki/containers/fulcio_v1.crt.pem > /dev/null

# Download Rekor public key
curl -sSfL https://rekor.sigstore.dev/api/v1/log/publicKey \
  | sudo tee /etc/pki/containers/rekor.pub > /dev/null
```

### Step 2: Configure Policy for Keyless Verification

```json
{
  "default": [
    {
      "type": "reject"
    }
  ],
  "transports": {
    "docker": {
      "ghcr.io/joshyorko/dudleys-second-bedroom": [
        {
          "type": "sigstoreSigned",
          "fulcio": {
            "caPath": "/etc/pki/containers/fulcio_v1.crt.pem",
            "oidcIssuer": "https://token.actions.githubusercontent.com",
            "subjectEmail": ""
          },
          "rekorPublicKeyPath": "/etc/pki/containers/rekor.pub",
          "signedIdentity": {
            "type": "matchRepository"
          }
        }
      ]
    }
  }
}
```

## Example Policy Files

Ready-to-use policy files are available in the repository:

- [`docs/signature-policy/policy.json`](signature-policy/policy.json) - Example signature policy
- [`docs/signature-policy/dudley.yaml`](signature-policy/dudley.yaml) - Example registries.d configuration

## Verifying SBOM and Provenance

In addition to signatures, you can verify the SBOM and SLSA provenance:

```bash
# Download and inspect SBOM
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq .

# Verify SLSA provenance
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

## Troubleshooting

### "Error: no matching signatures"

- Ensure you're verifying a production image (built from `main` branch)
- Check that the public key is correct and matches the signing key
- For OIDC verification, ensure the identity regexp matches exactly

### "Error: certificate verification failed"

- Verify the Fulcio CA certificate is up to date
- Check the OIDC issuer matches `https://token.actions.githubusercontent.com`
- Ensure the certificate identity pattern includes the correct branch reference

### "Error: unable to fetch signature"

- Check network connectivity to `ghcr.io`
- Verify the image tag exists and has been signed
- Ensure `use-sigstore-attachments: true` is set in registries.d

### Policy Not Being Enforced

- Restart podman/container services after policy changes
- Verify policy.json syntax with `jq . /etc/containers/policy.json`
- Check that registries.d file has correct YAML syntax

## Security Considerations

1. **Key Rotation**: If using key-based verification, establish a key rotation policy
2. **Policy Scope**: The example policy uses `matchRepository` which allows any tag; consider `exactRepository` for stricter control
3. **Default Deny**: The example default policy rejects unsigned images; adjust based on your security requirements
4. **Network Dependencies**: Keyless verification requires network access to Sigstore services

## References

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [containers-policy.json(5)](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)
- [containers-registries.d(5)](https://github.com/containers/image/blob/main/docs/containers-registries.d.5.md)
- [SLSA Provenance](https://slsa.dev/provenance/v0.2)
- [Sigstore](https://www.sigstore.dev/)
