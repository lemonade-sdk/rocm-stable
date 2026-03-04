#!/bin/bash
# Build script for ROCm 7.2 runtime library bundle
# This script builds the Docker image and extracts the ROCm runtime package

set -e

echo "Building ROCm 7.2 runtime library bundle..."

# Build the Docker image
echo "Step 1: Building Docker image..."
docker build -t rocm-7.2-runtime-builder .

# Create a temporary container to extract the tarball
echo "Step 2: Extracting runtime package from container..."
CONTAINER_ID=$(docker create rocm-7.2-runtime-builder)

# Copy the tarball from the container
docker cp ${CONTAINER_ID}:/rocm-7.2-runtime-libs.tar.gz .

# Clean up the temporary container
echo "Step 3: Cleaning up..."
docker rm ${CONTAINER_ID}

echo "Done! ROCm runtime package created: rocm-7.2-runtime-libs.tar.gz"
echo "Size: $(du -h rocm-7.2-runtime-libs.tar.gz | cut -f1)"
