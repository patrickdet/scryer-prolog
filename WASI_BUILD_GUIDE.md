# Scryer Prolog WASI Build Guide

This guide explains how to build and test Scryer Prolog as a WebAssembly System Interface (WASI) component using Docker.

## Overview

The build system uses Docker to create a reproducible environment for building WASI components. The built artifacts are stored in the host's `target/` directory, making them accessible for use with any WASI runtime.

## Prerequisites

- Docker and Docker Compose
- Bash shell (for the build script)

That's it! All other dependencies (Rust, wasm-tools, wasmtime) are handled inside Docker containers.

## Quick Start

```bash
# Build the WASI component
./wasi-build.sh build

# Run a quick test
./wasi-build.sh smoke-test

# Start interactive REPL
./wasi-build.sh run

# Run a specific Prolog file
./wasi-build.sh run-file examples/hello.pl
```

## Build System Architecture

The system consists of three main components:

1. **docker-compose.wasi-simple.yml** - Handles building the WASI component
2. **docker-compose.wasi-test.yml** - Provides various testing and runtime environments
3. **wasi-build.sh** - User-friendly wrapper script

### Key Features

- **Host-accessible artifacts**: Built components are stored in `./target/wasi-component/`
- **Reproducible builds**: Docker ensures consistent build environment
- **Cross-platform**: Works on Linux, macOS (x86_64 and ARM64)
- **Multiple test modes**: From quick smoke tests to comprehensive test suites

## Command Reference

### Build Commands

#### `build`
Builds the WASI component in release mode.
```bash
./wasi-build.sh build
```
Output: `target/wasi-component/scryer_prolog_component.wasm`

#### `build-dev`
Builds the WASI component in development mode (faster compilation, larger size).
```bash
./wasi-build.sh build-dev
```

#### `clean`
Removes all WASI build artifacts.
```bash
./wasi-build.sh clean
```

### Test Commands

#### `test`
Runs the comprehensive test suite.
```bash
./wasi-build.sh test
```

#### `smoke-test`
Runs a quick verification test.
```bash
./wasi-build.sh smoke-test
```

#### `test-all`
Runs all available tests (verification, smoke test, and full suite).
```bash
./wasi-build.sh test-all
```

#### `benchmark`
Runs performance benchmarks.
```bash
./wasi-build.sh benchmark
```

### Runtime Commands

#### `run`
Starts an interactive Prolog REPL in WASI.
```bash
./wasi-build.sh run
```

#### `run-file`
Executes a specific Prolog file.
```bash
./wasi-build.sh run-file examples/hello.pl
```

#### `shell`
Opens a shell in the test environment for manual testing.
```bash
./wasi-build.sh shell
```

### Information Commands

#### `info`
Shows information about the built component.
```bash
./wasi-build.sh info
```

#### `help`
Displays usage information.
```bash
./wasi-build.sh help
```

## Using the Built Component

After building, the WASI component is available at:
```
target/wasi-component/scryer_prolog_component.wasm
```

You can use this component with any WASI runtime:

### With Wasmtime
```bash
# Interactive REPL
wasmtime run target/wasi-component/scryer_prolog_component.wasm

# Run a Prolog file
wasmtime run --dir=. target/wasi-component/scryer_prolog_component.wasm examples/hello.pl

# With library access
wasmtime run --dir=. --dir=library target/wasi-component/scryer_prolog_component.wasm
```

### With Wasmer
```bash
wasmer run target/wasi-component/scryer_prolog_component.wasm
```

### With WasmEdge
```bash
wasmedge target/wasi-component/scryer_prolog_component.wasm
```

## Docker Compose Services

### Build Services (docker-compose.wasi-simple.yml)

- **build-wasi**: Builds release version
- **build-wasi-dev**: Builds development version
- **test-wasi**: Basic component test
- **run-wasi**: Interactive runtime

### Test Services (docker-compose.wasi-test.yml)

- **verify**: Checks component exists and shows WIT interface
- **smoke-test**: Quick functionality test
- **repl**: Interactive REPL
- **run-file**: Run specific Prolog files
- **test-suite**: Comprehensive test suite
- **benchmark**: Performance testing
- **memory-test**: Memory stress testing
- **debug**: Runtime with debug logging
- **shell**: Manual testing environment

## Examples

### Building and Testing
```bash
# Full workflow
./wasi-build.sh build
./wasi-build.sh test-all

# Quick verification
./wasi-build.sh build
./wasi-build.sh smoke-test
```

### Running Prolog Programs
```bash
# Create a simple program
cat > my_program.pl << 'EOF'
main :-
    write('Hello, WASI!'), nl,
    current_prolog_flag(version_data, Version),
    write('Scryer Prolog '), write(Version), nl,
    halt.

:- initialization(main).
EOF

# Run it
./wasi-build.sh run-file my_program.pl
```

### Interactive Development
```bash
# Start REPL
./wasi-build.sh run

# In the REPL:
?- write('Hello'), nl.
Hello
true.

?- X is 2 + 2.
X = 4.

?- halt.
```

## Troubleshooting

### Component not found
If you see "Component not found", run:
```bash
./wasi-build.sh build
```

### Permission denied
Make sure the build script is executable:
```bash
chmod +x wasi-build.sh
```

### Docker not running
Ensure Docker daemon is running:
```bash
# On Linux
sudo systemctl start docker

# On macOS
# Start Docker Desktop
```

### Build fails with out of memory
The WASI build can be memory-intensive. Ensure Docker has at least 4GB of memory allocated.

### Component runs out of memory
Increase WASI memory limits:
```bash
wasmtime run --wasm-max-memory=1073741824 target/wasi-component/scryer_prolog_component.wasm
```

## Advanced Usage

### Custom Docker Compose Commands

You can run Docker Compose commands directly:

```bash
# Build only, without tests
docker-compose -f docker-compose.wasi-simple.yml run --rm build-wasi

# Run with custom environment
RUST_LOG=debug docker-compose -f docker-compose.wasi-test.yml run --rm debug

# Access build container shell
docker-compose -f docker-compose.wasi-simple.yml run --rm build-wasi bash
```

### Integration with CI/CD

The build system is designed for CI/CD integration:

```yaml
# Example GitHub Actions workflow
- name: Build WASI Component
  run: ./wasi-build.sh build

- name: Test Component
  run: ./wasi-build.sh test-all

- name: Upload Artifact
  uses: actions/upload-artifact@v3
  with:
    name: scryer-prolog-wasi
    path: target/wasi-component/scryer_prolog_component.wasm
```

## Component Details

The built component:
- Implements the WIT interface defined in `wasi/wit/scryer-prolog.wit`
- Is a reactor component (can be instantiated multiple times)
- Supports WASI Preview 1
- Typical size: ~30-40MB (release mode)

## Next Steps

- Check out the [WASI_README.md](WASI_README.md) for general WASI information
- Explore the `examples/` directory for sample Prolog programs
- Read the WIT interface at `wasi/wit/scryer-prolog.wit` for embedding details