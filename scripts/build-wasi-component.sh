#!/bin/bash

# Build script for WASI component model
# This script builds Scryer Prolog as a WASI component

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BUILD_MODE="debug"
PROFILE=""
TARGET_DIR="target/wasm32-wasi"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_MODE="release"
            PROFILE="--profile=wasi-release"
            shift
            ;;
        --dev)
            BUILD_MODE="dev"
            PROFILE="--profile=wasi-dev"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release    Build in release mode (uses wasi-release profile)"
            echo "  --dev        Build in dev mode (uses wasi-dev profile)"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "If no option is specified, builds in debug mode."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Building Scryer Prolog WASI component in ${BUILD_MODE} mode...${NC}"

# Check if wasm-tools is installed
if ! command -v wasm-tools &> /dev/null; then
    echo -e "${RED}Error: wasm-tools is not installed.${NC}"
    echo "Please install wasm-tools:"
    echo "  cargo install wasm-tools"
    echo "or download from:"
    echo "  https://github.com/bytecodealliance/wasm-tools/releases"
    exit 1
fi

# Check if wasm32-wasi target is installed
if ! rustup target list --installed | grep -q "wasm32-wasi"; then
    echo -e "${YELLOW}Installing wasm32-wasi target...${NC}"
    rustup target add wasm32-wasi
fi

# Build the project
echo -e "${GREEN}Building with cargo...${NC}"
if [ -z "$PROFILE" ]; then
    cargo build --target wasm32-wasi --no-default-features --features wasi-component
    WASM_FILE="${TARGET_DIR}/debug/scryer_prolog.wasm"
    OUTPUT_FILE="${TARGET_DIR}/debug/scryer_prolog_component.wasm"
else
    cargo build --target wasm32-wasi --no-default-features --features wasi-component $PROFILE
    if [ "$BUILD_MODE" = "release" ]; then
        WASM_FILE="${TARGET_DIR}/wasi-release/scryer_prolog.wasm"
        OUTPUT_FILE="${TARGET_DIR}/wasi-release/scryer_prolog_component.wasm"
    else
        WASM_FILE="${TARGET_DIR}/wasi-dev/scryer_prolog.wasm"
        OUTPUT_FILE="${TARGET_DIR}/wasi-dev/scryer_prolog_component.wasm"
    fi
fi

# Check if the wasm file was created
if [ ! -f "$WASM_FILE" ]; then
    echo -e "${RED}Error: WASM file not found at $WASM_FILE${NC}"
    exit 1
fi

# Convert to component
echo -e "${GREEN}Converting to WASI component...${NC}"
wasm-tools component new "$WASM_FILE" -o "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${GREEN}✓ WASI component built successfully!${NC}"
    echo -e "${GREEN}  Output: $OUTPUT_FILE${NC}"

    # Show component info
    echo -e "\n${YELLOW}Component info:${NC}"
    wasm-tools component wit "$OUTPUT_FILE" || true
else
    echo -e "${RED}Error: Failed to create component${NC}"
    exit 1
fi
