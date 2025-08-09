#!/bin/bash

set -e

echo "Building Scryer Prolog CLI Component..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Change to project root
cd "$PROJECT_ROOT"

# Check if cargo-component is installed
if ! command -v cargo-component &> /dev/null; then
    echo -e "${RED}Error: cargo-component is not installed.${NC}"
    echo "Install it with: cargo install cargo-component"
    echo ""
    echo "cargo-component is required to build WebAssembly components."
    echo "For more information, visit: https://github.com/bytecodealliance/cargo-component"
    exit 1
fi

# Check if wasm-tools is installed
if ! command -v wasm-tools &> /dev/null; then
    echo -e "${RED}Error: wasm-tools is not installed.${NC}"
    echo "Install it with: cargo install wasm-tools"
    echo ""
    echo "wasm-tools is required for component composition."
    echo "For more information, visit: https://github.com/bytecodealliance/wasm-tools"
    exit 1
fi

# Check if wasm32-wasip2 target is installed
if ! rustup target list --installed | grep -q "wasm32-wasip2"; then
    echo -e "${RED}Error: wasm32-wasip2 target is not installed.${NC}"
    echo "Install it with: rustup target add wasm32-wasip2"
    exit 1
fi

# Parse command line arguments
BUILD_MODE="release"
COMPOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            BUILD_MODE="dev"
            shift
            ;;
        --compose)
            COMPOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dev       Build in development mode"
            echo "  --compose   Compose with library component"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Build the library component first if composing
if [ "$COMPOSE" = true ]; then
    echo -e "${YELLOW}Building Scryer Prolog library component...${NC}"

    cd "$PROJECT_ROOT"

    if [ "$BUILD_MODE" = "dev" ]; then
        cargo component build --profile=wasi-dev --features=wasi-component
    else
        cargo component build --profile=wasi-release --features=wasi-component
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build library component${NC}"
        echo ""
        echo "Troubleshooting tips:"
        echo "1. Make sure you're in the scryer-prolog root directory"
        echo "2. Check that the wasi-component feature is available"
        echo "3. Try running: cargo clean && cargo build --features=wasi-component"
        exit 1
    fi

    echo -e "${GREEN}✓ Library component built successfully${NC}"
fi

# Build the CLI component
echo -e "${YELLOW}Building CLI component...${NC}"

cd "$SCRIPT_DIR"

if [ "$BUILD_MODE" = "dev" ]; then
    cargo component build
else
    cargo component build --release
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build CLI component${NC}"
    exit 1
fi

echo -e "${GREEN}✓ CLI component built successfully${NC}"

# Compose components if requested
if [ "$COMPOSE" = true ]; then
    echo -e "${YELLOW}Composing components...${NC}"

    # Determine paths based on build mode
    if [ "$BUILD_MODE" = "dev" ]; then
        LIBRARY_PATH="$PROJECT_ROOT/target/wasm32-wasip2/wasi-dev/scryer_prolog.wasm"
        CLI_PATH="$SCRIPT_DIR/target/wasm32-wasip2/debug/scryer_prolog_cli.wasm"
        OUTPUT_PATH="$PROJECT_ROOT/target/scryer-prolog-cli-debug.wasm"
    else
        LIBRARY_PATH="$PROJECT_ROOT/target/wasm32-wasip2/wasi-release/scryer_prolog.wasm"
        CLI_PATH="$SCRIPT_DIR/target/wasm32-wasip2/release/scryer_prolog_cli.wasm"
        OUTPUT_PATH="$PROJECT_ROOT/target/scryer-prolog-cli.wasm"
    fi

    # Check if component files exist
    if [ ! -f "$LIBRARY_PATH" ]; then
        echo -e "${RED}Error: Library component not found at $LIBRARY_PATH${NC}"
        echo ""
        echo "The library component must be built first. Try one of these:"
        echo "1. Run this script from the cli-component directory with --compose flag"
        echo "2. Build the library manually:"
        echo "   cd ../.. && cargo component build --profile=wasi-${BUILD_MODE} --features=wasi-component"
        echo "3. Check if the path is correct: $LIBRARY_PATH"
        exit 1
    fi

    if [ ! -f "$CLI_PATH" ]; then
        echo -e "${RED}Error: CLI component not found at $CLI_PATH${NC}"
        exit 1
    fi

    # Compose the components
    wasm-tools compose \
        "$LIBRARY_PATH" \
        --plug "$CLI_PATH" \
        -o "$OUTPUT_PATH"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to compose components${NC}"
        echo ""
        echo "Component composition failed. This might be due to:"
        echo "1. Incompatible component interfaces"
        echo "2. Missing imports/exports"
        echo "3. Version mismatches"
        echo ""
        echo "Try running 'wasm-tools validate' on both components:"
        echo "  wasm-tools validate $LIBRARY_PATH"
        echo "  wasm-tools validate $CLI_PATH"
        exit 1
    fi

    echo -e "${GREEN}✓ Components composed successfully${NC}"
    echo -e "${GREEN}Output: $OUTPUT_PATH${NC}"

    # Print usage instructions
    echo ""
    echo "To run the composed CLI:"
    echo "  wasmtime run $OUTPUT_PATH"
    echo ""
    echo "Examples:"
    echo "  # Interactive REPL"
    echo "  wasmtime run $OUTPUT_PATH"
    echo ""
    echo "  # Execute a query"
    echo "  wasmtime run $OUTPUT_PATH -- -q \"member(X, [1,2,3]).\""
    echo ""
    echo "  # Load a file and run REPL"
    echo "  wasmtime run --dir=. $OUTPUT_PATH -- -f examples/family.pl"
else
    # Just built CLI component
    if [ "$BUILD_MODE" = "dev" ]; then
        CLI_PATH="$SCRIPT_DIR/target/wasm32-wasip2/debug/scryer_prolog_cli.wasm"
    else
        CLI_PATH="$SCRIPT_DIR/target/wasm32-wasip2/release/scryer_prolog_cli.wasm"
    fi

    echo -e "${GREEN}✓ Build complete${NC}"
    echo -e "${GREEN}Output: $CLI_PATH${NC}"
    echo ""
    echo -e "${YELLOW}Note: This is just the CLI component wrapper.${NC}"
    echo "To create a usable executable, you need to compose it with the library component."
    echo ""
    echo "Next steps:"
    echo "1. Run with --compose flag: ./build.sh --compose"
    echo "2. Or manually compose later with wasm-tools"
    echo ""
    echo "For more information, see cli-component/README.md"
fi
