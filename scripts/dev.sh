#!/bin/bash
set -euo pipefail

# Development helper script for Scryer Prolog with WASI support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Change to project directory
cd "$PROJECT_DIR"

# Main script logic
case "${1:-help}" in
    build)
        info "Building Scryer Prolog with WASI support..."
        docker-compose build build
        success "Build complete!"
        ;;

    dev)
        info "Starting development container..."
        docker-compose run --rm scryer-dev
        ;;

    shell)
        info "Starting interactive shell in development container..."
        docker-compose run --rm scryer-dev bash
        ;;

    native)
        info "Running native Scryer Prolog..."
        docker-compose run --rm scryer-native
        ;;

    wasi)
        info "Running WASI component..."
        docker-compose run --rm scryer-wasi
        ;;

    test)
        info "Running tests..."
        docker-compose run -T --rm test
        success "Tests complete!"
        ;;

    test-wasi)
        info "Testing WASI component..."
        docker-compose run -T --rm test-wasi
        success "WASI tests complete!"
        ;;

    build-native)
        info "Building native Scryer Prolog only..."
        docker-compose run -T --rm scryer-dev cargo build --release
        success "Native build complete!"
        ;;

    build-wasi)
        info "Building WASI component..."
        docker-compose run -T --rm scryer-dev bash -c "
            cargo build --target wasm32-wasip1 --profile wasi-release --no-default-features --features wasi-component &&
            wasm-tools component new \
                target/wasm32-wasip1/wasi-release/scryer_prolog.wasm \
                -o target/wasm32-wasip1/wasi-release/scryer_prolog.component.wasm
        "
        success "WASI component build complete!"
        ;;

    clean)
        info "Cleaning build artifacts..."
        docker-compose run -T --rm scryer-dev cargo clean
        success "Clean complete!"
        ;;

    fmt)
        info "Running cargo fmt..."
        docker-compose run -T --rm scryer-dev cargo fmt
        success "Formatting complete!"
        ;;

    clippy)
        info "Running cargo clippy..."
        docker-compose run -T --rm scryer-dev cargo clippy --all-targets --all-features
        success "Clippy complete!"
        ;;

    logs)
        docker-compose logs -f "${2:-}"
        ;;

    down)
        info "Stopping all containers..."
        docker-compose down
        success "All containers stopped!"
        ;;

    prune)
        warning "This will remove all Docker volumes for this project!"
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            success "Volumes removed!"
        else
            info "Cancelled"
        fi
        ;;

    exec)
        shift
        info "Executing command in development container..."
        docker-compose run -T --rm scryer-dev "$@"
        ;;

    wasmtime)
        shift
        info "Running wasmtime with component..."
        docker-compose run --rm scryer-wasi wasmtime run --dir=/home/scryer /opt/scryer/scryer_prolog.component.wasm "$@"
        ;;

    wit-deps)
        info "Checking WIT dependencies..."
        docker-compose run -T --rm scryer-dev bash -c "
            cd /app &&
            wasm-tools component wit wit/
        "
        ;;

    help|--help|-h)
        cat << EOF
Scryer Prolog Development Helper

Usage: $0 <command> [args...]

Commands:
    build           Build everything (native + WASI)
    dev             Start development container with mounted source
    shell           Start bash shell in development container
    native          Run native Scryer Prolog
    wasi            Run WASI component
    test            Run all tests
    test-wasi       Test WASI component
    build-native    Build native version only
    build-wasi      Build WASI component only
    clean           Clean build artifacts
    fmt             Run cargo fmt
    clippy          Run cargo clippy
    logs [service]  Show logs (optionally for specific service)
    down            Stop all containers
    prune           Remove all volumes (WARNING: destructive)
    exec <cmd>      Execute command in dev container
    wasmtime <args> Run wasmtime with additional arguments
    wit-deps        Check WIT dependencies
    help            Show this help message

Examples:
    $0 build                    # Build everything
    $0 dev                      # Start development environment
    $0 test                     # Run tests
    $0 exec cargo check         # Run cargo check in dev container
    $0 wasi                     # Run WASI component interactively
    $0 wasmtime --help          # Get wasmtime help

Environment Variables:
    RUST_LOG        Set Rust log level (default: info)
    RUST_BACKTRACE  Enable backtrace (1 or full)

EOF
        ;;

    *)
        error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
