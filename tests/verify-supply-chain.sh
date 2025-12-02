#!/usr/bin/env bash

#
# Purpose: Verification helpers for build supply-chain artifacts (SBOM, provenance, metadata, signatures)
# Category: tests
# Dependencies: cosign, oras, jq, skopeo
# Parallel-Safe: yes
# Cache-Friendly: yes
#
set -euo pipefail

echo "========================================="
echo "Supply-Chain Verification Helpers"
echo "========================================="

# Defaults for OIDC verification (GitHub Actions)
DEFAULT_OIDC_ISSUER="https://token.actions.githubusercontent.com"
DEFAULT_OIDC_IDENTITY_REGEXP="https://github.com/joshyorko/dudleys-second-bedroom/.github/workflows/build.yml"

verify_sbom() {
	local image_ref=${1:-}
	if [[ -z "$image_ref" ]]; then
		echo "verify_sbom: missing image ref" >&2
		return 2
	fi

	echo "verify_sbom: checking SBOM for $image_ref"

	if ! command -v cosign >/dev/null 2>&1; then
		echo "ERROR: cosign not installed in PATH" >&2
		return 1
	fi

	local out_file
	out_file=$(mktemp --suffix=.sbom.json)
	if ! cosign download sbom "$image_ref" >"$out_file" 2>/dev/null; then
		echo "ERROR: failed to download SBOM for $image_ref" >&2
		rm -f "$out_file"
		return 1
	fi

	# Basic sanity checks for a plausible SPDX/JSON SBOM
	if ! jq -e 'has("spdxVersion") or has("bomFormat") or has("packages")' "$out_file" >/dev/null 2>&1; then
		echo "ERROR: downloaded SBOM does not appear to be valid SPDX/CycloneDX JSON" >&2
		rm -f "$out_file"
		return 1
	fi

	echo "OK: SBOM downloaded and appears valid: $out_file"
	rm -f "$out_file"
	return 0
}

verify_provenance() {
	local image_ref=${1:-}
	if [[ -z "$image_ref" ]]; then
		echo "verify_provenance: missing image ref" >&2
		return 2
	fi

	echo "verify_provenance: checking provenance for $image_ref"

	if ! command -v cosign >/dev/null 2>&1; then
		echo "ERROR: cosign not installed in PATH" >&2
		return 1
	fi

	# verify-attestation returns non-zero if verification fails
	if ! cosign verify-attestation --type slsaprovenance "$image_ref" >/dev/null 2>&1; then
		echo "ERROR: provenance verification failed for $image_ref" >&2
		return 1
	fi

	echo "OK: provenance attestation verified for $image_ref"
	return 0
}

# T018: Verify metadata artifact exists and can be pulled
verify_metadata() {
	local image_ref=${1:-}
	if [[ -z "$image_ref" ]]; then
		echo "verify_metadata: missing image ref" >&2
		return 2
	fi

	echo "verify_metadata: checking metadata artifact for $image_ref"

	if ! command -v oras >/dev/null 2>&1; then
		echo "ERROR: oras not installed in PATH" >&2
		return 1
	fi

	if ! command -v skopeo >/dev/null 2>&1; then
		echo "ERROR: skopeo not installed in PATH" >&2
		return 1
	fi

	# Extract registry/repo from image_ref (strip tag if present)
	local registry_repo
	registry_repo="${image_ref%:*}"

	# Get the digest of the image
	local digest
	digest=$(skopeo inspect --format '{{.Digest}}' "docker://$image_ref" 2>/dev/null | cut -d: -f2)
	if [[ -z "$digest" ]]; then
		echo "ERROR: failed to get digest for $image_ref" >&2
		return 1
	fi

	local metadata_tag="sha256-${digest}.metadata"
	local metadata_ref="${registry_repo}:${metadata_tag}"

	echo "Looking for metadata artifact at: $metadata_ref"

	# Create temporary directory for pulling metadata
	local tmp_dir
	tmp_dir=$(mktemp -d)
	trap 'rm -rf "$tmp_dir"' RETURN

	if ! oras pull "$metadata_ref" --output "$tmp_dir" 2>/dev/null; then
		echo "ERROR: failed to pull metadata artifact from $metadata_ref" >&2
		return 1
	fi

	# Verify metadata.tar.gz exists and contains expected directories
	if [[ ! -f "$tmp_dir/metadata.tar.gz" ]]; then
		echo "ERROR: metadata.tar.gz not found in pulled artifact" >&2
		return 1
	fi

	# Verify tarball contains expected directories
	if ! tar -tzf "$tmp_dir/metadata.tar.gz" | grep -qE '^(specs|docs|build_files)/'; then
		echo "ERROR: metadata.tar.gz does not contain expected directories (specs/, docs/, build_files/)" >&2
		return 1
	fi

	echo "OK: metadata artifact verified at $metadata_ref"
	return 0
}

# T024: Verify key-based signature
verify_signature_key() {
	local image_ref=${1:-}
	local public_key=${2:-cosign.pub}

	if [[ -z "$image_ref" ]]; then
		echo "verify_signature_key: missing image ref" >&2
		return 2
	fi

	echo "verify_signature_key: verifying key-based signature for $image_ref"

	if ! command -v cosign >/dev/null 2>&1; then
		echo "ERROR: cosign not installed in PATH" >&2
		return 1
	fi

	if [[ ! -f "$public_key" ]]; then
		echo "ERROR: public key file not found: $public_key" >&2
		return 1
	fi

	if ! cosign verify --key "$public_key" "$image_ref" >/dev/null 2>&1; then
		echo "ERROR: key-based signature verification failed for $image_ref" >&2
		return 1
	fi

	echo "OK: key-based signature verified for $image_ref"
	return 0
}

# T029: Verify OIDC (keyless) signature
verify_signature_oidc() {
	local image_ref=${1:-}
	local oidc_issuer=${2:-$DEFAULT_OIDC_ISSUER}
	local identity_regexp=${3:-$DEFAULT_OIDC_IDENTITY_REGEXP}

	if [[ -z "$image_ref" ]]; then
		echo "verify_signature_oidc: missing image ref" >&2
		return 2
	fi

	echo "verify_signature_oidc: verifying OIDC signature for $image_ref"

	if ! command -v cosign >/dev/null 2>&1; then
		echo "ERROR: cosign not installed in PATH" >&2
		return 1
	fi

	if ! cosign verify \
		--certificate-oidc-issuer "$oidc_issuer" \
		--certificate-identity-regexp "$identity_regexp" \
		"$image_ref" >/dev/null 2>&1; then
		echo "ERROR: OIDC signature verification failed for $image_ref" >&2
		echo "  Issuer: $oidc_issuer"
		echo "  Identity: $identity_regexp"
		return 1
	fi

	echo "OK: OIDC signature verified for $image_ref"
	return 0
}

# Run all verification checks
verify_all() {
	local image_ref=${1:-}
	local public_key=${2:-cosign.pub}
	local exit_code=0

	if [[ -z "$image_ref" ]]; then
		echo "verify_all: missing image ref" >&2
		return 2
	fi

	echo "Running all supply chain verifications for: $image_ref"
	echo ""

	echo "--- SBOM Verification ---"
	if ! verify_sbom "$image_ref"; then
		exit_code=1
	fi
	echo ""

	echo "--- Provenance Verification ---"
	if ! verify_provenance "$image_ref"; then
		exit_code=1
	fi
	echo ""

	echo "--- Metadata Artifact Verification ---"
	if ! verify_metadata "$image_ref"; then
		exit_code=1
	fi
	echo ""

	echo "--- Key-based Signature Verification ---"
	if ! verify_signature_key "$image_ref" "$public_key"; then
		exit_code=1
	fi
	echo ""

	echo "--- OIDC Signature Verification ---"
	if ! verify_signature_oidc "$image_ref"; then
		exit_code=1
	fi
	echo ""

	if [[ $exit_code -eq 0 ]]; then
		echo "========================================="
		echo "ALL VERIFICATIONS PASSED"
		echo "========================================="
	else
		echo "========================================="
		echo "SOME VERIFICATIONS FAILED"
		echo "========================================="
	fi

	return $exit_code
}

usage() {
	cat <<'EOF'
Usage: verify-supply-chain.sh <cmd> <image> [options]

Commands:
  verify-sbom <image-ref>              Verify the attached SBOM for the image
  verify-provenance <image-ref>        Verify the SLSA provenance attestation
  verify-metadata <image-ref>          Verify the metadata artifact exists and is valid
  verify-signature-key <image-ref> [key]  Verify key-based signature (default key: cosign.pub)
  verify-signature-oidc <image-ref> [issuer] [identity]
                                       Verify OIDC (keyless) signature
  verify-all <image-ref> [key]         Run all verification checks

Examples:
  ./verify-supply-chain.sh verify-sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest
  ./verify-supply-chain.sh verify-signature-key ghcr.io/joshyorko/dudleys-second-bedroom:latest cosign.pub
  ./verify-supply-chain.sh verify-all ghcr.io/joshyorko/dudleys-second-bedroom:latest

EOF
}

if [[ ${#@} -lt 2 ]]; then
	usage
	exit 2
fi

cmd=$1
shift

case "$cmd" in
	verify-sbom) verify_sbom "$@" ;;
	verify-provenance) verify_provenance "$@" ;;
	verify-metadata) verify_metadata "$@" ;;
	verify-signature-key) verify_signature_key "$@" ;;
	verify-signature-oidc) verify_signature_oidc "$@" ;;
	verify-all) verify_all "$@" ;;
	*)
		usage
		exit 2
		;;
esac
