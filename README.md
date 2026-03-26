# ROCm 7.2.1 Runtime Bundle for llama.cpp

This repository provides a standalone bundle of ROCm 7.2.1 runtime libraries, enabling you to run llama.cpp binaries with AMD GPU (HIP) support **without requiring a full ROCm installation** on your system.

## Overview

The llama.cpp project distributes pre-built binaries for ROCm 7.2.1, but these binaries require ROCm runtime libraries to function. Installing the full ROCm stack (~5GB) can be cumbersome and may conflict with existing system configurations.

This project solves that problem by:
1. Extracting only the essential ROCm 7.2.1 runtime libraries from the official ROCm container
2. Packaging them as a portable, self-contained bundle (~500MB-1GB)
3. Providing simple environment setup scripts for immediate use

## Quick Start

### Download Pre-built Bundle

Download the latest release from the [Releases](../../releases) page:

```bash
# Download ROCm runtime bundle
wget https://github.com/lemonade-sdk/rocm-stable/releases/latest/download/rocm-7.2.1-runtime-libs.tar.gz

# Download llama.cpp ROCm binaries (example)
wget https://github.com/ggml-org/llama.cpp/releases/download/b8192/llama-b8192-bin-ubuntu-rocm-7.2.1-x64.tar.gz

# Extract both
tar -xzf llama-b8192-bin-ubuntu-rocm-7.2.1-x64.tar.gz
tar -xzf rocm-7.2.1-runtime-libs.tar.gz

# Run with ROCm support
cd llama-b8192-bin-ubuntu-rocm-7.2.1-x64
source ../rocm-7.2.1-runtime/setup-env.sh
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
source rocm-7.2.1-runtime/setup-env.sh
```

This script:
- Sets `LD_LIBRARY_PATH` to include the bundled libraries
- Sets `ROCM_PATH` to point to the bundle directory
- Displays configuration information

### Manual Configuration

If you prefer manual setup:

```bash
export LD_LIBRARY_PATH=/path/to/rocm-7.2.1-runtime:${LD_LIBRARY_PATH}
export ROCM_PATH=/path/to/rocm-7.2.1-runtime
```

## Compatibility

### llama.cpp Versions

This bundle is compatible with llama.cpp binaries built for ROCm 7.2 and 7.2.1. Check the llama.cpp release notes to ensure you're downloading the correct binaries.

## Troubleshooting

### Library Not Found

**Error:**
```
error while loading shared libraries: libamdhip64.so.6: cannot open shared object file
```

**Solution:**
Ensure you've sourced the setup script:
```bash
source rocm-7.2.1-runtime/setup-env.sh
```

Or manually set `LD_LIBRARY_PATH`:
```bash
export LD_LIBRARY_PATH=/path/to/rocm-7.2.1-runtime:${LD_LIBRARY_PATH}
```

This repository's build scripts and documentation are released under the MIT License.

The ROCm libraries themselves are licensed under MIT and Apache 2.0 licenses by AMD. See the [ROCm repository](https://github.com/RadeonOpenCompute/ROCm) for details.

## Disclaimer

This is an **unofficial** redistribution of ROCm runtime libraries for convenience. For official ROCm releases and support, visit:
- [ROCm GitHub](https://github.com/ROCm/ROCm)
- [ROCm Documentation](https://rocm.docs.amd.com/)

## Acknowledgments

- AMD for developing and maintaining ROCm
- llama.cpp team for providing excellent AMD GPU support
- The open-source community for testing and feedback

## Related Projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Fast LLM inference
- [ROCm](https://github.com/ROCm/ROCm) - AMD GPU compute platform

## Support

- **Issues with this bundle**: [Open an issue](../../issues)
- **llama.cpp questions**: Visit [llama.cpp repository](https://github.com/ggml-org/llama.cpp)
- **ROCm support**: Visit [ROCm documentation](https://rocm.docs.amd.com/)
