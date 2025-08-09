# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Regular Rust Build
```bash
# Build debug mode
cargo build

# Build release mode (optimized)
cargo build --release

# Run tests
cargo test

# Run with examples
cargo run -- program.pl
```

### WASI Component Model Build
The project has extensive WASI (WebAssembly System Interface) support with component model architecture:

```bash
# Build WASI component (different profiles)
make wasi-component-dev      # Development profile
make wasi-component-release  # Release profile (optimized)
make wasi-component-debug    # Debug profile

# Check/install WASI dependencies
make check-deps
make install-deps  # Installs wasm-tools and wasm32-wasi target

# Clean WASI artifacts
make clean-wasi

# Run WASI component
wasmtime run target/wasm32-wasi/debug/scryer_prolog_component.wasm
```

### Testing
```bash
# Run all tests
cargo test

# Run specific test module
cargo test machine::lib_machine::tests

# Run benchmarks
cargo bench

# Test WASI components
cd wasi/cli-component && cargo test
```

## Architecture Overview

### Core Components

**Warren Abstract Machine (WAM) Implementation**
- Core execution engine in `src/machine/` implementing the WAM architecture
- `src/machine/machine_state.rs` - Central machine state management
- `src/machine/dispatch.rs` - Instruction dispatch and execution
- `src/machine/heap.rs` - Heap memory management with specialized cell types
- `src/machine/stack.rs` - Stack frame management for execution

**Memory and Type System**
- `src/arena.rs` - Arena allocator for efficient memory management
- `src/atom_table.rs` - Global atom table with string interning
- `src/types.rs` - Core type definitions including heap cells and WAM types
- Compact string representation using packed UTF-8 encoding (24x memory reduction)

**Compilation Pipeline**
- `src/parser/` - Prolog parser and lexer generating AST
- `src/codegen.rs` - Code generation from AST to WAM instructions
- `src/loader.rs`, `src/machine/loader.rs` - Module loading and compilation orchestration
- `src/machine/compile.rs` - WAM compilation logic

**Libraries and Extensions**
- `src/lib/` - Standard library modules (lists, dcgs, clpz, etc.)
- Constraint Logic Programming: `src/lib/clpz.pl` (integers), `src/lib/clpb.pl` (booleans)
- Tabling support via delimited continuations in `src/lib/tabling.pl`
- HTTP server/client in `src/lib/http/`

**FFI and External Integration**
- `src/ffi.rs` - Foreign Function Interface for C libraries
- `src/wasi_component.rs` - WASI Component Model support
- `src/machine/lib_machine/` - Library machine for embedding Scryer

### Key Design Patterns

1. **First Instantiated Argument Indexing**: Indexes on leftmost non-variable argument across all clauses
2. **Attributed Variables**: SICStus-compatible interface for constraint programming
3. **Partial Strings**: Efficient representation of string tails as difference lists
4. **Stream-based I/O**: All I/O operations work through a unified stream abstraction

## Development Workflow

### Adding New Built-in Predicates
1. Define the predicate in appropriate module under `src/lib/`
2. Add system call handling in `src/machine/system_calls.rs` if needed
3. Register in `src/lib/builtins.pl` for visibility

### Debugging
- Use `library(debug)` predicates: `*` to generalize goals, `$` for execution traces
- Set `RUST_LOG=debug` for Rust-level debugging output
- The REPL supports TAB completion and history

### Module System
- Predicates are organized in modules with explicit imports/exports
- Use `:- use_module(library(module_name))` to import
- Module qualification with `:` operator: `lists:member(X, [1,2,3])`

## Testing Approach

### Rust Tests
- Unit tests alongside code with `#[cfg(test)]` modules
- Integration tests in `src/machine/lib_machine/tests.rs`

### Prolog Tests
- Test files in `tests-pl/` directory
- ISO conformance tests in `tests-pl/iso-conformity-tests.pl`
- Library-specific tests in `src/tests/`

### WASI Testing
- Component tests in `wasi/cli-component/tests/`
- Test scripts in `scripts/test-wasi-component.sh`

## Important Files

- `src/toplevel.pl` - REPL implementation and query handling
- `src/loader.pl` - Module loading predicates
- `src/machine/attributed_variables.pl` - Attributed variables implementation
- `~/.scryerrc` - User configuration file loaded at startup