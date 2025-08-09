# Scryer Prolog WASI Component Model

## Overview

This document describes the WebAssembly System Interface (WASI) component model support in Scryer Prolog. WASI components allow Scryer Prolog to run in server-side WebAssembly runtimes like Wasmtime and Wasmer, providing a portable and secure execution environment.

## What is a WASI Component?

WASI components are WebAssembly modules that conform to the [Component Model](https://github.com/WebAssembly/component-model) specification. They provide:

- **Strong typing** through WebAssembly Interface Types (WIT)
- **Language interoperability** - components can be written in different languages
- **Composability** - components can be combined to create larger applications
- **Security** - capability-based security model
- **Portability** - run on any WASI-compliant runtime

## Differences from Browser WASM

| Feature | Browser WASM | WASI Component |
|---------|--------------|----------------|
| Target | `wasm32-unknown-unknown` | `wasm32-wasip1` |
| Runtime | Web browsers | Wasmtime, Wasmer, etc. |
| System Access | None | Capability-based |
| Interface | JavaScript bindings | WIT-defined interfaces |
| Use Cases | Web applications | Server-side, CLI tools, embedded |

## Building WASI Components

### Prerequisites

1. **Rust** (1.78 or later)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **wasm32-wasi target**
   ```bash
   rustup target add wasm32-wasi
   ```

3. **wasm-tools**
   ```bash
   cargo install wasm-tools
   ```

### Build Commands

#### Using Make

```bash
# Development build (optimized for debugging)
make wasi-component-dev

# Release build (optimized for size and performance)
make wasi-component-release

# Debug build (unoptimized)
make wasi-component-debug
```

#### Using Cargo directly

```bash
# Build the WASI module
cargo build --target wasm32-wasi --no-default-features --features wasi-component

# Convert to component
wasm-tools component new target/wasm32-wasi/debug/scryer_prolog.wasm \
  -o target/wasm32-wasi/debug/scryer_prolog_component.wasm
```

#### Using Build Script

```bash
# Development profile
./scripts/build-wasi-component.sh --dev

# Release profile
./scripts/build-wasi-component.sh --release
```

#### Using Docker

```bash
# Build using docker-compose
docker-compose -f docker-compose.wasi.yml run build-wasi-component

# Build with specific profile
BUILD_PROFILE=release docker-compose -f docker-compose.wasi.yml run build-wasi-component
```

## Component Interface

The WASI component exposes the following WIT interface:

```wit
interface core {
    resource machine {
        constructor(config: machine-config);
        consult-module-string: func(module-name: string, program: string) -> result<_, string>;
        run-query: func(query: string) -> result<query-state, string>;
    }

    resource query-state {
        next: func() -> result<option<solution>, string>;
    }
}
```

## Testing

### Using Docker (Recommended)

Test the component without installing wasmtime locally:

```bash
# Run interactive tests
./scripts/test-wasi-component.sh target/wasm32-wasi/debug/scryer_prolog_component.wasm

# Run batch tests
./scripts/test-wasi-component.sh -t batch target/wasm32-wasi/debug/scryer_prolog_component.wasm

# Use specific wasmtime version
./scripts/test-wasi-component.sh -v 22.0.0 component.wasm
```

### Using docker-compose

```bash
# Test component info
docker-compose -f docker-compose.wasi.yml run test-component

# Run wasmtime interactively
docker-compose -f docker-compose.wasi.yml run wasmtime

# Debug shell
docker-compose -f docker-compose.wasi.yml run debug-shell
```

### Using Local Wasmtime

If you have wasmtime installed locally:

```bash
# Show component interface
wasmtime component wit scryer_prolog_component.wasm

# Run the component
wasmtime run scryer_prolog_component.wasm

# Invoke specific function
wasmtime run --invoke core.machine.constructor scryer_prolog_component.wasm
```

## CLI Component

Scryer Prolog also provides a CLI component that wraps the library component to provide an interactive command-line interface.

### Building the CLI Component

The CLI component is located in the `wasi/cli-component/` directory and can be built and composed with the library component:

```bash
# Build both library and CLI components and compose them
cd wasi/cli-component
./build.sh --compose

# The composed component will be at:
# target/scryer-prolog-cli.wasm
```

### Using the CLI Component

The CLI component provides both interactive REPL and batch query execution:

```bash
# Start interactive REPL
wasmtime run scryer-prolog-cli.wasm

# Execute a single query
wasmtime run scryer-prolog-cli.wasm -- -q "member(X, [1,2,3])."

# Load a Prolog file and start REPL
wasmtime run --dir=. scryer-prolog-cli.wasm -- -f program.pl

# Load file and execute query
wasmtime run --dir=. scryer-prolog-cli.wasm -- -f facts.pl -q "parent(tom, X)."
```

### CLI Options

- `-f, --file <FILE>...` - Load Prolog file(s) before starting
- `-g, --goal <GOAL>` - Execute goal at startup
- `-q, --query <QUERY>` - Execute query and exit (batch mode)
- `-h, --help` - Display help information
- `-v, --version` - Display version information

### REPL Features

The CLI component's REPL provides:

- Multi-line query support with continuation prompts
- Solution navigation (press `;` for next, ENTER to stop)
- Built-in commands (`:help`, `:quit`, `:clear`)
- Support for the `halt.` query to exit

## Usage Examples

### Basic Query Execution

```javascript
// Pseudo-code for using the component
const machine = new Machine({});

// Load a Prolog program
machine.consultModuleString("facts", `
  parent(tom, bob).
  parent(bob, ann).
  grandparent(X, Y) :- parent(X, Z), parent(Z, Y).
`);

// Run a query
const queryState = machine.runQuery("grandparent(tom, X)");

// Get results
while (true) {
  const result = queryState.next();
  if (!result) break;
  
  if (result.type === "binding") {
    console.log("X =", result.bindings.X);
  }
}
```

### Integration with Host Languages

WASI components can be used from various host languages:

- **Rust**: Using `wasmtime` crate
- **Python**: Using `wasmtime-py`
- **JavaScript/Node.js**: Using `@bytecodealliance/wasmtime`
- **Go**: Using `wasmtime-go`

## Limitations

Current limitations of the WASI component build:

1. **No default features**: FFI, REPL, networking, and TLS are disabled
2. **Limited system access**: Only capabilities exposed through WASI
3. **No threading**: WASI doesn't support threads yet
4. **Experimental**: The component model is still evolving

## Troubleshooting

### Build Errors

**Error: `wasm-tools: command not found`**
```bash
cargo install wasm-tools
```

**Error: `target 'wasm32-wasi' not found`**
```bash
rustup target add wasm32-wasi
```

**Error: `feature 'wasi-component' not found`**

Make sure you're using the latest version with WASI support.

### Runtime Errors

**Error: `failed to find export core`**

The component wasn't built correctly. Rebuild with:
```bash
make clean-wasi
make wasi-component-release
```

**Error: `out of memory`**

The default memory limits might be too low. Wasmtime allows configuration:
```bash
wasmtime run --max-memory-size 1073741824 component.wasm
```

### Docker Issues

**Error: `docker: command not found`**

Install Docker from https://docs.docker.com/get-docker/

**Error: `permission denied`**

Add your user to the docker group:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Future Enhancements

Planned improvements for WASI component support:

1. **Filesystem access**: Enable consulting `.pl` files from WASI filesystem
2. **Networking**: HTTP client support when WASI adds networking
3. **Component composition**: Examples of combining with other components
4. **Performance optimizations**: Profile-guided optimization for components
5. **Standard library**: Subset of standard library compatible with WASI
6. **Enhanced CLI**: Additional REPL features like history, tab completion
7. **Web deployment**: JavaScript transpilation for browser-based CLI

## References

- [WebAssembly Component Model](https://github.com/WebAssembly/component-model)
- [WASI Documentation](https://wasi.dev/)
- [wit-bindgen](https://github.com/bytecodealliance/wit-bindgen)
- [Wasmtime Documentation](https://docs.wasmtime.dev/)
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)