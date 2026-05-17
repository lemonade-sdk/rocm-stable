#!/bin/bash
# Build script for six ROCm artifacts:
#   1. rocm-<ver>-runtime-libs.tar.gz   - runtime library bundle
#   2. rocm-<ver>-sdk-compiler.tar.gz   - compiler binaries, headers, cmake, share
#   3. rocm-<ver>-sdk-device-libs.tar.gz - device library bitcode (.bc, .hsaco, .co)
#   4. rocm-<ver>-sdk-core-libs.tar.gz  - core shared libraries (HIP, HSA, LLVM)
#   5. rocm-<ver>-sdk-blas.tar.gz       - rocBLAS, hipBLAS, hipBLASLt + Tensile kernels
#   6. rocm-<ver>-sdk-math.tar.gz       - rocSPARSE, rocSOLVER, random libs, etc.
#
# All tarballs are extracted from the official AMD ROCm .deb packages
# (no apt / repo.radeon.com needed at consume time).

set -eo pipefail

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
        # Also check for ISA version number in .bc files (e.g., isa_version_1030)
        local isa_version="${gpu#gfx}"
        if [[ "${filename}" == *"isa_version_${isa_version}"* ]]; then
            return 0
        fi
    done

    # Reject non-target GPU architectures (CDNA)
    if [[ "${filename}" == *"gfx908"* ]] || \
       [[ "${filename}" == *"gfx90a"* ]] || \
       [[ "${filename}" == *"gfx942"* ]] || \
       [[ "${filename}" == *"gfx950"* ]] || \
       [[ "${filename}" == *"isa_version_906"* ]] || \
       [[ "${filename}" == *"isa_version_908"* ]] || \
       [[ "${filename}" == *"isa_version_942"* ]] || \
       [[ "${filename}" == *"isa_version_950"* ]]; then
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

# Filter device library bitcode files (.bc, .hsaco, .co) for unsupported GPUs.
# This removes bitcode for CDNA architectures (gfx908, gfx90a, gfx942, gfx950)
# while keeping files for our target RDNA architectures (gfx103x, gfx110x, gfx120x).
filter_device_libs() {
    local staging_dir="$1"
    while IFS= read -r libfile; do
        basename=$(basename "${libfile}")
        if ! should_keep_file "${basename}" "${GPU_TARGETS}"; then
            echo "  Removing unsupported GPU device lib: ${basename}"
            rm -f "${libfile}"
        fi
    done < <(find "${staging_dir}" -maxdepth 1 -type f \( -name '*.bc' -o -name '*.hsaco' -o -name '*.co' -o -name '*.dat' \))
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

echo "Step 4.5: Filtering device library bitcode for GPU_TARGETS..."
filter_device_libs "${SDK_STAGING}"

echo "Step 5: Splitting SDK into six content-based artifacts..."

# DIAG: Show what's in the SDK staging before partitioning
echo "  [DIAG] SDK staging top-level directories:"
for d in "${SDK_STAGING}"/*/; do
    if [ -d "$d" ]; then
        dname=$(basename "$d")
        dsize=$(du -sh "$d" 2>/dev/null | cut -f1)
        dbytes=$(du -sb "$d" 2>/dev/null | cut -f1)
        echo "    ${dname}: ${dsize} (${dbytes} bytes)"
    fi
done
if [ -d "${SDK_STAGING}/lib" ]; then
    echo "  [DIAG] SDK staging lib/ subdirectories:"
    for d in "${SDK_STAGING}/lib/"*/; do
        if [ -d "$d" ]; then
            dname=$(basename "$d")
            dsize=$(du -sh "$d" 2>/dev/null | cut -f1)
            dbytes=$(du -sb "$d" 2>/dev/null | cut -f1)
            echo "    lib/${dname}: ${dsize} (${dbytes} bytes)"
        fi
    done
fi

SDK_COMPILER="rocm-${ROCM_VERSION}-sdk-compiler.tar.gz"
SDK_DEVICE_LIBS="rocm-${ROCM_VERSION}-sdk-device-libs.tar.gz"
SDK_CORE_LIBS="rocm-${ROCM_VERSION}-sdk-core-libs.tar.gz"
SDK_BLAS="rocm-${ROCM_VERSION}-sdk-blas.tar.gz"
SDK_MATH="rocm-${ROCM_VERSION}-sdk-math.tar.gz"

# --- Define content partitions ---

# sdk-blas: BLAS libraries with Tensile kernel data
SDK_BLAS_DIRS=(
    "lib/rocblas"
    "lib/hipblaslt"
    "lib/composablekernel"
)
SDK_BLAS_LIBS=(
    "librocblas.so*"
    "libhipblas.so*"
    "libhipblas-common.so*"
    "libhipblaslt.so*"
)

# sdk-math: sparse/solver/random math libraries
SDK_MATH_DIRS=(
    "lib/rocsparse"
    "lib/rocsolver"
    "lib/rocwmma"
)
SDK_MATH_LIBS=(
    "librocsparse.so*"
    "librocsolver.so*"
    "libhipsparse.so*"
    "libhipsolver.so*"
    "libhiprand.so*"
    "librocrand.so*"
)

# --- Create component staging directories ---
STAGING_COMPILER="${SDK_STAGING}-compiler"
STAGING_DEVICE_LIBS="${SDK_STAGING}-device-libs"
STAGING_CORE_LIBS="${SDK_STAGING}-core-libs"
STAGING_BLAS="${SDK_STAGING}-blas"
STAGING_MATH="${SDK_STAGING}-math"

rm -rf "${STAGING_COMPILER}" "${STAGING_DEVICE_LIBS}" "${STAGING_CORE_LIBS}" "${STAGING_BLAS}" "${STAGING_MATH}"
mkdir -p "${STAGING_COMPILER}" "${STAGING_DEVICE_LIBS}" "${STAGING_CORE_LIBS}" "${STAGING_BLAS}" "${STAGING_MATH}"

# ---- sdk-blas ----
echo "  Partitioning: sdk-blas (BLAS libraries + Tensile kernels)..."

mkdir -p "${STAGING_BLAS}/lib"

for dir in "${SDK_BLAS_DIRS[@]}"; do
    if [ -d "${SDK_STAGING}/${dir}" ]; then
        mkdir -p "$(dirname "${STAGING_BLAS}/${dir}")"
        cp -a "${SDK_STAGING}/${dir}" "${STAGING_BLAS}/${dir}"
        echo "    + ${dir}/"
    fi
done

for lib in "${SDK_BLAS_LIBS[@]}"; do
    matches=$(find "${SDK_STAGING}/lib" -maxdepth 1 -name "${lib}" 2>/dev/null || true)
    for f in ${matches}; do
        if [ -e "$f" ]; then
            cp -a "$f" "${STAGING_BLAS}/lib/"
            echo "    + lib/$(basename "$f")"
        fi
    done
done

# ---- sdk-math ----
echo "  Partitioning: sdk-math (sparse/solver/random libraries)..."

mkdir -p "${STAGING_MATH}/lib"

for dir in "${SDK_MATH_DIRS[@]}"; do
    if [ -d "${SDK_STAGING}/${dir}" ]; then
        mkdir -p "$(dirname "${STAGING_MATH}/${dir}")"
        cp -a "${SDK_STAGING}/${dir}" "${STAGING_MATH}/${dir}"
        echo "    + ${dir}/"
    fi
done

for lib in "${SDK_MATH_LIBS[@]}"; do
    matches=$(find "${SDK_STAGING}/lib" -maxdepth 1 -name "${lib}" 2>/dev/null || true)
    for f in ${matches}; do
        if [ -e "$f" ]; then
            cp -a "$f" "${STAGING_MATH}/lib/"
            echo "    + lib/$(basename "$f")"
        fi
    done
done

# ---- sdk-core-libs: all lib/*.so* files (except BLAS/MATH) ----
# Includes LLVM shared libraries from lib/llvm/lib/
echo "  Partitioning: sdk-core-libs (core shared libraries)..."

mkdir -p "${STAGING_CORE_LIBS}/lib"

# Root-level lib/*.so* files (except BLAS/MATH patterns)
find "${SDK_STAGING}/lib" -maxdepth 1 \( -name '*.so' -o -name '*.so.*' \) \( -type f -o -type l \) | while IFS= read -r f; do
    fname=$(basename "$f")
    skip=false

    # Skip if matches BLAS pattern
    for lib in "${SDK_BLAS_LIBS[@]}"; do
        eval "case \"\${fname}\" in ${lib}) skip=true; break ;; esac"
    done
    [ "${skip}" = true ] && continue

    # Skip if matches MATH pattern
    for lib in "${SDK_MATH_LIBS[@]}"; do
        eval "case \"\${fname}\" in ${lib}) skip=true; break ;; esac"
    done
    [ "${skip}" = true ] && continue

    cp -a "$f" "${STAGING_CORE_LIBS}/lib/"
    echo "    + lib/${fname}"
done

# LLVM shared libraries from lib/llvm/lib/
if [ -d "${SDK_STAGING}/lib/llvm/lib" ]; then
    find "${SDK_STAGING}/lib/llvm/lib" -maxdepth 1 \( -name '*.so' -o -name '*.so.*' \) \( -type f -o -type l \) | while IFS= read -r f; do
        cp -a "$f" "${STAGING_CORE_LIBS}/lib/"
        echo "    + lib/llvm/$(basename "$f")"
    done
fi

# ---- sdk-device-libs: lib/ non-.so* files (device library bitcode) ----
# Special handling for lib/llvm/: compiler toolchain lives here, skip it.
# lib/llvm/ files go to compiler (bin, include, cmake, share) or core-libs (.so).
echo "  Partitioning: sdk-device-libs (device library bitcode)..."

mkdir -p "${STAGING_DEVICE_LIBS}/lib"

(cd "${SDK_STAGING}" && find lib -type f \( ! -name '*.so' ! -name '*.so.*' \)) | while IFS= read -r entry; do
    rel="${entry#lib/}"
    fname=$(basename "${entry}")
    skip=false

    # Skip lib/llvm/ entirely - those are compiler toolchain files
    if [[ "${rel}" == llvm/* ]]; then
        skip=true
    fi
    # Skip lib/clang/ and lib/amdgcn-amd-amdhsa/ - explicitly copied below
    if [[ "${rel}" == clang/* ]] || [[ "${rel}" == amdgcn-amd-amdhsa/* ]]; then
        skip=true
    fi
    [ "${skip}" = true ] && continue

    # Skip if in BLAS or MATH subdirectories
    for dir in "${SDK_BLAS_DIRS[@]}"; do
        dir_base="${dir#lib/}"
        if [[ "${rel}" == "${dir_base}"/* ]] || [[ "${rel}" == "${dir_base}" ]]; then
            skip=true; break
        fi
    done
    [ "${skip}" = true ] && continue

    for dir in "${SDK_MATH_DIRS[@]}"; do
        dir_base="${dir#lib/}"
        if [[ "${rel}" == "${dir_base}"/* ]] || [[ "${rel}" == "${dir_base}" ]]; then
            skip=true; break
        fi
    done
    [ "${skip}" = true ] && continue

    dest_dir="${STAGING_DEVICE_LIBS}/lib/$(dirname "${rel}")"
    mkdir -p "${dest_dir}"
    cp -a "${SDK_STAGING}/${entry}" "${dest_dir}/"
    echo "    + lib/${rel}"
done

# GPU-specific clang resources and AMDGPU toolchain libs
# These are device compilation resources that belong with device library bitcode
if [ -d "${SDK_STAGING}/lib/llvm/lib/clang" ]; then
    mkdir -p "${STAGING_DEVICE_LIBS}/lib/clang"
    cp -a "${SDK_STAGING}/lib/llvm/lib/clang" "${STAGING_DEVICE_LIBS}/lib/"
    echo "    + lib/llvm/lib/clang/"
fi
# amdgcn-amd-amdhsa may be at root level or under llvm/
if [ -d "${SDK_STAGING}/lib/amdgcn-amd-amdhsa" ]; then
    mkdir -p "${STAGING_DEVICE_LIBS}/lib/amdgcn-amd-amdhsa"
    cp -a "${SDK_STAGING}/lib/amdgcn-amd-amdhsa" "${STAGING_DEVICE_LIBS}/lib/"
    echo "    + lib/amdgcn-amd-amdhsa/"
elif [ -d "${SDK_STAGING}/lib/llvm/lib/amdgcn-amd-amdhsa" ]; then
    mkdir -p "${STAGING_DEVICE_LIBS}/lib/amdgcn-amd-amdhsa"
    cp -a "${SDK_STAGING}/lib/llvm/lib/amdgcn-amd-amdhsa" "${STAGING_DEVICE_LIBS}/lib/"
    echo "    + lib/llvm/lib/amdgcn-amd-amdhsa/"
fi

# ---- sdk-compiler: everything else (bin, include, cmake, share, etc.) ----
echo "  Partitioning: sdk-compiler (compilers, headers, cmake, remaining)..."

# DIAG: trace the compiler find loop to debug skip logic
echo "  [DIAG-COMPILER] Starting find loop, entries processed:"
(cd "${SDK_STAGING}" && find . -mindepth 1) | while IFS= read -r entry; do
    rel="${entry#./}"
    skip=false
    skip_reason=""

    # Skip BLAS directories
    for dir in "${SDK_BLAS_DIRS[@]}"; do
        if [ "${rel}" = "${dir}" ] || [[ "${rel}" == "${dir}/"* ]]; then
            skip=true; skip_reason="blas dir: ${dir}"; break
        fi
    done
    [ "${skip}" = true ] && { echo "    SKIP [${skip_reason}]: ${rel}"; continue; }

    # Skip MATH directories
    for dir in "${SDK_MATH_DIRS[@]}"; do
        if [ "${rel}" = "${dir}" ] || [[ "${rel}" == "${dir}/"* ]]; then
            skip=true; skip_reason="math dir: ${dir}"; break
        fi
    done
    [ "${skip}" = true ] && { echo "    SKIP [${skip_reason}]: ${rel}"; continue; }

    # Skip lib/ files (they go to core-libs, blas, math, or device-libs)
    if [[ "${rel}" == lib/* ]]; then
        skip=true; skip_reason="lib/*"
    fi
    # Skip top-level llvm/ directory (duplicate of lib/llvm/, captured elsewhere)
    if [[ "${rel}" == llvm/* ]]; then
        skip=true; skip_reason="llvm/*"
    fi
    # Skip top-level amdgcn/ directory (duplicate of lib/llvm/lib/amdgcn-amd-amdhsa)
    if [[ "${rel}" == amdgcn/* ]]; then
        skip=true; skip_reason="amdgcn/*"
    fi
    [ "${skip}" = true ] && { echo "    SKIP [${skip_reason}]: ${rel}"; continue; }

    echo "    COPY: ${rel}"
    dest="${STAGING_COMPILER}/${rel}"
    mkdir -p "$(dirname "${dest}")"
    cp -a "${SDK_STAGING}/${rel}" "${dest}"
done
echo "  [DIAG-COMPILER] Find loop complete."

# LLVM toolchain files from lib/llvm/ (binaries, headers, clang resources)
if [ -d "${SDK_STAGING}/lib/llvm" ]; then
    echo "  Partitioning: lib/llvm/ toolchain into compiler..."
    # Copy bin/, include/, share/, cmake/ from lib/llvm/
    for subdir in bin include share cmake; do
        if [ -d "${SDK_STAGING}/lib/llvm/${subdir}" ]; then
            mkdir -p "${STAGING_COMPILER}/${subdir}"
            cp -a "${SDK_STAGING}/lib/llvm/${subdir}" "${STAGING_COMPILER}/"
            echo "    + lib/llvm/${subdir}/"
        fi
    done
    # Copy lib/cmake/ (LLVM cmake config)
    if [ -d "${SDK_STAGING}/lib/llvm/lib/cmake" ]; then
        mkdir -p "${STAGING_COMPILER}/lib/cmake"
        cp -a "${SDK_STAGING}/lib/llvm/lib/cmake" "${STAGING_COMPILER}/lib/"
        echo "    + lib/llvm/lib/cmake/"
    fi
    # Copy lib/libunwind.a and other static libs from lib/llvm/lib/
    if [ -d "${SDK_STAGING}/lib/llvm/lib" ]; then
        find "${SDK_STAGING}/lib/llvm/lib" -maxdepth 1 -type f \( -name '*.a' -o -name '*.la' \) | while IFS= read -r f; do
            cp -a "$f" "${STAGING_COMPILER}/lib/"
            echo "    + lib/llvm/lib/$(basename "$f")"
        done
    fi
    # Copy lib-debug/ (LLVM debug symbols from openmp-extras)
    if [ -d "${SDK_STAGING}/lib/llvm/lib-debug" ]; then
        mkdir -p "${STAGING_COMPILER}/lib-debug"
        cp -a "${SDK_STAGING}/lib/llvm/lib-debug" "${STAGING_COMPILER}/"
        echo "    + lib/llvm/lib-debug/"
    fi
fi

# ---- Create tarballs ----
echo "  Creating tarballs..."

# Diagnostic: report compiler partition sizes by top-level directory
echo "  [DIAG] Compiler partition top-level directory sizes:"
for d in "${STAGING_COMPILER}"/*/; do
    if [ -d "$d" ]; then
        dname=$(basename "$d")
        dsize=$(du -sh "$d" 2>/dev/null | cut -f1)
        echo "    ${dname}: ${dsize}"
    fi
done

tar -czf "${SDK_COMPILER}" -C "${STAGING_COMPILER}" .
SDK_COMPILER_SIZE=$(du -h "${SDK_COMPILER}" | cut -f1)
echo "    sdk-compiler:   ${SDK_COMPILER} (${SDK_COMPILER_SIZE})"

tar -czf "${SDK_DEVICE_LIBS}" -C "${STAGING_DEVICE_LIBS}" .
SDK_DEVICE_LIBS_SIZE=$(du -h "${SDK_DEVICE_LIBS}" | cut -f1)
echo "    sdk-device-libs: ${SDK_DEVICE_LIBS} (${SDK_DEVICE_LIBS_SIZE})"

tar -czf "${SDK_CORE_LIBS}" -C "${STAGING_CORE_LIBS}" .
SDK_CORE_LIBS_SIZE=$(du -h "${SDK_CORE_LIBS}" | cut -f1)
echo "    sdk-core-libs:  ${SDK_CORE_LIBS} (${SDK_CORE_LIBS_SIZE})"

tar -czf "${SDK_BLAS}" -C "${STAGING_BLAS}" .
SDK_BLAS_SIZE=$(du -h "${SDK_BLAS}" | cut -f1)
echo "    sdk-blas:       ${SDK_BLAS} (${SDK_BLAS_SIZE})"

tar -czf "${SDK_MATH}" -C "${STAGING_MATH}" .
SDK_MATH_SIZE=$(du -h "${SDK_MATH}" | cut -f1)
echo "    sdk-math:       ${SDK_MATH} (${SDK_MATH_SIZE})"

rm -rf "${STAGING_COMPILER}" "${STAGING_DEVICE_LIBS}" "${STAGING_CORE_LIBS}" "${STAGING_BLAS}" "${STAGING_MATH}" "${SDK_TEMP}" "${SDK_DIST}" "${SDK_STAGING}"

echo ""
echo "Done! Built six bundles:"
echo "  - ${RUNTIME_TARBALL} (${RUNTIME_SIZE})"
echo "  - ${SDK_COMPILER} (${SDK_COMPILER_SIZE})"
echo "  - ${SDK_DEVICE_LIBS} (${SDK_DEVICE_LIBS_SIZE})"
echo "  - ${SDK_CORE_LIBS} (${SDK_CORE_LIBS_SIZE})"
echo "  - ${SDK_BLAS} (${SDK_BLAS_SIZE})"
echo "  - ${SDK_MATH} (${SDK_MATH_SIZE})"
