# ROCm 7.2 Runtime Library Bundle Builder
# This Dockerfile extracts the necessary ROCm runtime libraries from the official
# ROCm container and packages them for standalone distribution.

FROM rocm/dev-ubuntu-24.04:7.2 AS extractor

# Create working directory for the runtime package
WORKDIR /rocm-runtime

# Move required shared libraries from ROCm installation
# These are the core libraries needed for llama.cpp HIP backend
RUN mv /opt/rocm/lib/librocsparse.so* . && \
    mv /opt/rocm/lib/libhsa-runtime64.so* . && \
    mv /opt/rocm/lib/libamdhip64.so* . && \
    mv /opt/rocm/lib/libhipblas.so* . && \
    mv /opt/rocm/lib/libhipblaslt.so* . && \
    mv /opt/rocm/lib/librocblas.so* . && \
    mv /opt/rocm/lib/libamd_comgr.so* . && \
    mv /opt/rocm/lib/libhsakmt.so* . && \
    mv /opt/rocm/lib/libdrm.so* . && \
    mv /opt/rocm/lib/libdrm_amdgpu.so* . && \
    mv /opt/rocm/lib/rocblas . && \
    mv /opt/rocm/lib/hipblaslt .

# Copy template files into the package
COPY templates/setup-env.sh .
COPY templates/README-package.md README.md

# Make setup script executable
RUN chmod +x setup-env.sh

# Create the final tarball
RUN tar -czf /rocm-7.2-runtime-libs.tar.gz -C /rocm-runtime .

# Final stage - minimal image with just the tarball
FROM scratch AS export
COPY --from=extractor /rocm-7.2-runtime-libs.tar.gz /
