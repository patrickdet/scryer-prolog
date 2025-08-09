# Scryer Prolog WASI Component

This document describes how to build and run Scryer Prolog as a WebAssembly System Interface (WASI) component.

## Overview

Scryer Prolog can be compiled to WebAssembly and run as a WASI component, enabling it to run in any WASI-compatible runtime such as Wasmtime, Wasmer, or WasmEdge. This allows Scryer Prolog to be embedded in various environments including cloud functions, edge computing platforms, and sandboxed environments.

## Prerequisites

- Rust 1.85 or later
- `wasm-tools` CLI
- `wasmtime` (for testing)
- Docker (optional, for containerized development)

## Building the WASI Component

### Manual Build

1. Add the required Rust targets:
   ```bash
   rustup target add wasm32-wasip1
   ```

2. Build the WASI component:
   ```bash
   cargo build --target wasm32-wasip1 --profile wasi-release --no-default-features --features wasi-component
   ```

3. Create the component using wasm-tools:
   ```bash
   wasm-tools component new \
     target/wasm32-wasip1/wasi-release/scryer_prolog.wasm \
     --adapt wasi_snapshot_preview1.reactor.wasm \
     -o target/wasm32-wasip1/wasi-release/scryer_prolog.component.wasm
   ```

   Note: You'll need to download the WASI adapter from the Wasmtime releases page.

### Docker Build

The easiest way to build the WASI component is using the provided Docker setup:

```bash
# Build everything (native + WASI)
./scripts/dev.sh build

# Build only the WASI component
./scripts/dev.sh build-wasi
```

## Running the WASI Component

### With Wasmtime

```bash
# Run interactively
wasmtime run scryer_prolog.component.wasm

# Run with a Prolog file
wasmtime run --dir=. scryer_prolog.component.wasm -- my_program.pl

# With debugging output
WASMTIME_LOG=debug wasmtime run scryer_prolog.component.wasm
```

### Using Docker

```bash
# Run the WASI component interactively
./scripts/dev.sh wasi

# Run with custom arguments
./scripts/dev.sh wasmtime -- my_program.pl
```

## Component Interface

The WASI component exports a WIT (WebAssembly Interface Types) interface defined in `wasi/wit/scryer-prolog.wit`:

```wit
package scryer:prolog@0.9.4;

interface core {
    resource machine {
        constructor(config: machine-config);
        consult-module-string: func(module-name: string, program: string) -> result<_, string>;
        run-query: func(query: string) -> result<query-state, string>;
    }

    resource query-state {
        next: func() -> result<option<solution>, string>;
    }

    // ... additional types
}
```

This allows host applications to:
1. Create Prolog machine instances
2. Load Prolog programs
3. Execute queries
4. Iterate through solutions

## Development Workflow

### Using Docker Compose

The project includes a comprehensive Docker Compose setup for development:

```bash
# Start development container with source mounted
./scripts/dev.sh dev

# Run tests
./scripts/dev.sh test

# Test WASI component specifically
./scripts/dev.sh test-wasi

# Access development shell
./scripts/dev.sh shell
```

### Local Development

1. Make changes to the source code
2. Build the WASI component
3. Test with wasmtime
4. Iterate

## Examples

### Basic Usage

```prolog
% hello.pl
main :- 
    write('Hello from WASI!'), nl,
    halt.
```

Run with:
```bash
wasmtime run --dir=. scryer_prolog.component.wasm -- hello.pl
```

### Embedding in Host Application

```rust
use wasmtime::*;
use wasmtime::component::*;

// Load and instantiate the component
let engine = Engine::default();
let component = Component::from_file(&engine, "scryer_prolog.component.wasm")?;
let linker = Linker::new(&engine);
let store = Store::new(&engine, ());
let instance = linker.instantiate(&mut store, &component)?;

// Use the Prolog machine
// ... (host-specific implementation)
```

## Limitations

- **Single-threaded**: WASI components run in a single-threaded environment
- **File system access**: Limited to directories explicitly allowed with `--dir`
- **Network access**: Not available in the current WASI preview
- **FFI**: Foreign function interface is not available in WASI builds

## Troubleshooting

### Build Errors

1. **Missing wasm32-wasip1 target**:
   ```
   error: failed to run custom build command for `scryer-prolog`
   ```
   Solution: Run `rustup target add wasm32-wasip1`

2. **wit-bindgen version mismatch**:
   ```
   error: failed to resolve wit from path
   ```
   Solution: Ensure you're using wit-bindgen 0.42 or compatible version

3. **Component creation fails**:
   ```
   error: failed to encode a component from module
   ```
   Solution: Ensure you have the correct WASI adapter file

### Runtime Errors

1. **File not found**:
   ```
   Error: failed to find file
   ```
   Solution: Use `--dir` flag to allow file system access

2. **Out of memory**:
   ```
   Error: wasm trap: out of bounds memory access
   ```
   Solution: Increase memory limits in wasmtime or use a smaller program

## Performance Considerations

- WASI components have some overhead compared to native execution
- JIT compilation in wasmtime provides good performance for long-running programs
- For best performance, use wasmtime's caching features

## Future Improvements

- [ ] Full WASI Preview 2 support
- [ ] Network capabilities when available in WASI
- [ ] Component composition support
- [ ] Better error handling and debugging tools

## Resources

- [WASI Documentation](https://wasi.dev/)
- [Component Model](https://component-model.bytecodealliance.org/)
- [wit-bindgen](https://github.com/bytecodealliance/wit-bindgen)
- [Wasmtime](https://wasmtime.dev/)