# ROCm 7.2.1 Runtime Libraries Bundle

This package contains the essential ROCm 7.2.1 runtime libraries needed to run llama.cpp binaries with HIP (AMD GPU) support, without requiring a full ROCm installation on your system.

## What's Included

### Shared Libraries
- `libamdhip64.so*` - HIP runtime
- `libhsa-runtime64.so*` - HSA runtime
- `libhipblas.so*` - HIP BLAS library
- `libhipblaslt.so*` - HIP BLAS LT library
- `librocblas.so*` - ROCm BLAS library
- `librocsparse.so*` - ROCm sparse linear algebra
- `libamd_comgr.so*` - AMD compiler runtime
- `libhsakmt.so*` - HSA kernel mode thunk
- `libdrm.so*` - Direct Rendering Manager
- `libdrm_amdgpu.so*` - AMD GPU DRM support

### Kernel Directories
- `rocblas/` - ROCBlas GPU kernel files
- `hipblaslt/` - HipBLAS LT GPU kernel files

### Helper Scripts
- `setup-env.sh` - Environment configuration script

## System Requirements

- AMD GPU with ROCm support
- Linux kernel with AMDGPU driver support
- No ROCm system installation required

## Usage

### Quick Start

1. Extract this package:
   ```bash
   tar -xzf rocm-7.2.1-runtime-libs.tar.gz
   ```

2. Source the environment setup script:
   ```bash
   source rocm-7.2.1-runtime/setup-env.sh
   ```

3. Run your llama.cpp binary:
   ```bash
   ./llama-cli --version
   ```

### Using with llama.cpp

Download the llama.cpp ROCm binaries from their releases page, then combine with this runtime package:

```bash
# Download llama.cpp ROCm binaries (example)
wget https://github.com/ggml-org/llama.cpp/releases/download/b8192/llama-b8192-bin-ubuntu-rocm-7.2.1-x64.tar.gz

# Download ROCm runtime libraries (from this repository's releases)
wget https://github.com/YOUR-USERNAME/rocm-7.2.1/releases/latest/download/rocm-7.2.1-runtime-libs.tar.gz

# Extract both
tar -xzf llama-b8192-bin-ubuntu-rocm-7.2.1-x64.tar.gz
tar -xzf rocm-7.2.1-runtime-libs.tar.gz

# Run with ROCm support
cd llama-b8192-bin-ubuntu-rocm-7.2.1-x64
source ../rocm-7.2.1-runtime/setup-env.sh
./llama-cli --version
```

### Manual Environment Setup

If you prefer not to use the `setup-env.sh` script, you can manually set the environment variables:

```bash
export LD_LIBRARY_PATH=/path/to/rocm-7.2.1-runtime:${LD_LIBRARY_PATH}
export ROCM_PATH=/path/to/rocm-7.2.1-runtime
```

### GPU Compatibility

If you encounter GPU compatibility errors, you may need to override the GPU architecture version:

```bash
export HSA_OVERRIDE_GFX_VERSION=<your_version>
```

Common values:
- `9.0.6` - AMD Radeon VII, MI50/60
- `9.0.8` - MI100
- `9.0.a` - MI210/250
- `10.3.0` - RX 6900 XT, RX 6800 XT
- `11.0.0` - RX 7900 XTX, RX 7900 XT
- `11.0.1` - RX 7600, RX 7700 XT, RX 7800 XT

You can find your GPU architecture using:
```bash
rocminfo | grep gfx
```

## Troubleshooting

### Library Not Found Errors

If you see errors like:
```
error while loading shared libraries: libamdhip64.so.6: cannot open shared object file
```

Ensure you've sourced the `setup-env.sh` script or correctly set `LD_LIBRARY_PATH`.

### GPU Not Detected

Verify your AMDGPU driver is loaded:
```bash
lsmod | grep amdgpu
```

Check GPU visibility:
```bash
ls /dev/dri/
```

You should see `renderD*` and `card*` devices.

### Performance Issues

For optimal performance:
- Ensure your GPU has adequate power and cooling
- Check system monitoring tools for throttling
- Verify you're using the correct `HSA_OVERRIDE_GFX_VERSION` for your GPU

## Version Information

- **ROCm Version**: 7.2.1
- **Source**: rocm/dev-ubuntu-24.04:7.2.1-complete
- **Compatible with**: llama.cpp binaries built for ROCm 7.2.1

## License

The ROCm libraries are licensed under MIT and Apache 2.0 licenses by AMD.
For full license information, see: https://github.com/RadeonOpenCompute/ROCm

## Support

For issues with:
- **This runtime package**: Open an issue at the repository where you downloaded this package
- **llama.cpp**: Visit https://github.com/ggml-org/llama.cpp
- **ROCm**: Visit https://github.com/RadeonOpenCompute/ROCm
