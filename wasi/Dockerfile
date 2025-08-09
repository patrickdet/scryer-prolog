# Dockerfile for WASI build environment
FROM rust:1.85-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
  clang \
  lld \
  llvm \
  pkg-config \
  libssl-dev \
  ca-certificates \
  curl \
  git \
  && rm -rf /var/lib/apt/lists/*

# Add WASM targets
RUN rustup target add wasm32-wasip2

# Install Rust tools for WASI development
RUN cargo install --locked \
  cargo-component@0.21.1 \
  wasm-tools@1.235.0 \
  wit-deps-cli

# Install wasmtime (detect architecture)
RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "x86_64" ]; then \
  WASMTIME_ARCH="x86_64"; \
  elif [ "$ARCH" = "aarch64" ]; then \
  WASMTIME_ARCH="aarch64"; \
  else \
  echo "Unsupported architecture: $ARCH" && exit 1; \
  fi && \
  WASMTIME_VERSION="28.0.0" && \
  curl -sSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}/wasmtime-v${WASMTIME_VERSION}-${WASMTIME_ARCH}-linux.tar.xz" | \
  tar -xJ -C /usr/local/bin --strip-components 1 "wasmtime-v${WASMTIME_VERSION}-${WASMTIME_ARCH}-linux/wasmtime"

# Set environment variables for WASM compilation
ENV CC_wasm32_wasip2=clang \
  AR_wasm32_wasip2=llvm-ar \
  CFLAGS_wasm32_wasip2=-O3

# Create a non-root user for building
RUN useradd -m -u 1000 -s /bin/bash builder

# Set up cargo directories with proper permissions
RUN mkdir -p /usr/local/cargo/registry && \
  chown -R builder:builder /usr/local/cargo

# Switch to non-root user
USER builder

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
