# Scryer Prolog CLI Component

A WebAssembly Component Model CLI interface for Scryer Prolog, providing an interactive REPL and batch query execution for the Scryer Prolog WASI library component.

## Overview

This CLI component is designed to work with the Scryer Prolog library component using the WebAssembly Component Model. It provides:

- Interactive REPL (Read-Eval-Print Loop) interface
- Batch query execution
- File loading capabilities
- Multi-line query support
- Proper solution formatting

## Architecture

The CLI component imports the Scryer Prolog core library component and exports a standard WASI CLI interface:

```
┌─────────────────────────┐
│   CLI Component         │  (scryer:prolog-cli)
│  - REPL interface       │
│  - Batch mode           │
│  - File loading         │
└───────────┬─────────────┘
            │ imports
┌───────────▼─────────────┐
│  Library Component      │  (scryer:prolog/core)
│  - Machine resource     │
│  - Query execution      │
│  - Term representation  │
└─────────────────────────┘
```

## Building

### Prerequisites

1. Rust toolchain with `wasm32-wasip2` target:
   ```bash
   rustup target add wasm32-wasip2
   ```

2. Install cargo-component:
   ```bash
   cargo install cargo-component
   ```

3. Install wasm-tools:
   ```bash
   cargo install wasm-tools
   ```

### Build Instructions

1. **Build just the CLI component:**
   ```bash
   cd wasi/cli-component
   cargo component build --release
   ```

2. **Build and compose with library component:**
   ```bash
   ./build.sh --compose
   ```

3. **Development build:**
   ```bash
   ./build.sh --dev --compose
   ```

The composed component will be output to `../../target/scryer-prolog-cli.wasm`.

## Usage

### Running with Wasmtime

```bash
# Interactive REPL
wasmtime run scryer-prolog-cli.wasm

# Execute a single query
wasmtime run scryer-prolog-cli.wasm -- -q "member(X, [1,2,3])."

# Load a file and start REPL
wasmtime run --dir=. scryer-prolog-cli.wasm -- -f examples/family.pl

# Load file and execute query
wasmtime run --dir=. scryer-prolog-cli.wasm -- -f examples/family.pl -q "parent(tom, X)."

# Execute goal at startup
wasmtime run scryer-prolog-cli.wasm -- -g "write('Hello, World!'), nl."
```

### Command Line Options

- `-f, --file <FILE>...` - Load Prolog file(s) before starting
- `-g, --goal <GOAL>` - Execute goal at startup
- `-q, --query <QUERY>` - Execute query and exit (batch mode)
- `-h, --help` - Display help message
- `-v, --version` - Display version information

### REPL Commands

- `:help`, `:h` - Show help message
- `:quit`, `:exit`, `:q` - Exit the REPL
- `:clear` - Clear the screen
- `halt.` - Exit via Prolog query

### Interactive Mode Features

1. **Multi-line queries**: Queries can span multiple lines. The REPL will show a continuation prompt (`   `) until a terminating period is entered.

2. **Solution navigation**: After displaying a solution with variable bindings:
   - Press `;` or `SPACE` to see the next solution
   - Press `ENTER` or any other key to stop

3. **Query format**: All queries must end with a period (`.`)

## Examples

### Basic Queries

```prolog
?- append([1,2], [3,4], X).
X = [1, 2, 3, 4] .

?- member(X, [a,b,c]).
X = a ;
X = b ;
X = c .

?- between(1, 5, X).
X = 1 ;
X = 2 ;
X = 3 ;
X = 4 ;
X = 5 .
```

### Working with Files

Create a file `facts.pl`:

```prolog
likes(mary, food).
likes(mary, wine).
likes(john, wine).
likes(john, mary).

happy(X) :- likes(X, wine), likes(X, food).
```

Load and query:

```bash
wasmtime run --dir=. scryer-prolog-cli.wasm -- -f facts.pl -q "happy(X)."
```

### Multi-line Input

```prolog
?- findall(X, 
   (member(X, [1,2,3,4,5]),
    X > 2),
   L).
L = [3, 4, 5] .
```

## Web Usage

The CLI component can be used in web environments after transpilation:

```bash
# Transpile to JavaScript
jco transpile scryer-prolog-cli.wasm -o cli-js/

# Use in Node.js or browser with appropriate WASI polyfills
```

Project Structure

```
wasi/cli-component/
├── Cargo.toml          # Component manifest
├── build.sh            # Build script
├── src/
│   ├── lib.rs          # Main component implementation
│   ├── args.rs         # Argument parsing
│   ├── formatter.rs    # Solution formatting
│   └── repl.rs         # REPL functionality
├── examples/
│   └── family.pl       # Example Prolog program
└── README.md           # This file
```

## Features

- **Full Prolog syntax support**: All Scryer Prolog features available
- **Resource management**: Automatic cleanup of query states and bindings
- **Error handling**: Graceful error reporting for syntax and runtime errors
- **Unicode support**: Full UTF-8 support in queries and output
- **Streaming solutions**: Memory-efficient iteration through solutions

## Testing

Run the test suite:

```bash
cargo test
```

Integration tests with the library component:

```bash
./build.sh --compose
# Run test queries
wasmtime run ../../target/scryer-prolog-cli.wasm -- -q "1 = 1."
```

## Troubleshooting

1. **File not found errors**: Use `--dir=.` flag with wasmtime to allow filesystem access
2. **Composition errors**: Ensure the library component is built with `--features=wasi-component`
3. **Query syntax errors**: All queries must end with a period (`.`)
4. **Memory issues**: The CLI uses default heap/stack sizes; these can be adjusted in the code if needed

## License

BSD 3-Clause License (same as Scryer Prolog)