#!/bin/bash
# Test script for Docker WASI build

set -e

echo "=== Docker WASI Build Test Script ==="
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Function to run a docker compose command and check result
run_test() {
    local test_name="$1"
    local compose_cmd="$2"

    echo -e "${YELLOW}Running:${NC} $test_name"
    if docker compose run --rm --no-TTY $compose_cmd >/dev/null 2>&1; then
        print_status 0 "$test_name succeeded"
    else
        print_status 1 "$test_name failed"
        return 1
    fi
}

# Check if docker compose is available
echo "1. Checking Docker setup..."
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker Compose v2 is not installed${NC}"
    exit 1
fi
print_status 0 "Docker and Docker Compose are available"
echo

# Clean previous builds
echo "2. Cleaning previous builds..."
docker compose run --rm --no-TTY clean >/dev/null 2>&1 || true
print_status 0 "Clean complete"
echo

# Test WIT validation
echo "3. Testing WIT validation..."
if run_test "WIT validation" "validate-wit"; then
    echo
else
    echo -e "${YELLOW}Warning: WIT validation failed, but continuing...${NC}"
    echo
fi

# Test main build
echo "4. Testing main build (this may take several minutes)..."
if docker compose run --rm --no-TTY build 2>&1 | grep -q "Build completed successfully"; then
    print_status 0 "Main build completed successfully"
else
    print_status 1 "Main build failed"
    echo -e "${RED}Build failed. Run 'docker compose run --rm build' to see detailed output${NC}"
    exit 1
fi
echo

# Check if components were built
echo "5. Checking build outputs..."
if docker compose run --rm --no-TTY --entrypoint sh build -c "test -f target/scryer-prolog-cli.wasm" 2>/dev/null; then
    print_status 0 "CLI component found"
else
    print_status 1 "CLI component not found"
fi

if docker compose run --rm --no-TTY --entrypoint sh build -c "test -f target/wasm32-wasip2/wasi-release/scryer_prolog.wasm" 2>/dev/null; then
    print_status 0 "Library component found"
else
    print_status 1 "Library component not found"
fi
echo

# Test the CLI component
echo "6. Testing CLI component..."
if docker compose run --rm --no-TTY test 2>&1 | grep -q "All tests passed"; then
    print_status 0 "CLI tests passed"
else
    print_status 1 "CLI tests failed"
    echo -e "${YELLOW}Run 'docker compose run --rm test' to see test details${NC}"
fi
echo

# Summary
echo "=== Test Summary ==="
echo
echo "Build artifacts location:"
echo "  - CLI component: target/scryer-prolog-cli.wasm"
echo "  - Library component: target/wasm32-wasip2/wasi-release/scryer_prolog.wasm"
echo
echo "To run the WASI REPL:"
echo "  docker compose run --rm repl"
echo
echo "To enter development shell:"
echo "  docker compose run --rm dev"
echo
echo -e "${GREEN}Docker build test completed!${NC}"
