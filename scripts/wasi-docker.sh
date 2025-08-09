#!/bin/bash
# Convenience script for WASI component Docker operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="docker-compose.wasi.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
BUILD_PROFILE="${BUILD_PROFILE:-release}"
WASMTIME_VERSION="${WASMTIME_VERSION:-latest}"

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    cat << EOF
${CYAN}Scryer Prolog WASI Component Docker Helper${NC}

Usage: $0 <command> [options]

Commands:
    build [profile]     Build the WASI component (debug/dev/release)
    test                Run component tests with wasmtime
    run                 Run interactive WASI component
    shell               Start debug shell with wasmtime
    info                Show component WIT interface
    verify              Verify component was built
    clean               Clean build artifacts
    logs [service]      Show service logs
    all                 Build and test everything

Options:
    --profile PROFILE   Set build profile (debug/dev/release)
    --wasmtime VERSION  Set wasmtime version (default: latest)
    --help, -h          Show this help message

Environment Variables:
    BUILD_PROFILE       Build profile (default: release)
    WASMTIME_VERSION    Wasmtime version (default: latest)

Examples:
    $0 build                    # Build release version
    $0 build dev                # Build dev version
    $0 test                     # Run tests
    $0 run                      # Run interactive session
    $0 --profile=debug build    # Build debug version

EOF
}

# Change to project directory
cd "$PROJECT_DIR"

# Parse global options
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            BUILD_PROFILE="$2"
            shift 2
            ;;
        --profile=*)
            BUILD_PROFILE="${1#*=}"
            shift
            ;;
        --wasmtime)
            WASMTIME_VERSION="$2"
            shift 2
            ;;
        --wasmtime=*)
            WASMTIME_VERSION="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Export environment variables
export BUILD_PROFILE
export WASMTIME_VERSION

# Main command handling
case "${1:-help}" in
    build)
        # Handle optional profile argument
        if [ $# -ge 2 ]; then
            BUILD_PROFILE="$2"
            export BUILD_PROFILE
        fi

        info "Building WASI component with profile: $BUILD_PROFILE"
        info "This may take several minutes on first run..."

        if docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi-component; then
            success "Build complete!"
            info "Component location: target/wasi-component/scryer_prolog_component.wasm"
        else
            error "Build failed!"
            exit 1
        fi
        ;;

    test)
        info "Running WASI component tests..."

        # First ensure component is built
        if [ ! -f "target/wasi-component/scryer_prolog_component.wasm" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi-component
        fi

        docker-compose -f "$COMPOSE_FILE" run -T --rm test-component
        success "Tests complete!"
        ;;

    run)
        info "Starting interactive WASI component session..."
        info "Use Ctrl+D or :- halt. to exit"

        # Ensure component exists
        if [ ! -f "target/wasi-component/scryer_prolog_component.wasm" ]; then
            warning "Component not found, building first..."
            docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi-component
        fi

        docker-compose -f "$COMPOSE_FILE" run -T --rm wasmtime
        ;;

    shell)
        info "Starting debug shell with wasmtime..."
        info "Component at: /wasm/scryer_prolog_component.wasm"
        info "Examples at: /examples/"

        docker-compose -f "$COMPOSE_FILE" run -T --rm debug-shell
        ;;

    info)
        info "Showing component WIT interface..."

        if [ ! -f "target/wasi-component/scryer_prolog_component.wasm" ]; then
            error "Component not found! Run '$0 build' first."
            exit 1
        fi

        docker-compose -f "$COMPOSE_FILE" run -T --rm --entrypoint wasmtime test-component \
            component wit /wasm/scryer_prolog_component.wasm
        ;;

    verify)
        info "Verifying WASI component..."
        docker-compose -f "$COMPOSE_FILE" run -T --rm verify-component
        ;;

    clean)
        info "Cleaning WASI component artifacts..."
        rm -rf target/wasi-component
        rm -rf target/wasm32-wasip1
        success "Clean complete!"
        ;;

    logs)
        SERVICE="${2:-}"
        if [ -z "$SERVICE" ]; then
            docker-compose -f "$COMPOSE_FILE" logs -f
        else
            docker-compose -f "$COMPOSE_FILE" logs -f "$SERVICE"
        fi
        ;;

    all)
        info "Building and testing everything..."

        # Build
        info "Step 1/3: Building component..."
        docker-compose -f "$COMPOSE_FILE" run -T --rm build-wasi-component

        # Verify
        info "Step 2/3: Verifying build..."
        docker-compose -f "$COMPOSE_FILE" run -T --rm verify-component

        # Test
        info "Step 3/3: Running tests..."
        docker-compose -f "$COMPOSE_FILE" run -T --rm test-component

        success "All operations completed successfully!"
        ;;

    ps)
        docker-compose -f "$COMPOSE_FILE" ps
        ;;

    down)
        info "Stopping all services..."
        docker-compose -f "$COMPOSE_FILE" down
        success "Services stopped!"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
