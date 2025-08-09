#!/bin/bash
# Simple WASI component build script for Scryer Prolog

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.wasi-simple.yml"
TEST_COMPOSE_FILE="docker-compose.wasi-test.yml"
COMPONENT_PATH="target/wasi-component/scryer_prolog_component.wasm"

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    error "Docker or docker-compose not found!"
    exit 1
fi

# Main command
CMD="${1:-help}"

case "$CMD" in
    build)
        info "Building WASI component (release)..."
        info "This may take several minutes on first run..."

        if docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi; then
            success "Build complete!"
            if [ -f "$COMPONENT_PATH" ]; then
                info "Component available at: $COMPONENT_PATH"
                info "Component size: $(ls -lh "$COMPONENT_PATH" | awk '{print $5}')"
                info "This is a LIBRARY component with WIT interface - see examples/wasi-component-usage.md"
            else
                error "Build succeeded but component not found at $COMPONENT_PATH"
                error "This may indicate a volume mounting issue"
                exit 1
            fi
        else
            error "Build failed!"
            exit 1
        fi
        ;;

    build-dev)
        info "Building WASI component (dev)..."

        if docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi-dev; then
            success "Build complete!"
            if [ -f "$COMPONENT_PATH" ]; then
                info "Component available at: $COMPONENT_PATH"
                info "Component size: $(ls -lh "$COMPONENT_PATH" | awk '{print $5}')"
            else
                error "Build succeeded but component not found at $COMPONENT_PATH"
                exit 1
            fi
        else
            error "Build failed!"
            exit 1
        fi
        ;;

    test)
        info "Testing WASI component..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi
        fi

        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm test-suite
        ;;

    smoke-test)
        info "Running smoke test..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            error "Component not found! Run '$0 build' first."
            exit 1
        fi

        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm smoke-test
        ;;

    test-all)
        info "Running all tests..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi
        fi

        info "1. Verification..."
        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm verify

        info "2. Smoke test..."
        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm smoke-test

        info "3. Test suite..."
        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm test-suite

        success "All tests completed!"
        ;;

    benchmark)
        info "Running performance benchmark..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            error "Component not found! Run '$0 build' first."
            exit 1
        fi

        docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm benchmark
        ;;

    run)
        info "Starting interactive WASI session..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi
        fi

        info "Use Ctrl+D or ':- halt.' to exit"
        docker-compose -f "$TEST_COMPOSE_FILE" run --rm repl
        ;;

    run-file)
        FILE="${2:-}"
        if [ -z "$FILE" ]; then
            error "Please specify a Prolog file to run"
            echo "Usage: $0 run-file <file.pl>"
            exit 1
        fi

        info "Running $FILE..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi
        fi

        PROLOG_FILE="$FILE" docker-compose -f "$TEST_COMPOSE_FILE" run -T --rm run-file
        ;;

    shell)
        info "Starting test shell..."

        if [ ! -f "$COMPONENT_PATH" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi
        fi

        docker-compose -f "$TEST_COMPOSE_FILE" run --rm shell
        ;;

    clean)
        info "Cleaning WASI artifacts..."
        if [ -d "target/wasi-component" ]; then
            rm -rf target/wasi-component
            info "Removed target/wasi-component"
        fi
        if [ -d "target/wasm32-wasip1" ]; then
            rm -rf target/wasm32-wasip1
            info "Removed target/wasm32-wasip1"
        fi
        success "Clean complete!"
        ;;

    info)
        if [ ! -f "$COMPONENT_PATH" ]; then
            error "Component not found! Run '$0 build' first."
            exit 1
        fi

        info "Component info:"
        echo "Path: $COMPONENT_PATH"
        echo "Size: $(ls -lh "$COMPONENT_PATH" | awk '{print $5}')"
        echo "Modified: $(ls -lh "$COMPONENT_PATH" | awk '{print $6, $7, $8}')"
        ;;

    help|--help|-h)
        cat << EOF
Scryer Prolog WASI Build Script

This builds a LIBRARY COMPONENT that exports a WIT interface, not a standalone CLI application.
The component must be embedded in a host application to be used.

Usage: $0 <command> [args]

Build Commands:
    build         Build WASI component (release mode) - creates library component
    build-dev     Build WASI component (dev mode) - creates library component
    clean         Clean build artifacts

Test Commands (Note: These require a CLI wrapper, not available for library components):
    test          Run comprehensive test suite [NOT AVAILABLE - library component]
    smoke-test    Run quick smoke test [NOT AVAILABLE - library component]
    test-all      Run verification, smoke test, and full suite [NOT AVAILABLE]
    benchmark     Run performance benchmark [NOT AVAILABLE - library component]

Run Commands (Note: These require a CLI wrapper, not available for library components):
    run           Start interactive WASI REPL [NOT AVAILABLE - library component]
    run-file FILE Run a specific Prolog file [NOT AVAILABLE - library component]
    shell         Start test shell for manual testing

Info Commands:
    info          Show component information
    help          Show this help message

Examples:
    $0 build                # Build library component (5.2MB)
    $0 info                 # Show component details

To use the component, you need to:
1. Embed it in a host application (Rust, JavaScript, Python, etc.)
2. Use the WIT interface to create machines and run queries
3. See examples/wasi-component-usage.md for details

EOF
        ;;

    *)
        error "Unknown command: $CMD"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
