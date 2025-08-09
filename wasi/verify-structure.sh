#!/bin/bash

# Verification script for Scryer Prolog WASI component structure
# This script checks that the reorganized structure is correct and ready for building

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

echo -e "${BLUE}=== Scryer Prolog WASI Structure Verification ===${NC}"
echo ""

# Track if any issues are found
ISSUES_FOUND=false

# Function to check if a file exists
check_file() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description exists"
        return 0
    else
        echo -e "${RED}✗${NC} $description missing: $file"
        ISSUES_FOUND=true
        return 1
    fi
}

# Function to check if a directory exists
check_dir() {
    local dir="$1"
    local description="$2"

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description exists"
        return 0
    else
        echo -e "${RED}✗${NC} $description missing: $dir"
        ISSUES_FOUND=true
        return 1
    fi
}

# Function to check file content
check_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if [ -f "$file" ] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ISSUES_FOUND=true
        return 1
    fi
}

echo -e "${YELLOW}1. Checking directory structure...${NC}"
check_dir "$SCRIPT_DIR" "wasi directory"
check_dir "$SCRIPT_DIR/wit" "wasi/wit directory"
check_dir "$SCRIPT_DIR/cli-component" "wasi/cli-component directory"
check_dir "$SCRIPT_DIR/cli-component/src" "CLI component source directory"
check_dir "$SCRIPT_DIR/cli-component/wit" "CLI component WIT directory"
check_dir "$SCRIPT_DIR/cli-component/examples" "CLI component examples directory"
echo ""

echo -e "${YELLOW}2. Checking WIT files...${NC}"
check_file "$SCRIPT_DIR/wit/scryer-prolog.wit" "Library component WIT interface"
check_file "$SCRIPT_DIR/cli-component/wit/cli.wit" "CLI component WIT interface"
check_file "$SCRIPT_DIR/cli-component/wit/deps.toml" "WIT dependencies manifest"

# Check WIT file syntax (basic check)
if [ -f "$SCRIPT_DIR/wit/scryer-prolog.wit" ]; then
    if grep -q "package scryer:prolog" "$SCRIPT_DIR/wit/scryer-prolog.wit"; then
        echo -e "${GREEN}✓${NC} Library WIT has correct package declaration"
    else
        echo -e "${RED}✗${NC} Library WIT missing package declaration"
        ISSUES_FOUND=true
    fi
fi

if [ -f "$SCRIPT_DIR/cli-component/wit/cli.wit" ]; then
    if grep -q "package scryer:prolog-cli" "$SCRIPT_DIR/cli-component/wit/cli.wit"; then
        echo -e "${GREEN}✓${NC} CLI WIT has correct package declaration"
    else
        echo -e "${RED}✗${NC} CLI WIT missing package declaration"
        ISSUES_FOUND=true
    fi
fi
echo ""

echo -e "${YELLOW}3. Checking build files...${NC}"
check_file "$SCRIPT_DIR/build.sh" "Unified build script"
check_file "$SCRIPT_DIR/cli-component/build.sh" "CLI component build script"
check_file "$SCRIPT_DIR/cli-component/build.rs" "wit-deps build script"
check_file "$SCRIPT_DIR/cli-component/Cargo.toml" "CLI component manifest"

# Check if build scripts are executable
if [ -x "$SCRIPT_DIR/build.sh" ]; then
    echo -e "${GREEN}✓${NC} Unified build script is executable"
else
    echo -e "${YELLOW}!${NC} Unified build script is not executable (run: chmod +x $SCRIPT_DIR/build.sh)"
fi

if [ -x "$SCRIPT_DIR/cli-component/build.sh" ]; then
    echo -e "${GREEN}✓${NC} CLI build script is executable"
else
    echo -e "${YELLOW}!${NC} CLI build script is not executable (run: chmod +x $SCRIPT_DIR/cli-component/build.sh)"
fi
echo ""

echo -e "${YELLOW}4. Checking configuration files...${NC}"

# Check wit-deps configuration
if [ -f "$SCRIPT_DIR/cli-component/wit/deps.toml" ]; then
    if grep -q 'scryer-prolog = { path = "../../wit" }' "$SCRIPT_DIR/cli-component/wit/deps.toml"; then
        echo -e "${GREEN}✓${NC} wit-deps configuration points to correct path"
    else
        echo -e "${RED}✗${NC} wit-deps configuration has incorrect path"
        ISSUES_FOUND=true
    fi
fi

# Check Cargo.toml for wit-deps
check_content "$SCRIPT_DIR/cli-component/Cargo.toml" "wit-deps" "Cargo.toml includes wit-deps dependency"
check_content "$SCRIPT_DIR/cli-component/Cargo.toml" "wit-bindgen" "Cargo.toml includes wit-bindgen dependency"

# Check build.rs
check_content "$SCRIPT_DIR/cli-component/build.rs" "wit_deps::lock!" "build.rs uses wit-deps"
echo ""

echo -e "${YELLOW}5. Checking documentation...${NC}"
check_file "$SCRIPT_DIR/README.md" "WASI directory README"
check_file "$SCRIPT_DIR/cli-component/README.md" "CLI component README"

# Check if old structure exists (should not)
echo ""
echo -e "${YELLOW}6. Checking for old structure (should not exist)...${NC}"
if [ -d "$PROJECT_ROOT/wit" ] && [ "$PROJECT_ROOT/wit" != "$SCRIPT_DIR/wit" ]; then
    echo -e "${RED}✗${NC} Old wit/ directory still exists at repository root"
    ISSUES_FOUND=true
else
    echo -e "${GREEN}✓${NC} No old wit/ directory at repository root"
fi

if [ -d "$PROJECT_ROOT/cli-component" ] && [ "$PROJECT_ROOT/cli-component" != "$SCRIPT_DIR/cli-component" ]; then
    echo -e "${RED}✗${NC} Old cli-component/ directory still exists at repository root"
    ISSUES_FOUND=true
else
    echo -e "${GREEN}✓${NC} No old cli-component/ directory at repository root"
fi
echo ""

echo -e "${YELLOW}7. Checking example files...${NC}"
check_file "$SCRIPT_DIR/cli-component/examples/family.pl" "Example Prolog program"
check_file "$SCRIPT_DIR/cli-component/examples/run-examples.sh" "Example runner script"
echo ""

# Summary
echo -e "${BLUE}=== Verification Summary ===${NC}"
if [ "$ISSUES_FOUND" = true ]; then
    echo -e "${RED}Issues found!${NC} Please fix the issues above before building."
    echo ""
    echo "Common fixes:"
    echo "1. Make sure you're in the correct directory"
    echo "2. Check that all files were properly moved/created"
    echo "3. Ensure build scripts are executable: chmod +x *.sh"
    exit 1
else
    echo -e "${GREEN}All checks passed!${NC} The WASI structure is ready for building."
    echo ""
    echo "Next steps:"
    echo "1. Install build tools:"
    echo "   - rustup target add wasm32-wasip2"
    echo "   - cargo install cargo-component wasm-tools wit-deps"
    echo ""
    echo "2. Build everything:"
    echo "   cd $SCRIPT_DIR && ./build.sh"
    echo ""
    echo "3. Or use Docker:"
    echo "   docker compose -f docker-compose.cli.yml run build-and-test-all"
fi

exit 0
