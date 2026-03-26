#!/bin/bash
# Build script for ROCm 7.2.1 runtime library bundle (Native version)
# This script downloads ROCm packages from the official repository and extracts them
# to create a standalone distribution without using Docker.

set -e

ROCM_VERSION="7.2.1"
UBUNTU_CODENAME="noble"
BASE_URL="https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/pool/main"
GPU_TARGETS="gfx1030;gfx1031;gfx1032;gfx1100;gfx1101;gfx1102;gfx1151;gfx1150;gfx1200;gfx1201"

# Packages to download (based on Dockerfile extraction)
PACKAGES=(
    "c/comgr7.2.1/comgr7.2.1_3.0.0.70201-81~24.04_amd64.deb"
    "h/hip-runtime-amd7.2.1/hip-runtime-amd7.2.1_7.2.53211.70201-81~24.04_amd64.deb"
    "h/hipblas7.2.1/hipblas7.2.1_3.2.0.70201-81~24.04_amd64.deb"
    "h/hipblaslt7.2.1/hipblaslt7.2.1_1.2.2.70201-81~24.04_amd64.deb"
    "h/hsa-rocr7.2.1/hsa-rocr7.2.1_1.18.0.70201-81~24.04_amd64.deb"
    "h/hsa-rocr-dev7.2.1/hsa-rocr-dev7.2.1_1.18.0.70201-81~24.04_amd64.deb"
    "r/rocblas7.2.1/rocblas7.2.1_5.2.0.70201-81~24.04_amd64.deb"
    "r/rocsparse7.2.1/rocsparse7.2.1_4.2.0.70201-81~24.04_amd64.deb"
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

# Remove cmake files (not needed in runtime package)
if [ -d "${STAGING_DIR}/cmake" ]; then
    echo "Step 3: Removing cmake files..."
    rm -rf "${STAGING_DIR}/cmake"
fi

# Step 4: Filter tensile libraries for GPU_TARGETS
echo "Step 4: Filtering tensile libraries for GPU_TARGETS..."

# Function to check if a filename should be kept
should_keep_file() {
    local filename="$1"
    local gpu_targets="$2"

    # First check if filename contains any SUPPORTED GPU target
    local IFS=';'
    for gpu in $gpu_targets; do
        if [[ "${filename}" == *"${gpu}"* ]]; then
            return 0  # Keep it
        fi
    done

    # Remove files with unnecessary GPU architectures
    if [[ "${filename}" == *"gfx908"* ]] || \
       [[ "${filename}" == *"gfx90a"* ]] || \
       [[ "${filename}" == *"gfx942"* ]] || \
       [[ "${filename}" == *"gfx950"* ]]; then
        return 1  # Remove it
    fi

    # Keep generic fallback files without explicit GPU suffix
    if [[ "${filename}" == *"fallback"* ]]; then
        return 0
    fi

    # Default: keep (generic files without GPU in name)
    return 0
}

# Find and remove unsupported GPU libraries
while IFS= read -r libfile; do
    basename=$(basename "${libfile}")
    if ! should_keep_file "${basename}" "${GPU_TARGETS}"; then
        echo "  Removing unsupported GPU library: ${basename}"
        rm -f "${libfile}"
    fi
done < <(find "${STAGING_DIR}" -type f \( -name "*TensileLibrary*" -o -name "*Kernels.so*" -o -name "extop_*" \))

# Step 5: Create the final tarball
echo "Step 5: Creating the final tarball..."
tar -czf "rocm-${ROCM_VERSION}-runtime-libs.tar.gz" -C "${STAGING_DIR}" .

echo "Done! ROCm runtime package created: rocm-${ROCM_VERSION}-runtime-libs.tar.gz"
TARBALL="rocm-${ROCM_VERSION}-runtime-libs.tar.gz"
TARBALL_SIZE=$(du -h "${TARBALL}" | cut -f1)
echo "Size: ${TARBALL_SIZE}"

# Clean up
rm -rf "${TEMP_DIR}" "${DIST_DIR}" "${STAGING_DIR}"
