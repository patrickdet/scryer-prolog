# Scryer Prolog WASI Components

This directory contains everything related to WebAssembly System Interface (WASI) support for Scryer Prolog, organized following the WebAssembly Component Model architecture.

## Directory Structure

```
wasi/
├── wit/                    # WebAssembly Interface Types (WIT) definitions
│   └── scryer-prolog.wit   # Library component interface
├── cli-component/          # CLI wrapper component
│   ├── wit/                # CLI component WIT files
│   │   ├── cli.wit         # CLI component interface
│   │   └── deps.toml       # WIT dependencies manifest
│   ├── src/                # Rust source code
│   ├── examples/           # Example Prolog programs
│   ├── build.sh            # Build script
│   └── README.md           # CLI component documentation
└── README.md               # This file
```

## Components Overview

### 1. Library Component (`scryer:prolog/core`)

The core Scryer Prolog engine compiled as a WASI component. This is built from the main Scryer Prolog codebase with the `wasi-component` feature.

**Interface**: `wit/scryer-prolog.wit`

**Build command**:
```bash
cargo component build --profile=wasi-release --no-default-features --features=wasi-component
```

### 2. CLI Component (`scryer:prolog-cli`)

A command-line interface wrapper that imports the library component and provides an interactive REPL and batch query execution.

**Interface**: `cli-component/wit/cli.wit`

**Build command**:
```bash
cd cli-component
cargo component build --release
```

## Building Everything

### Quick Build

From the repository root:

```bash
# Build and compose both components
cd wasi/cli-component
./build.sh --compose
```

This will produce a complete CLI at `target/scryer-prolog-cli.wasm`.

### Step-by-Step Build

1. **Build the library component** (from repository root):
   ```bash
   cargo component build --profile=wasi-release --no-default-features --features=wasi-component
   ```

2. **Build the CLI component**:
   ```bash
   cd wasi/cli-component
   cargo component build --release
   ```

3. **Compose them together**:
   ```bash
   wasm-tools compose \
     ../../target/wasm32-wasip2/wasi-release/scryer_prolog.wasm \
     --plug target/wasm32-wasip2/release/scryer_prolog_cli.wasm \
     -o ../../target/scryer-prolog-cli.wasm
   ```

### Using Docker

Build everything in Docker:

```bash
docker compose -f docker-compose.cli.yml run build-and-test-all
```

## WIT Dependency Management

The CLI component uses `wit-deps` to manage its dependency on the library component's WIT interface. The dependency is specified in `cli-component/wit/deps.toml`:

```toml
scryer-prolog = { path = "../../wit" }
```

This ensures the CLI component always uses the correct interface definitions from the library component.

## Usage Examples

### Interactive REPL

```bash
wasmtime run target/scryer-prolog-cli.wasm
```

### Execute a Query

```bash
wasmtime run target/scryer-prolog-cli.wasm -- -q "member(X, [1,2,3])."
```

### Load Prolog Files

```bash
wasmtime run --dir=. target/scryer-prolog-cli.wasm -- -f program.pl
```

## Development Workflow

1. **Modify library component**: Edit main Scryer Prolog code
2. **Modify CLI component**: Edit code in `cli-component/src/`
3. **Update interfaces**: Edit WIT files and run build to regenerate bindings
4. **Test**: Use the composed component with wasmtime

## Testing

### Unit Tests

```bash
# Test library component
cargo test --features=wasi-component

# Test CLI component
cd wasi/cli-component
cargo test
```

### Integration Tests

```bash
# Run example queries
cd wasi/cli-component
./examples/run-examples.sh
```

## Troubleshooting

### Common Issues

1. **`wit-deps` not found**: Install with `cargo install wit-deps`
2. **Component composition fails**: Ensure both components are built with matching interfaces
3. **File access denied**: Use `--dir=.` flag with wasmtime for filesystem access

### Build Requirements

- Rust 1.78+
- `wasm32-wasip2` target
- `cargo-component`
- `wasm-tools`
- `wit-deps` (for CLI component)

### Installation

```bash
# Install all required tools
rustup target add wasm32-wasip2
cargo install cargo-component wasm-tools wit-deps
```

## Architecture Benefits

This modular architecture provides:

1. **Clear separation**: Library logic vs CLI interface
2. **Reusability**: Library component can be used by other components
3. **Type safety**: WIT interfaces provide strong typing
4. **Future flexibility**: Easy to add new wrapper components (e.g., HTTP server)

## Future Components

Planned additional components:

- **HTTP Server Component**: RESTful API for Prolog queries
- **Language Server Component**: LSP implementation for IDEs
- **Test Runner Component**: Automated testing framework

## References

- [Component Model Documentation](https://github.com/WebAssembly/component-model)
- [cargo-component](https://github.com/bytecodealliance/cargo-component)
- [wit-deps](https://github.com/bytecodealliance/wit-deps)
- [WASI Documentation](https://wasi.dev/)