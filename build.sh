#!/bin/bash
# Build script for the ROCm SDK bundle: compiler, headers, cmake configs,
# and runtime libraries — everything needed to BUILD against ROCm without
# touching apt or repo.radeon.com at consume time.
#
# Downloads .deb packages from the official AMD ROCm repository and extracts
# them into a single self-contained tarball.

set -e

ROCM_VERSION="7.2.2"
ROCM_DEB_SUFFIX="70202-86"  # apt build suffix that pairs with this version
UBUNTU_CODENAME="noble"
BASE_URL="https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/pool/main"

# Trim tensile / kernel libraries to the gfx targets we actually ship for.
# Add new archs here when AMD enables WMMA on them in this ROCm release.
GPU_TARGETS="gfx908;gfx90a;gfx942;gfx1030;gfx1031;gfx1032;gfx1100;gfx1101;gfx1102;gfx1103;gfx1151;gfx1150;gfx1200;gfx1201"

# Full SDK package set (compiler + headers + runtime libs).
PACKAGES=(
    # Foundational
    "r/rocm-core${ROCM_VERSION}/rocm-core${ROCM_VERSION}_7.2.2.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "c/comgr${ROCM_VERSION}/comgr${ROCM_VERSION}_3.0.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # Compiler toolchain + cmake helpers
    "r/rocm-llvm${ROCM_VERSION}/rocm-llvm${ROCM_VERSION}_22.0.0.26084.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocm-device-libs${ROCM_VERSION}/rocm-device-libs${ROCM_VERSION}_1.0.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocm-cmake${ROCM_VERSION}/rocm-cmake${ROCM_VERSION}_0.14.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # HIP runtime + headers + driver wrapper
    "h/hip-runtime-amd${ROCM_VERSION}/hip-runtime-amd${ROCM_VERSION}_7.2.53211.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hip-dev${ROCM_VERSION}/hip-dev${ROCM_VERSION}_7.2.53211.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipcc${ROCM_VERSION}/hipcc${ROCM_VERSION}_1.1.1.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # HSA runtime + headers
    "h/hsa-rocr${ROCM_VERSION}/hsa-rocr${ROCM_VERSION}_1.18.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hsa-rocr-dev${ROCM_VERSION}/hsa-rocr-dev${ROCM_VERSION}_1.18.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # rocBLAS / hipBLAS / hipBLASLt
    "r/rocblas${ROCM_VERSION}/rocblas${ROCM_VERSION}_5.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocblas-dev${ROCM_VERSION}/rocblas-dev${ROCM_VERSION}_5.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblas${ROCM_VERSION}/hipblas${ROCM_VERSION}_3.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblas-common-dev${ROCM_VERSION}/hipblas-common-dev${ROCM_VERSION}_1.4.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblas-dev${ROCM_VERSION}/hipblas-dev${ROCM_VERSION}_3.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblaslt${ROCM_VERSION}/hipblaslt${ROCM_VERSION}_1.2.2.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblaslt-dev${ROCM_VERSION}/hipblaslt-dev${ROCM_VERSION}_1.2.2.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # rocSPARSE / hipSPARSE
    "r/rocsparse${ROCM_VERSION}/rocsparse${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocsparse-dev${ROCM_VERSION}/rocsparse-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipsparse${ROCM_VERSION}/hipsparse${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipsparse-dev${ROCM_VERSION}/hipsparse-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # rocSOLVER / hipSOLVER
    "r/rocsolver${ROCM_VERSION}/rocsolver${ROCM_VERSION}_3.32.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocsolver-dev${ROCM_VERSION}/rocsolver-dev${ROCM_VERSION}_3.32.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipsolver${ROCM_VERSION}/hipsolver${ROCM_VERSION}_3.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipsolver-dev${ROCM_VERSION}/hipsolver-dev${ROCM_VERSION}_3.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # Random / thrust / prim / cub template libs
    "h/hiprand${ROCM_VERSION}/hiprand${ROCM_VERSION}_3.1.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hiprand-dev${ROCM_VERSION}/hiprand-dev${ROCM_VERSION}_3.1.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocrand${ROCM_VERSION}/rocrand${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocrand-dev${ROCM_VERSION}/rocrand-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocprim-dev${ROCM_VERSION}/rocprim-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocthrust-dev${ROCM_VERSION}/rocthrust-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipcub-dev${ROCM_VERSION}/hipcub-dev${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # WMMA matrix-multiply primitives
    "r/rocwmma-dev${ROCM_VERSION}/rocwmma-dev${ROCM_VERSION}_2.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # Composable Kernel (used by hipblaslt/rocblas tensile path)
    "c/composablekernel-dev${ROCM_VERSION}/composablekernel-dev${ROCM_VERSION}_1.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # OpenMP extras (HIP offload runtime)
    "o/openmp-extras-runtime${ROCM_VERSION}/openmp-extras-runtime${ROCM_VERSION}_20.70.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # Profiling helpers (small)
    "r/rocprofiler-register${ROCM_VERSION}/rocprofiler-register${ROCM_VERSION}_0.6.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/roctracer${ROCM_VERSION}/roctracer${ROCM_VERSION}_4.1.70202.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # SMI / info
    "r/rocm-smi-lib${ROCM_VERSION}/rocm-smi-lib${ROCM_VERSION}_7.8.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocminfo${ROCM_VERSION}/rocminfo${ROCM_VERSION}_1.0.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
)

TEMP_DIR="tmp_extract"
DIST_DIR="rocm-runtime"
STAGING_DIR="rocm-runtime-bundle"

echo "Building ROCm ${ROCM_VERSION} SDK bundle (Native)..."

# Clean up previous builds
rm -rf "${TEMP_DIR}" "${DIST_DIR}" "${STAGING_DIR}"
mkdir -p "${TEMP_DIR}" "${DIST_DIR}"

# Step 1: Download and extract packages
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
        if command -v zstd >/dev/null 2>&1; then
            tar --use-compress-program=zstd -xf "${TEMP_DIR}/data.tar.zst" -C "${DIST_DIR}"
        else
            echo "Error: zstd is required to extract some packages but not found."
            exit 1
        fi
    fi

    rm -f "${TEMP_DIR}/data.tar."* "${TEMP_DIR}/control.tar."* "${TEMP_DIR}/debian-binary" "${TEMP_DIR}/${pkg_name}"
done

# Step 2: Organize files (full /opt/rocm-X.Y.Z tree, not just lib/)
echo "Step 2: Organizing the SDK tree..."
mkdir -p "${STAGING_DIR}"

ROCM_INSTALL_DIR=$(find "${DIST_DIR}/opt" -maxdepth 1 -name "rocm-*" -type d | head -n 1)

if [ -z "${ROCM_INSTALL_DIR}" ]; then
    echo "Error: Could not find ROCm installation directory in extracted files."
    exit 1
fi

echo "  Found ROCm installation at ${ROCM_INSTALL_DIR}"

# Copy the entire ROCm install tree (bin/, include/, lib/, lib/llvm/, share/, etc.)
cp -a "${ROCM_INSTALL_DIR}/." "${STAGING_DIR}/"

# Copy template files
if [ -f "templates/setup-env.sh" ]; then
    cp templates/setup-env.sh "${STAGING_DIR}/"
    chmod +x "${STAGING_DIR}/setup-env.sh"
fi

if [ -f "templates/README-package.md" ]; then
    cp templates/README-package.md "${STAGING_DIR}/README.md"
fi

# Step 3: Create version file
echo "Step 3: Creating version information..."
mkdir -p "${STAGING_DIR}/.info"
echo "${ROCM_VERSION}" > "${STAGING_DIR}/.info/version"
echo "  Created version file: ${STAGING_DIR}/.info/version"

# Step 4: Filter tensile libraries for GPU_TARGETS
echo "Step 4: Filtering tensile libraries for GPU_TARGETS..."

should_keep_file() {
    local filename="$1"
    local gpu_targets="$2"

    local IFS=';'
    for gpu in $gpu_targets; do
        if [[ "${filename}" == *"${gpu}"* ]]; then
            return 0
        fi
    done

    if [[ "${filename}" == *"gfx908"* ]] || \
       [[ "${filename}" == *"gfx90a"* ]] || \
       [[ "${filename}" == *"gfx942"* ]] || \
       [[ "${filename}" == *"gfx950"* ]]; then
        return 1
    fi

    if [[ "${filename}" == *"fallback"* ]]; then
        return 0
    fi

    return 0
}

while IFS= read -r libfile; do
    basename=$(basename "${libfile}")
    if ! should_keep_file "${basename}" "${GPU_TARGETS}"; then
        echo "  Removing unsupported GPU library: ${basename}"
        rm -f "${libfile}"
    fi
done < <(find "${STAGING_DIR}" -type f \( -name "*TensileLibrary*" -o -name "*Kernels.so*" -o -name "extop_*" \))

# Step 5: Create the final tarball
echo "Step 5: Creating the final tarball..."
TARBALL="rocm-${ROCM_VERSION}-runtime-libs.tar.gz"
tar -czf "${TARBALL}" -C "${STAGING_DIR}" .

echo "Done! ROCm bundle created: ${TARBALL}"
TARBALL_SIZE=$(du -h "${TARBALL}" | cut -f1)
echo "Size: ${TARBALL_SIZE}"

# Clean up
rm -rf "${TEMP_DIR}" "${DIST_DIR}" "${STAGING_DIR}"
