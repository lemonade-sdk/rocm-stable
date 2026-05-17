#!/bin/bash
# Build script for two ROCm artifacts:
#   1. rocm-<ver>-runtime-libs.tar.gz — runtime library bundle, identical in
#      shape and contents to the bundle produced on `main`: same 11 debs,
#      only lib/* is shipped, cmake/ is stripped, GPU kernels filtered.
#   2. rocm-<ver>-sdk.tar.gz — full SDK: compiler, headers, cmake configs,
#      and runtime libraries, laid out as a drop-in replacement for
#      /opt/rocm.
#
# Both tarballs are extracted from the official AMD ROCm .deb packages
# (no apt / repo.radeon.com needed at consume time).

set -e

ROCM_VERSION="7.2.2"
ROCM_DEB_SUFFIX="70202-86"  # apt build suffix that pairs with this version
UBUNTU_CODENAME="noble"
BASE_URL="https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/pool/main"

# Trim tensile / kernel libraries to the gfx targets we actually ship for.
# Add new archs here when AMD enables WMMA on them in this ROCm release.
GPU_TARGETS="gfx1030;gfx1031;gfx1032;gfx1100;gfx1101;gfx1102;gfx1103;gfx1151;gfx1150;gfx1200;gfx1201"

# Runtime package set — mirrors `main` exactly. Do not add or remove entries
# here without coordinating; the runtime tarball's contract is to match the
# historical runtime bundle.
PACKAGES_RUNTIME=(
    "c/comgr${ROCM_VERSION}/comgr${ROCM_VERSION}_3.0.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hip-runtime-amd${ROCM_VERSION}/hip-runtime-amd${ROCM_VERSION}_7.2.53211.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblas${ROCM_VERSION}/hipblas${ROCM_VERSION}_3.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hipblaslt${ROCM_VERSION}/hipblaslt${ROCM_VERSION}_1.2.2.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hsa-rocr${ROCM_VERSION}/hsa-rocr${ROCM_VERSION}_1.18.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "h/hsa-rocr-dev${ROCM_VERSION}/hsa-rocr-dev${ROCM_VERSION}_1.18.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocblas${ROCM_VERSION}/rocblas${ROCM_VERSION}_5.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocsparse${ROCM_VERSION}/rocsparse${ROCM_VERSION}_4.2.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocsolver${ROCM_VERSION}/rocsolver${ROCM_VERSION}_3.32.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocprofiler-register${ROCM_VERSION}/rocprofiler-register${ROCM_VERSION}_0.6.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/roctracer${ROCM_VERSION}/roctracer${ROCM_VERSION}_4.1.70202.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
)

# Full SDK package set (compiler + headers + cmake + runtime + dev libs).
PACKAGES_SDK=(
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

    # Profiling helpers
    "r/rocprofiler-register${ROCM_VERSION}/rocprofiler-register${ROCM_VERSION}_0.6.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/roctracer${ROCM_VERSION}/roctracer${ROCM_VERSION}_4.1.70202.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"

    # SMI / info
    "r/rocm-smi-lib${ROCM_VERSION}/rocm-smi-lib${ROCM_VERSION}_7.8.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
    "r/rocminfo${ROCM_VERSION}/rocminfo${ROCM_VERSION}_1.0.0.${ROCM_DEB_SUFFIX}~24.04_amd64.deb"
)

# Download + ar-extract each .deb in $1 (nameref to array) into $2 (dist dir).
# $3 is a scratch temp dir.
extract_packages() {
    local -n pkgs=$1
    local dist_dir=$2
    local temp_dir=$3
    for pkg_path in "${pkgs[@]}"; do
        pkg_name=$(basename "${pkg_path}")
        echo "  Processing ${pkg_name}..."

        wget -q "${BASE_URL}/${pkg_path}" -O "${temp_dir}/${pkg_name}"

        (cd "${temp_dir}" && ar x "${pkg_name}")

        if [ -f "${temp_dir}/data.tar.xz" ]; then
            tar -xf "${temp_dir}/data.tar.xz" -C "${dist_dir}"
        elif [ -f "${temp_dir}/data.tar.zst" ]; then
            if command -v zstd >/dev/null 2>&1; then
                tar --use-compress-program=zstd -xf "${temp_dir}/data.tar.zst" -C "${dist_dir}"
            else
                echo "Error: zstd is required to extract some packages but not found."
                exit 1
            fi
        fi

        rm -f "${temp_dir}/data.tar."* "${temp_dir}/control.tar."* "${temp_dir}/debian-binary" "${temp_dir}/${pkg_name}"
    done
}

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

filter_gpu_libs() {
    local staging_dir="$1"
    while IFS= read -r libfile; do
        basename=$(basename "${libfile}")
        if ! should_keep_file "${basename}" "${GPU_TARGETS}"; then
            echo "  Removing unsupported GPU library: ${basename}"
            rm -f "${libfile}"
        fi
    done < <(find "${staging_dir}" -type f \( -name "*TensileLibrary*" -o -name "*Kernels.so*" -o -name "extop_*" \))
}

# ---- Runtime bundle: mirror main's layout exactly (lib/* only, no cmake) ----

RUNTIME_TEMP="tmp_extract_runtime"
RUNTIME_DIST="rocm-runtime"
RUNTIME_STAGING="rocm-runtime-bundle"

echo "=== Building ROCm ${ROCM_VERSION} runtime bundle ==="
rm -rf "${RUNTIME_TEMP}" "${RUNTIME_DIST}" "${RUNTIME_STAGING}"
mkdir -p "${RUNTIME_TEMP}" "${RUNTIME_DIST}" "${RUNTIME_STAGING}"

echo "Step 1: Downloading and extracting runtime packages..."
extract_packages PACKAGES_RUNTIME "${RUNTIME_DIST}" "${RUNTIME_TEMP}"

echo "Step 2: Organizing libraries..."
RUNTIME_ROCM_DIR=$(find "${RUNTIME_DIST}/opt" -maxdepth 1 -name "rocm-*" -type d | head -n 1)
if [ -z "${RUNTIME_ROCM_DIR}" ]; then
    echo "Error: Could not find ROCm installation directory in extracted files."
    exit 1
fi
echo "  Found ROCm installation at ${RUNTIME_ROCM_DIR}"

if [ -d "${RUNTIME_ROCM_DIR}/lib" ]; then
    cp -r "${RUNTIME_ROCM_DIR}/lib/"* "${RUNTIME_STAGING}/"
else
    echo "Error: lib directory not found in ROCm installation."
    exit 1
fi

# Step 2.5: Remove unversioned .so dev symlinks (link-time only, not needed at runtime)
echo "Step 2.5: Removing unversioned .so dev symlinks from runtime bundle..."
find "${RUNTIME_STAGING}" -maxdepth 1 -type l -name '*.so' ! -name '*.so.*' -delete 2>/dev/null || true

if [ -f "templates/setup-env.sh" ]; then
    cp templates/setup-env.sh "${RUNTIME_STAGING}/"
    chmod +x "${RUNTIME_STAGING}/setup-env.sh"
fi
if [ -f "templates/README-package.md" ]; then
    cp templates/README-package.md "${RUNTIME_STAGING}/README.md"
fi

if [ -d "${RUNTIME_STAGING}/cmake" ]; then
    echo "Step 3: Removing cmake files..."
    rm -rf "${RUNTIME_STAGING}/cmake"
fi

echo "Step 3.5: Creating version information..."
mkdir -p "${RUNTIME_STAGING}/.info"
echo "${ROCM_VERSION}" > "${RUNTIME_STAGING}/.info/version"

echo "Step 4: Filtering tensile libraries for GPU_TARGETS..."
filter_gpu_libs "${RUNTIME_STAGING}"

echo "Step 5: Creating the runtime tarball..."
RUNTIME_TARBALL="rocm-${ROCM_VERSION}-runtime-libs.tar.gz"
tar -czf "${RUNTIME_TARBALL}" -C "${RUNTIME_STAGING}" .
RUNTIME_SIZE=$(du -h "${RUNTIME_TARBALL}" | cut -f1)
echo "  Runtime bundle: ${RUNTIME_TARBALL} (${RUNTIME_SIZE})"

rm -rf "${RUNTIME_TEMP}" "${RUNTIME_DIST}" "${RUNTIME_STAGING}"

# ---- SDK bundle: full /opt/rocm tree (compiler + headers + cmake + runtime) ----

SDK_TEMP="tmp_extract_sdk"
SDK_DIST="rocm-sdk"
SDK_STAGING="rocm-sdk-bundle"

echo ""
echo "=== Building ROCm ${ROCM_VERSION} SDK bundle ==="
rm -rf "${SDK_TEMP}" "${SDK_DIST}" "${SDK_STAGING}"
mkdir -p "${SDK_TEMP}" "${SDK_DIST}" "${SDK_STAGING}"

echo "Step 1: Downloading and extracting SDK packages..."
extract_packages PACKAGES_SDK "${SDK_DIST}" "${SDK_TEMP}"

echo "Step 2: Organizing the SDK tree..."
SDK_ROCM_DIR=$(find "${SDK_DIST}/opt" -maxdepth 1 -name "rocm-*" -type d | head -n 1)
if [ -z "${SDK_ROCM_DIR}" ]; then
    echo "Error: Could not find ROCm installation directory in extracted files."
    exit 1
fi
echo "  Found ROCm installation at ${SDK_ROCM_DIR}"

cp -a "${SDK_ROCM_DIR}/." "${SDK_STAGING}/"

if [ -f "templates/setup-env.sh" ]; then
    cp templates/setup-env.sh "${SDK_STAGING}/"
    chmod +x "${SDK_STAGING}/setup-env.sh"
fi
if [ -f "templates/README-package.md" ]; then
    cp templates/README-package.md "${SDK_STAGING}/README.md"
fi

echo "Step 3: Creating version information..."
mkdir -p "${SDK_STAGING}/.info"
echo "${ROCM_VERSION}" > "${SDK_STAGING}/.info/version"

echo "Step 4: Filtering tensile libraries for GPU_TARGETS..."
filter_gpu_libs "${SDK_STAGING}"

echo "Step 5: Splitting SDK into two parts..."

# sdk-part1: compiler toolchain, headers, cmake, core runtime libs (~1.5 GB)
# sdk-part2: math libraries with Tensile kernels (~1.8 GB)
# Both parts must be extracted to /opt/rocm to produce the full SDK.
SDK_PART1="rocm-${ROCM_VERSION}-sdk-part1.tar.gz"
SDK_PART2="rocm-${ROCM_VERSION}-sdk-part2.tar.gz"

# Directories that go into part2 only (heavy Tensile kernel data).
SDK_PART2_DIRS=(
    "lib/rocblas"
    "lib/hipblaslt"
    "lib/rocsparse"
    "lib/rocsolver"
    "lib/composablekernel"
    "lib/rocwmma"
)

# .so files specific to part2 (math libraries not in the runtime bundle).
SDK_PART2_LIBS=(
    "librocblas.so*"
    "libhipblas.so*"
    "libhipblas-common.so*"
    "libhipsparse.so*"
    "libhipsolver.so*"
    "libhiprand.so*"
)

# Create part1: everything EXCEPT the math-specific dirs and libs.
TAR_EXCLUDES=""
for dir in "${SDK_PART2_DIRS[@]}"; do
    TAR_EXCLUDES="${TAR_EXCLUDES} --exclude=${dir}"
done
for lib in "${SDK_PART2_LIBS[@]}"; do
    TAR_EXCLUDES="${TAR_EXCLUDES} --exclude=${lib}"
done

echo "  Creating ${SDK_PART1}..."
# shellcheck disable=SC2086
tar -czf "${SDK_PART1}" ${TAR_EXCLUDES} -C "${SDK_STAGING}" .
SDK_PART1_SIZE=$(du -h "${SDK_PART1}" | cut -f1)
echo "    SDK part 1: ${SDK_PART1} (${SDK_PART1_SIZE})"

# Create part2: only the math-specific dirs and libs.
echo "  Creating ${SDK_PART2}..."
TAR_PART2_INCLUDES=()
for dir in "${SDK_PART2_DIRS[@]}"; do
    if [ -d "${SDK_STAGING}/${dir}" ]; then
        TAR_PART2_INCLUDES+=("${dir}")
    fi
done
for lib in "${SDK_PART2_LIBS[@]}"; do
    matching=$(find "${SDK_STAGING}" -maxdepth 1 -name "${lib}" 2>/dev/null)
    if [ -n "${matching}" ]; then
        TAR_PART2_INCLUDES+=("${lib}")
    fi
done

if [ ${#TAR_PART2_INCLUDES[@]} -gt 0 ]; then
    tar -czf "${SDK_PART2}" -C "${SDK_STAGING}" "${TAR_PART2_INCLUDES[@]}"
    SDK_PART2_SIZE=$(du -h "${SDK_PART2}" | cut -f1)
    echo "    SDK part 2: ${SDK_PART2} (${SDK_PART2_SIZE})"
else
    echo "    WARNING: No math library files found — sdk-part2 is empty."
    SDK_PART2_SIZE="0"
fi

rm -rf "${SDK_TEMP}" "${SDK_DIST}" "${SDK_STAGING}"

echo ""
echo "Done! Built three bundles:"
echo "  - ${RUNTIME_TARBALL} (${RUNTIME_SIZE})"
echo "  - ${SDK_PART1} (${SDK_PART1_SIZE})"
echo "  - ${SDK_PART2} (${SDK_PART2_SIZE})"
