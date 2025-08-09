#!/bin/bash

# Test script for Scryer Prolog WASI component using Docker-based wasmtime
# This script runs wasmtime through Docker to test WASI components without local installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
COMPONENT_PATH=""
WASMTIME_VERSION="latest"
DOCKER_IMAGE="ghcr.io/bytecodealliance/wasmtime"
TEST_MODE="interactive"
VERBOSE=false

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] <component.wasm>"
    echo ""
    echo "Test Scryer Prolog WASI component using Docker-based wasmtime"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Wasmtime version (default: latest)"
    echo "  -t, --test-mode MODE     Test mode: interactive|batch|all (default: interactive)"
    echo "  -V, --verbose           Enable verbose output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 target/wasm32-wasi/debug/scryer_prolog_component.wasm"
    echo "  $0 -v 22.0.0 -t batch component.wasm"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            WASMTIME_VERSION="$2"
            shift 2
            ;;
        -t|--test-mode)
            TEST_MODE="$2"
            shift 2
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            COMPONENT_PATH="$1"
            shift
            ;;
    esac
done

# Check if component path is provided
if [ -z "$COMPONENT_PATH" ]; then
    echo -e "${RED}Error: Component path not provided${NC}"
    usage
fi

# Check if component file exists
if [ ! -f "$COMPONENT_PATH" ]; then
    echo -e "${RED}Error: Component file not found: $COMPONENT_PATH${NC}"
    exit 1
fi

# Get absolute path for Docker mounting
COMPONENT_ABS_PATH=$(realpath "$COMPONENT_PATH")
COMPONENT_DIR=$(dirname "$COMPONENT_ABS_PATH")
COMPONENT_NAME=$(basename "$COMPONENT_ABS_PATH")

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Function to run wasmtime in Docker
run_wasmtime() {
    local args="$1"
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Running: docker run --rm -i -v \"$COMPONENT_DIR:/wasm\" \"$DOCKER_IMAGE:$WASMTIME_VERSION\" $args${NC}"
    fi
    docker run --rm -i \
        -v "$COMPONENT_DIR:/wasm" \
        "$DOCKER_IMAGE:$WASMTIME_VERSION" \
        $args
}

# Function to test component info
test_component_info() {
    echo -e "${YELLOW}Testing component information...${NC}"
    if run_wasmtime "component wit /wasm/$COMPONENT_NAME"; then
        echo -e "${GREEN}✓ Component WIT interface retrieved successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get component information${NC}"
        return 1
    fi
}

# Function to run interactive tests
run_interactive_test() {
    echo -e "${YELLOW}Running interactive test...${NC}"
    echo -e "${BLUE}Starting wasmtime with component...${NC}"

    # Create a test script to invoke the component
    cat > /tmp/scryer_test_queries.txt << 'EOF'
% Test basic facts
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).

% Test queries
?- parent(tom, X).
?- parent(X, ann).

% Test arithmetic
?- X is 2 + 3.
?- X is 10 * 5.

% Test list operations
?- length([1,2,3,4], N).
?- append([1,2], [3,4], X).

% Exit
?- halt.
EOF

    echo -e "${BLUE}Sending test queries to component...${NC}"

    # Run the component with test input
    if docker run --rm -i \
        -v "$COMPONENT_DIR:/wasm" \
        -v "/tmp/scryer_test_queries.txt:/test_input.txt" \
        "$DOCKER_IMAGE:$WASMTIME_VERSION" \
        run /wasm/$COMPONENT_NAME < /tmp/scryer_test_queries.txt; then
        echo -e "${GREEN}✓ Interactive test completed${NC}"
    else
        echo -e "${RED}✗ Interactive test failed${NC}"
        return 1
    fi

    rm -f /tmp/scryer_test_queries.txt
}

# Function to run batch tests
run_batch_test() {
    echo -e "${YELLOW}Running batch tests...${NC}"

    # Test 1: Invoke core.machine constructor
    echo -e "${BLUE}Test 1: Creating machine instance...${NC}"
    if run_wasmtime "run --invoke core.machine.constructor /wasm/$COMPONENT_NAME -- '{}'"; then
        echo -e "${GREEN}✓ Machine constructor test passed${NC}"
    else
        echo -e "${RED}✗ Machine constructor test failed${NC}"
    fi

    # Test 2: Basic function invocation (if available)
    echo -e "${BLUE}Test 2: Testing basic function invocation...${NC}"
    # This would test specific exported functions once we know their signatures

    echo -e "${GREEN}Batch tests completed${NC}"
}

# Function to test with example Prolog file
test_with_prolog_file() {
    local prolog_file="$1"
    echo -e "${YELLOW}Testing with Prolog file: $prolog_file${NC}"

    if [ ! -f "$prolog_file" ]; then
        echo -e "${RED}Error: Prolog file not found: $prolog_file${NC}"
        return 1
    fi

    # Copy file content and create consult command
    local prolog_content=$(cat "$prolog_file")

    # Run component and consult the module
    echo -e "${BLUE}Consulting Prolog module...${NC}"

    # This is a placeholder - actual implementation depends on component interface
    echo -e "${YELLOW}Note: File-based testing requires proper component interface implementation${NC}"
}

# Main test execution
echo -e "${GREEN}=== Scryer Prolog WASI Component Test ===${NC}"
echo -e "${BLUE}Component: $COMPONENT_PATH${NC}"
echo -e "${BLUE}Wasmtime version: $WASMTIME_VERSION${NC}"
echo ""

# Pull wasmtime Docker image if needed
echo -e "${YELLOW}Pulling wasmtime Docker image...${NC}"
if docker pull "$DOCKER_IMAGE:$WASMTIME_VERSION" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker image ready${NC}"
else
    echo -e "${RED}✗ Failed to pull Docker image${NC}"
    exit 1
fi

# Run tests based on mode
case $TEST_MODE in
    interactive)
        test_component_info
        run_interactive_test
        ;;
    batch)
        test_component_info
        run_batch_test
        ;;
    all)
        test_component_info
        run_interactive_test
        run_batch_test
        ;;
    *)
        echo -e "${RED}Error: Unknown test mode: $TEST_MODE${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== Test Summary ===${NC}"
echo -e "${BLUE}All tests completed.${NC}"

# Check if there's an example Prolog file to test
EXAMPLE_DIR="$(dirname "$COMPONENT_DIR")/examples/wasi-component"
if [ -d "$EXAMPLE_DIR" ] && [ -f "$EXAMPLE_DIR/test_program.pl" ]; then
    echo ""
    echo -e "${YELLOW}Found example Prolog file. Run with:${NC}"
    echo -e "${BLUE}$0 $COMPONENT_PATH${NC}"
fi
