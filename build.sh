#!/bin/bash
# Build script for ROCm 7.2 runtime library bundle (Native version)
# This script downloads ROCm packages from the official repository and extracts them
# to create a standalone distribution without using Docker.

set -e

ROCM_VERSION="7.2"
UBUNTU_CODENAME="noble"
BASE_URL="https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/pool/main"

# Packages to download (based on Dockerfile extraction)
PACKAGES=(
    "c/comgr7.2.0/comgr7.2.0_3.0.0.70200-43~24.04_amd64.deb"
    "h/hip-runtime-amd7.2.0/hip-runtime-amd7.2.0_7.2.26015.70200-43~24.04_amd64.deb"
    "h/hipblas7.2.0/hipblas7.2.0_3.2.0.70200-43~24.04_amd64.deb"
    "h/hipblaslt7.2.0/hipblaslt7.2.0_1.2.1.70200-43~24.04_amd64.deb"
    "h/hsa-rocr7.2.0/hsa-rocr7.2.0_1.18.0.70200-43~24.04_amd64.deb"
    "h/hsa-rocr-dev7.2.0/hsa-rocr-dev7.2.0_1.18.0.70200-43~24.04_amd64.deb"
    "r/rocblas7.2.0/rocblas7.2.0_5.2.0.70200-43~24.04_amd64.deb"
    "r/rocsparse7.2.0/rocsparse7.2.0_4.2.0.70200-43~24.04_amd64.deb"
)

TEMP_DIR="tmp_extract"
DIST_DIR="rocm-runtime"
STAGING_DIR="rocm-runtime-bundle"

echo "Building ROCm ${ROCM_VERSION} runtime library bundle (Native)..."

# Clean up previous builds
rm -rf "${TEMP_DIR}" "${DIST_DIR}" "${STAGING_DIR}"
mkdir -p "${TEMP_DIR}" "${DIST_DIR}"

# Download and extract packages
echo "Step 1: Downloading and extracting packages..."
for pkg_path in "${PACKAGES[@]}"; do
    pkg_name=$(basename "${pkg_path}")
    echo "  Processing ${pkg_name}..."
    
    wget -q "${BASE_URL}/${pkg_path}" -O "${TEMP_DIR}/${pkg_name}"
    
    # Extract .deb (ar x)
    (cd "${TEMP_DIR}" && ar x "${pkg_name}")
    
    # Extract data.tar.* (it could be .xz or .zst)
    if [ -f "${TEMP_DIR}/data.tar.xz" ]; then
        tar -xf "${TEMP_DIR}/data.tar.xz" -C "${DIST_DIR}"
    elif [ -f "${TEMP_DIR}/data.tar.zst" ]; then
        # Ensure zstd is available or use appropriate tar flag
        if command -v zstd >/dev/null 2>&1; then
            tar --use-compress-program=zstd -xf "${TEMP_DIR}/data.tar.zst" -C "${DIST_DIR}"
        else
            echo "Error: zstd is required to extract some packages but not found."
            exit 1
        fi
    fi
    
    # Clean up temp files for this package
    rm -f "${TEMP_DIR}/data.tar."* "${TEMP_DIR}/control.tar."* "${TEMP_DIR}/debian-binary" "${TEMP_DIR}/${pkg_name}"
done

# Step 2: Organize files (simulate /opt/rocm/lib structure)
echo "Step 2: Organizing libraries..."
mkdir -p "${STAGING_DIR}"

# ROCm packages usually install to /opt/rocm-X.Y.Z/
# We want to pull everything from there into the root of our bundle
ROCM_INSTALL_DIR=$(find "${DIST_DIR}/opt" -maxdepth 1 -name "rocm-*" -type d | head -n 1)

if [ -z "${ROCM_INSTALL_DIR}" ]; then
    echo "Error: Could not find ROCm installation directory in extracted files."
    exit 1
fi

echo "  Found ROCm installation at ${ROCM_INSTALL_DIR}"

# Copy libraries
if [ -d "${ROCM_INSTALL_DIR}/lib" ]; then
    cp -r "${ROCM_INSTALL_DIR}/lib/"* "${STAGING_DIR}/"
else
    echo "Error: lib directory not found in ROCm installation."
    exit 1
fi

# Copy template files
if [ -f "templates/setup-env.sh" ]; then
    cp templates/setup-env.sh "${STAGING_DIR}/"
    chmod +x "${STAGING_DIR}/setup-env.sh"
fi

if [ -f "templates/README-package.md" ]; then
    cp templates/README-package.md "${STAGING_DIR}/README.md"
fi

# Step 3: Create the final tarball
echo "Step 3: Creating the final tarball..."
tar -czf "rocm-${ROCM_VERSION}-runtime-libs.tar.gz" -C "${STAGING_DIR}" .

echo "Done! ROCm runtime package created: rocm-${ROCM_VERSION}-runtime-libs.tar.gz"
echo "Size: $(du -h "rocm-${ROCM_VERSION}-runtime-libs.tar.gz" | cut -f1)"

# Clean up
rm -rf "${TEMP_DIR}" "${DIST_DIR}" "${STAGING_DIR}"
