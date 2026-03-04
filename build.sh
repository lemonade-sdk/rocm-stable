#!/bin/bash
# Build script for ROCm 7.2 runtime library bundle
# This script builds the Docker image and extracts the ROCm runtime package

set -e

echo "Building ROCm 7.2 runtime library bundle..."

# Build the Docker image and extract the tarball directly to the current directory
echo "Step 1: Building and extracting runtime package..."
docker build --target export --output type=local,dest=. .

echo "Done! ROCm runtime package created: rocm-7.2-runtime-libs.tar.gz"
echo "Size: $(du -h rocm-7.2-runtime-libs.tar.gz | cut -f1)"
