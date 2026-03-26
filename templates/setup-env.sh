#!/bin/bash
# ROCm 7.2.1 Runtime Environment Setup Script
# Source this script to configure your environment for llama.cpp with bundled ROCm libraries
#
# Usage:
#   source setup-env.sh
#
# Or from a different directory:
#   source /path/to/rocm-7.2.1-runtime/setup-env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${SCRIPT_DIR}:${LD_LIBRARY_PATH}"
export ROCM_PATH="${SCRIPT_DIR}"