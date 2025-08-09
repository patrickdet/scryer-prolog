#!/bin/bash

# Simple test script to verify CLI component can compile
# This script tests the CLI component in isolation

set -e

echo "=== CLI Component Build Test ==="
echo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check current directory
if [ ! -f "Cargo.toml" ]; then
    echo -e "${RED}Error: Must be run from cli-component directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found${NC}"
    echo "Please install Rust: https://rustup.rs/"
    exit 1
fi

# Check if wasm32-wasip2 target is installed
echo "Checking for wasm32-wasip2 target..."
if ! rustup target list --installed | grep -q "wasm32-wasip2"; then
    echo -e "${YELLOW}Installing wasm32-wasip2 target...${NC}"
    rustup target add wasm32-wasip2
else
    echo -e "${GREEN}✓ wasm32-wasip2 target installed${NC}"
fi

# Try a basic cargo check first
echo
echo "Running cargo check..."
if cargo check --target wasm32-wasip2 2>&1; then
    echo -e "${GREEN}✓ Basic syntax check passed${NC}"
else
    echo -e "${RED}✗ Basic syntax check failed${NC}"
    echo "This might be due to missing wit-bindgen macros"
fi

# Try building with regular cargo (not cargo-component)
echo
echo "Attempting regular cargo build..."
if cargo build --target wasm32-wasip2 --release 2>&1; then
    echo -e "${GREEN}✓ Regular cargo build succeeded${NC}"
    echo "Output: target/wasm32-wasip2/release/scryer_prolog_cli.wasm"
    ls -lh target/wasm32-wasip2/release/*.wasm 2>/dev/null || true
else
    echo -e "${YELLOW}Regular cargo build failed (expected without cargo-component)${NC}"
fi

# Check if cargo-component is available
echo
if command -v cargo-component &> /dev/null; then
    echo -e "${GREEN}cargo-component is installed${NC}"
    echo "Attempting component build..."

    if cargo component build --release 2>&1; then
        echo -e "${GREEN}✓ Component build succeeded!${NC}"
        echo "Output: target/wasm32-wasip2/release/scryer_prolog_cli.wasm"
        ls -lh target/wasm32-wasip2/release/*.wasm 2>/dev/null || true
    else
        echo -e "${RED}✗ Component build failed${NC}"
    fi
else
    echo -e "${YELLOW}cargo-component not found${NC}"
    echo "To install: cargo install cargo-component"
    echo "This is required for proper WASI component builds"
fi

echo
echo "=== Build Test Summary ==="

# Check if the WIT files exist
if [ -f "wit/cli.wit" ]; then
    echo -e "${GREEN}✓ CLI WIT file exists${NC}"
else
    echo -e "${RED}✗ CLI WIT file missing${NC}"
fi

if [ -f "wit/deps/scryer-prolog.wit" ]; then
    echo -e "${GREEN}✓ Dependency WIT file exists${NC}"
else
    echo -e "${YELLOW}! Dependency WIT file missing${NC}"
    echo "  This might cause issues with component composition"
fi

# Provide next steps
echo
echo "Next steps:"
echo "1. If cargo-component is not installed:"
echo "   cargo install cargo-component"
echo
echo "2. To build the full CLI component:"
echo "   cargo component build --release"
echo
echo "3. To compose with library component:"
echo "   Use wasm-tools compose with the library component"
