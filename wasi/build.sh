#!/bin/bash

# Build script for Scryer Prolog WASI components
# This script builds both the library and CLI components and composes them together

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Default values
BUILD_MODE="release"
SKIP_LIBRARY=false
SKIP_CLI=false
SKIP_COMPOSE=false
CLEAN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            BUILD_MODE="dev"
            shift
            ;;
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --debug)
            BUILD_MODE="debug"
            shift
            ;;
        --skip-library)
            SKIP_LIBRARY=true
            shift
            ;;
        --skip-cli)
            SKIP_CLI=true
            shift
            ;;
        --skip-compose)
            SKIP_COMPOSE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Build Scryer Prolog WASI components"
            echo ""
            echo "Options:"
            echo "  --dev              Build in development mode (default: release)"
            echo "  --release          Build in release mode (default)"
            echo "  --debug            Build in debug mode"
            echo "  --skip-library     Skip building the library component"
            echo "  --skip-cli         Skip building the CLI component"
            echo "  --skip-compose     Skip composing the components"
            echo "  --clean            Clean build artifacts before building"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                     # Build everything in release mode"
            echo "  $0 --dev               # Build everything in dev mode"
            echo "  $0 --skip-library      # Only build CLI and compose"
            echo "  $0 --clean --release   # Clean build in release mode"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Scryer Prolog WASI Build ===${NC}"
echo "Build mode: $BUILD_MODE"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for Rust
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found${NC}"
    echo "Please install Rust: https://rustup.rs/"
    exit 1
fi

# Check for wasm32-wasip2 target
if ! rustup target list --installed | grep -q "wasm32-wasip2"; then
    echo -e "${YELLOW}Installing wasm32-wasip2 target...${NC}"
    rustup target add wasm32-wasip2
fi

# Check for cargo-component
if ! command -v cargo-component &> /dev/null; then
    echo -e "${RED}Error: cargo-component not found${NC}"
    echo "Installing cargo-component..."
    cargo install cargo-component --version 0.18.0
fi

# Check for wasm-tools
if ! command -v wasm-tools &> /dev/null; then
    echo -e "${RED}Error: wasm-tools not found${NC}"
    echo "Installing wasm-tools..."
    cargo install wasm-tools --version 1.223.0
fi

# Check for wit-deps (needed by CLI component)
if ! command -v wit-deps &> /dev/null; then
    echo -e "${YELLOW}Warning: wit-deps not found${NC}"
    echo "Installing wit-deps..."
    cargo install wit-deps --version 0.4.0
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    cd "$PROJECT_ROOT"
    cargo clean
    cd "$SCRIPT_DIR/cli-component"
    cargo clean
    cd "$PROJECT_ROOT"
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Determine build profiles
case $BUILD_MODE in
    "dev")
        LIBRARY_PROFILE="wasi-dev"
        CLI_PROFILE="dev"
        OUTPUT_SUFFIX="-dev"
        ;;
    "debug")
        LIBRARY_PROFILE="wasi-debug"
        CLI_PROFILE="debug"
        OUTPUT_SUFFIX="-debug"
        ;;
    "release")
        LIBRARY_PROFILE="wasi-release"
        CLI_PROFILE="release"
        OUTPUT_SUFFIX=""
        ;;
esac

# Build library component
if [ "$SKIP_LIBRARY" = false ]; then
    echo -e "${BLUE}Building library component...${NC}"
    cd "$PROJECT_ROOT"

    if cargo component build --profile=$LIBRARY_PROFILE --no-default-features --features=wasi-component; then
        echo -e "${GREEN}✓ Library component built successfully${NC}"
        LIBRARY_PATH="$PROJECT_ROOT/target/wasm32-wasip2/$LIBRARY_PROFILE/scryer_prolog.wasm"
        if [ -f "$LIBRARY_PATH" ]; then
            echo "  Size: $(du -h "$LIBRARY_PATH" | cut -f1)"
        fi
    else
        echo -e "${RED}✗ Failed to build library component${NC}"
        exit 1
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping library component build${NC}"
    LIBRARY_PATH="$PROJECT_ROOT/target/wasm32-wasip2/$LIBRARY_PROFILE/scryer_prolog.wasm"
    if [ ! -f "$LIBRARY_PATH" ]; then
        echo -e "${RED}Error: Library component not found at $LIBRARY_PATH${NC}"
        echo "Build it first without --skip-library"
        exit 1
    fi
fi

# Build CLI component
if [ "$SKIP_CLI" = false ]; then
    echo -e "${BLUE}Building CLI component...${NC}"
    cd "$SCRIPT_DIR/cli-component"

    if [ "$CLI_PROFILE" = "release" ]; then
        cargo component build --release
    else
        cargo component build
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ CLI component built successfully${NC}"
        CLI_PATH="$SCRIPT_DIR/cli-component/target/wasm32-wasip2/$CLI_PROFILE/scryer_prolog_cli.wasm"
        if [ -f "$CLI_PATH" ]; then
            echo "  Size: $(du -h "$CLI_PATH" | cut -f1)"
        fi
    else
        echo -e "${RED}✗ Failed to build CLI component${NC}"
        exit 1
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping CLI component build${NC}"
    CLI_PATH="$SCRIPT_DIR/cli-component/target/wasm32-wasip2/$CLI_PROFILE/scryer_prolog_cli.wasm"
    if [ ! -f "$CLI_PATH" ]; then
        echo -e "${RED}Error: CLI component not found at $CLI_PATH${NC}"
        echo "Build it first without --skip-cli"
        exit 1
    fi
fi

# Compose components
if [ "$SKIP_COMPOSE" = false ]; then
    echo -e "${BLUE}Composing components...${NC}"

    OUTPUT_PATH="$PROJECT_ROOT/target/scryer-prolog-cli$OUTPUT_SUFFIX.wasm"

    # Check if both components exist
    if [ ! -f "$LIBRARY_PATH" ]; then
        echo -e "${RED}Error: Library component not found at $LIBRARY_PATH${NC}"
        exit 1
    fi

    if [ ! -f "$CLI_PATH" ]; then
        echo -e "${RED}Error: CLI component not found at $CLI_PATH${NC}"
        exit 1
    fi

    # Compose
    if wasm-tools compose \
        "$LIBRARY_PATH" \
        --plug "$CLI_PATH" \
        -o "$OUTPUT_PATH"; then

        echo -e "${GREEN}✓ Components composed successfully${NC}"
        echo "  Output: $OUTPUT_PATH"
        echo "  Size: $(du -h "$OUTPUT_PATH" | cut -f1)"

        # Validate the composed component
        echo ""
        echo -e "${YELLOW}Validating composed component...${NC}"
        if wasm-tools validate "$OUTPUT_PATH"; then
            echo -e "${GREEN}✓ Component validation passed${NC}"
        else
            echo -e "${RED}✗ Component validation failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Failed to compose components${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Skipping component composition${NC}"
    OUTPUT_PATH="$PROJECT_ROOT/target/scryer-prolog-cli$OUTPUT_SUFFIX.wasm"
fi

# Print summary and usage instructions
echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""

if [ -f "$OUTPUT_PATH" ]; then
    echo "CLI component available at:"
    echo "  $OUTPUT_PATH"
    echo ""
    echo "To run the CLI:"
    echo "  wasmtime run $OUTPUT_PATH"
    echo ""
    echo "Examples:"
    echo "  # Interactive REPL"
    echo "  wasmtime run $OUTPUT_PATH"
    echo ""
    echo "  # Execute a query"
    echo "  wasmtime run $OUTPUT_PATH -- -q \"member(X, [1,2,3]).\""
    echo ""
    echo "  # Load a file"
    echo "  wasmtime run --dir=. $OUTPUT_PATH -- -f program.pl"
else
    echo "Components built but not composed."
    echo "Run without --skip-compose to create the final CLI."
fi

echo ""
echo "For more examples, see:"
echo "  $SCRIPT_DIR/cli-component/examples/run-examples.sh"
