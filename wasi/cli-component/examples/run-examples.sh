#!/bin/bash

# Example usage script for Scryer Prolog CLI Component
# This script demonstrates various ways to use the CLI component

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if the CLI component exists
CLI_WASM="../../../target/scryer-prolog-cli.wasm"
if [ ! -f "$CLI_WASM" ]; then
    echo "Error: CLI component not found at $CLI_WASM"
    echo "Please build it first with: cd ../.. && ./build.sh --compose"
    exit 1
fi

# Check if wasmtime is installed
if ! command -v wasmtime &> /dev/null; then
    echo "Error: wasmtime is not installed."
    echo "Install it from: https://wasmtime.dev/"
    exit 1
fi

echo -e "${GREEN}Scryer Prolog CLI Component Examples${NC}"
echo "======================================"
echo

# Example 1: Show version
echo -e "${BLUE}Example 1: Show version information${NC}"
echo "Command: wasmtime run $CLI_WASM -- -v"
wasmtime run "$CLI_WASM" -- -v
echo

# Example 2: Show help
echo -e "${BLUE}Example 2: Show help message${NC}"
echo "Command: wasmtime run $CLI_WASM -- -h"
wasmtime run "$CLI_WASM" -- -h
echo

# Example 3: Simple query
echo -e "${BLUE}Example 3: Execute a simple query${NC}"
echo "Command: wasmtime run $CLI_WASM -- -q \"member(X, [a,b,c]).\""
wasmtime run "$CLI_WASM" -- -q "member(X, [a,b,c])."
echo

# Example 4: Arithmetic query
echo -e "${BLUE}Example 4: Arithmetic operations${NC}"
echo "Command: wasmtime run $CLI_WASM -- -q \"X is 2 + 3 * 4.\""
wasmtime run "$CLI_WASM" -- -q "X is 2 + 3 * 4."
echo

# Example 5: List operations
echo -e "${BLUE}Example 5: List operations${NC}"
echo "Command: wasmtime run $CLI_WASM -- -q \"append([1,2], [3,4], X).\""
wasmtime run "$CLI_WASM" -- -q "append([1,2], [3,4], X)."
echo

# Example 6: Multiple solutions
echo -e "${BLUE}Example 6: Query with multiple solutions${NC}"
echo "Command: wasmtime run $CLI_WASM -- -q \"between(1, 5, X).\""
wasmtime run "$CLI_WASM" -- -q "between(1, 5, X)."
echo

# Example 7: Goal execution
echo -e "${BLUE}Example 7: Execute a goal at startup${NC}"
echo "Command: wasmtime run $CLI_WASM -- -g \"write('Hello from Prolog!'), nl.\""
wasmtime run "$CLI_WASM" -- -g "write('Hello from Prolog!'), nl."
echo

# Example 8: Load file and query
echo -e "${BLUE}Example 8: Load a file and run a query${NC}"
echo "Creating a temporary Prolog file..."
cat > temp_facts.pl << 'EOF'
% Temperature facts
temperature(monday, 20).
temperature(tuesday, 22).
temperature(wednesday, 19).
temperature(thursday, 23).
temperature(friday, 21).

% Hot day definition
hot_day(Day) :- temperature(Day, Temp), Temp > 21.

% Average temperature
average_temp(Avg) :-
    findall(T, temperature(_, T), Temps),
    sum_list(Temps, Sum),
    length(Temps, Count),
    Avg is Sum / Count.
EOF

echo "Command: wasmtime run --dir=. $CLI_WASM -- -f temp_facts.pl -q \"hot_day(Day).\""
wasmtime run --dir=. "$CLI_WASM" -- -f temp_facts.pl -q "hot_day(Day)."
echo

# Example 9: Complex query from file
echo -e "${BLUE}Example 9: Complex query using loaded facts${NC}"
echo "Command: wasmtime run --dir=. $CLI_WASM -- -f temp_facts.pl -q \"average_temp(Avg).\""
wasmtime run --dir=. "$CLI_WASM" -- -f temp_facts.pl -q "average_temp(Avg)."
echo

# Clean up
rm -f temp_facts.pl

# Example 10: Family relationships
echo -e "${BLUE}Example 10: Family relationships example${NC}"
echo "Command: wasmtime run --dir=. $CLI_WASM -- -f family.pl -q \"ancestor(tom, X).\""
wasmtime run --dir=. "$CLI_WASM" -- -f family.pl -q "ancestor(tom, X)."
echo

# Example 11: Interactive REPL
echo -e "${BLUE}Example 11: Interactive REPL${NC}"
echo -e "${YELLOW}To start the interactive REPL, run:${NC}"
echo "wasmtime run $CLI_WASM"
echo
echo "In the REPL, you can:"
echo "  - Type queries ending with a period (.)"
echo "  - Press ; to see more solutions"
echo "  - Use :help for REPL commands"
echo "  - Use :quit or halt. to exit"
echo

# Example 12: Piping queries
echo -e "${BLUE}Example 12: Piping queries${NC}"
echo "Command: echo \"length([1,2,3,4,5], L).\" | wasmtime run $CLI_WASM"
echo "length([1,2,3,4,5], L)." | wasmtime run "$CLI_WASM"
echo

# Example 13: Error handling
echo -e "${BLUE}Example 13: Error handling${NC}"
echo "Command: wasmtime run $CLI_WASM -- -q \"undefined_predicate(X).\""
wasmtime run "$CLI_WASM" -- -q "undefined_predicate(X)." || true
echo

echo -e "${GREEN}Examples completed!${NC}"
echo
echo "Tips:"
echo "- Use --dir=. with wasmtime to allow file system access"
echo "- Queries must end with a period (.)"
echo "- In batch mode, all solutions are shown automatically"
echo "- In interactive mode, use ; to navigate solutions"
