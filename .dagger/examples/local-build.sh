#!/usr/bin/env bash
# Example: Local build script using Dagger
set -euo pipefail

# Configuration
IMAGE_NAME="dudleys-second-bedroom"
IMAGE_TAG="local-$(date +%Y%m%d)"
GIT_COMMIT=$(git rev-parse --short HEAD)
REGISTRY="ghcr.io"
REPOSITORY="joshyorko/dudleys-second-bedroom"

echo "🚀 Starting local build with Dagger..."
echo "  Image: ${IMAGE_NAME}"
echo "  Tag: ${IMAGE_TAG}"
echo "  Commit: ${GIT_COMMIT}"
echo ""

# Step 1: Validate
echo "🔍 Step 1/4: Validating configuration..."
if ! dagger call validate --source=.; then
    echo "❌ Validation failed!"
    exit 1
fi
echo "✅ Validation passed"
echo ""

# Step 2: Build
echo "🔨 Step 2/4: Building image..."
if ! dagger call build \
    --source=. \
    --image-name="${IMAGE_NAME}" \
    --tag="${IMAGE_TAG}" \
    --git-commit="${GIT_COMMIT}"; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build completed"
echo ""

# Step 3: Test
echo "🧪 Step 3/4: Running tests..."
IMAGE=$(dagger call build --source=. --git-commit="${GIT_COMMIT}")
if ! dagger call test --image="${IMAGE}"; then
    echo "❌ Tests failed!"
    exit 1
fi
echo "✅ Tests passed"
echo ""

# Step 4: Optional - Export container
echo "📦 Step 4/4: Exporting container..."
read -p "Export container to local registry? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    dagger call build \
        --source=. \
        --image-name="${IMAGE_NAME}" \
        --tag="${IMAGE_TAG}" \
        --git-commit="${GIT_COMMIT}" \
        export --path="${IMAGE_NAME}-${IMAGE_TAG}.tar"
    
    echo "✅ Container exported to ${IMAGE_NAME}-${IMAGE_TAG}.tar"
    echo ""
    echo "To load into podman:"
    echo "  podman load -i ${IMAGE_NAME}-${IMAGE_TAG}.tar"
    echo ""
    echo "To load into docker:"
    echo "  docker load -i ${IMAGE_NAME}-${IMAGE_TAG}.tar"
fi

echo ""
echo "🎉 Local build complete!"
echo ""
echo "Next steps:"
echo "  1. Test locally: podman run -it ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  2. Build ISO: dagger call build-iso --source=. --image-ref=${REGISTRY}/${REPOSITORY}:${IMAGE_TAG}"
echo "  3. Push to registry: dagger call publish --image=\$IMAGE --repository=${REPOSITORY}"
