# ROCm 7.2 Runtime Bundle for llama.cpp

This repository provides a standalone bundle of ROCm 7.2 runtime libraries, enabling you to run llama.cpp binaries with AMD GPU (HIP) support **without requiring a full ROCm installation** on your system.

## Overview

The llama.cpp project distributes pre-built binaries for ROCm 7.2, but these binaries require ROCm runtime libraries to function. Installing the full ROCm stack (~5GB) can be cumbersome and may conflict with existing system configurations.

This project solves that problem by:
1. Extracting only the essential ROCm 7.2 runtime libraries from the official ROCm container
2. Packaging them as a portable, self-contained bundle (~500MB-1GB)
3. Providing simple environment setup scripts for immediate use

## Quick Start

### Download Pre-built Bundle

Download the latest release from the [Releases](../../releases) page:

```bash
# Download ROCm runtime bundle
wget https://github.com/lemonade-sdk/rocm-stable/releases/latest/download/rocm-7.2-runtime-libs.tar.gz

# Download llama.cpp ROCm binaries (example)
wget https://github.com/ggml-org/llama.cpp/releases/download/b8192/llama-b8192-bin-ubuntu-rocm-7.2-x64.tar.gz

# Extract both
tar -xzf llama-b8192-bin-ubuntu-rocm-7.2-x64.tar.gz
tar -xzf rocm-7.2-runtime-libs.tar.gz

# Run with ROCm support
cd llama-b8192-bin-ubuntu-rocm-7.2-x64
source ../rocm-7.2-runtime/setup-env.sh
./llama-cli --version
```

### Verify Installation

Check that ROCm libraries are properly loaded:

```bash
# Check binary dependencies
ldd ./llama-cli | grep -i rocm

# Test GPU detection
./llama-cli --version
```

## What's Included

The runtime bundle contains:

### Core Libraries
- `libamdhip64.so*` - HIP runtime for AMD GPUs
- `libhsa-runtime64.so*` - Heterogeneous System Architecture runtime
- `libhipblas.so*`, `libhipblaslt.so*` - HIP BLAS libraries
- `librocblas.so*` - ROCm BLAS implementation
- `librocsparse.so*` - ROCm sparse linear algebra
- `libamd_comgr.so*` - AMD Code Object Manager
- `libhsakmt.so*` - HSA Kernel Mode Thunk
- `libdrm.so*`, `libdrm_amdgpu.so*` - Direct Rendering Manager

### GPU Kernels
- `rocblas/` - Pre-compiled GPU kernels for BLAS operations
- `hipblaslt/` - Pre-compiled GPU kernels for BLAS LT operations

### Helper Scripts
- `setup-env.sh` - Automatic environment configuration
- `README.md` - Detailed usage instructions

## System Requirements

- **GPU**: AMD GPU with ROCm support (see [compatibility list](https://rocm.docs.amd.com/en/latest/release/gpu_os_support.html))
- **OS**: Linux with AMDGPU kernel driver
- **Kernel**: Recent Linux kernel (5.15+) with AMDGPU driver loaded
- **No ROCm installation required** on the host system

### Verify GPU Support

Check if your GPU is detected:

```bash
# Check if AMDGPU driver is loaded
lsmod | grep amdgpu

# List GPU devices
ls -la /dev/dri/

# Get GPU information (if rocminfo is installed)
rocminfo | grep gfx
```

## Usage

### Environment Setup

The bundle includes a `setup-env.sh` script that configures your environment:

```bash
source rocm-7.2-runtime/setup-env.sh
```

This script:
- Sets `LD_LIBRARY_PATH` to include the bundled libraries
- Sets `ROCM_PATH` to point to the bundle directory
- Displays configuration information

### Manual Configuration

If you prefer manual setup:

```bash
export LD_LIBRARY_PATH=/path/to/rocm-7.2-runtime:${LD_LIBRARY_PATH}
export ROCM_PATH=/path/to/rocm-7.2-runtime
```

### GPU Architecture Override

Some GPUs may require architecture version override:

```bash
export HSA_OVERRIDE_GFX_VERSION=<version>
```

Common values:
- `9.0.6` - Radeon VII, MI50/60
- `9.0.8` - MI100
- `9.0.a` - MI210/250
- `10.3.0` - RX 6900 XT, RX 6800 XT
- `11.0.0` - RX 7900 XTX, RX 7900 XT
- `11.0.1` - RX 7600, RX 7700/7800 XT

## Building from Source

### Prerequisites

- `bash`
- `wget`
- `tar`
- `ar` (usually part of `binutils`)
- `zstd` (for extracting some `.deb` packages)
- ~10GB free disk space (mostly for temporary extraction)

### Build Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/YOUR-USERNAME/rocm-7.2.git
   cd rocm-7.2
   ```

2. Run the build script:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

3. The script will:
   - Download official ROCm 7.2 `.deb` packages from the AMD repository
   - Extract runtime libraries and kernels without installing them to your system
   - Create a portable `rocm-7.2-runtime-libs.tar.gz` bundle

4. Find the bundle in the current directory:
   ```bash
   ls -lh rocm-7.2-runtime-libs.tar.gz
   ```

## Compatibility

### llama.cpp Versions

This bundle is compatible with llama.cpp binaries built for ROCm 7.2. Check the llama.cpp release notes to ensure you're downloading the correct binaries.

Example compatible releases:
- llama.cpp `b8192` and later (Ubuntu ROCm 7.2 builds)
- Any llama.cpp binary tagged with `rocm-7.2`

### ROCm Version

This bundle is specifically for **ROCm 7.2**. Using it with binaries built for other ROCm versions (6.x, 7.0, 7.1) may result in undefined behavior or crashes.

## Troubleshooting

### Library Not Found

**Error:**
```
error while loading shared libraries: libamdhip64.so.6: cannot open shared object file
```

**Solution:**
Ensure you've sourced the setup script:
```bash
source rocm-7.2-runtime/setup-env.sh
```

Or manually set `LD_LIBRARY_PATH`:
```bash
export LD_LIBRARY_PATH=/path/to/rocm-7.2-runtime:${LD_LIBRARY_PATH}
```

### GPU Not Detected

**Error:**
```
ggml_init_cublas: GGML_CUDA_FORCE_MMQ:   no
ggml_init_cublas: CUDA_USE_TENSOR_CORES: yes
ggml_init_cublas: found 0 ROCm devices:
```

**Solutions:**

1. Verify AMDGPU driver is loaded:
   ```bash
   lsmod | grep amdgpu
   ```

2. Check GPU devices exist:
   ```bash
   ls /dev/dri/
   ```
   You should see `renderD128` or similar devices.

3. Ensure your user has access to GPU devices:
   ```bash
   groups
   ```
   You should be in the `video` or `render` group. If not:
   ```bash
   sudo usermod -a -G video,render $USER
   # Log out and back in
   ```

### GPU Architecture Mismatch

**Error:**
```
HSA Error: Incompatible kernel
```

**Solution:**
Set the GPU architecture override:
```bash
export HSA_OVERRIDE_GFX_VERSION=<your_version>
```

Find your GPU version:
```bash
rocminfo | grep gfx
```

### Performance Issues

If you experience poor performance:

1. **Check GPU utilization:**
   ```bash
   watch -n 1 rocm-smi
   ```

2. **Verify power management:**
   Some GPUs may be in power-saving mode. Check your GPU power state.

3. **Monitor thermals:**
   Ensure adequate cooling and that the GPU isn't thermal throttling.

## How It Works

### Extraction Process

1. The `build.sh` script downloads official ROCm 7.2 `.deb` packages for Ubuntu 24.04 (Noble)
2. It uses `ar` and `tar` to extract the package contents without requiring root or a package manager
3. It copies essential runtime libraries and GPU kernel directories (`rocblas/`, `hipblaslt/`)
4. It packages everything with helper scripts into a portable tarball

### Why This Approach?

- **Portable**: No system installation required
- **Isolated**: Doesn't conflict with existing ROCm installations
- **Minimal**: Only includes runtime libraries, not development tools
- **Flexible**: Users can easily switch between ROCm versions

## Automated Releases

This repository uses GitHub Actions to automatically build and release the ROCm runtime bundle when tags are pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow will:
1. Build the Docker image
2. Extract the runtime bundle
3. Generate checksums
4. Create a GitHub release with the bundle attached

## Contributing

Contributions are welcome! Please feel free to:
- Report issues
- Suggest improvements
- Submit pull requests
- Share your use cases

## License

This repository's build scripts and documentation are released under the MIT License.

The ROCm libraries themselves are licensed under MIT and Apache 2.0 licenses by AMD. See the [ROCm repository](https://github.com/RadeonOpenCompute/ROCm) for details.

## Disclaimer

This is an **unofficial** redistribution of ROCm runtime libraries for convenience. For official ROCm releases and support, visit:
- [ROCm GitHub](https://github.com/RadeonOpenCompute/ROCm)
- [ROCm Documentation](https://rocm.docs.amd.com/)

## Acknowledgments

- AMD for developing and maintaining ROCm
- llama.cpp team for providing excellent AMD GPU support
- The open-source community for testing and feedback

## Related Projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Fast LLM inference
- [ROCm](https://github.com/RadeonOpenCompute/ROCm) - AMD GPU compute platform
- [HIP](https://github.com/ROCm-Developer-Tools/HIP) - GPU runtime API

## Support

- **Issues with this bundle**: [Open an issue](../../issues)
- **llama.cpp questions**: Visit [llama.cpp repository](https://github.com/ggml-org/llama.cpp)
- **ROCm support**: Visit [ROCm documentation](https://rocm.docs.amd.com/)
