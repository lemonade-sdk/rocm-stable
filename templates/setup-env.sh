#!/bin/bash
# ROCm 7.2 Runtime Environment Setup Script
# Source this script to configure your environment for llama.cpp with bundled ROCm libraries
#
# Usage:
#   source setup-env.sh
#
# Or from a different directory:
#   source /path/to/rocm-7.2-runtime/setup-env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add ROCm runtime libraries to library path
export LD_LIBRARY_PATH="${SCRIPT_DIR}:${LD_LIBRARY_PATH}"

# Set ROCM_PATH to point to our bundled runtime
export ROCM_PATH="${SCRIPT_DIR}"

# Optional: Set HSA_OVERRIDE_GFX_VERSION if needed for your GPU
# Uncomment and set appropriately for your hardware:
#
# Common values:
#   - gfx906  : AMD Radeon VII, MI50/60
#   - gfx908  : MI100
#   - gfx90a  : MI210/250
#   - gfx1030 : RX 6900 XT, RX 6800 XT
#   - gfx1100 : RX 7900 XTX, RX 7900 XT
#   - gfx1101 : RX 7600, RX 7700 XT, RX 7800 XT
#
# export HSA_OVERRIDE_GFX_VERSION=10.3.0

echo "=============================================="
echo "ROCm 7.2 Runtime Environment Configured"
echo "=============================================="
echo "Libraries loaded from: ${SCRIPT_DIR}"
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
echo ""
echo "You can now run llama.cpp binaries with ROCm support."
echo ""
echo "If you encounter GPU compatibility issues, you may need to set:"
echo "  export HSA_OVERRIDE_GFX_VERSION=<your_gpu_version>"
echo "=============================================="
