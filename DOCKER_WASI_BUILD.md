# Docker WASI Build Guide for Scryer Prolog

This guide explains how to build and test Scryer Prolog's WASI components using Docker.

## Prerequisites

- Docker Engine 20.10 or newer
- Docker Compose v2 or newer
- At least 20GB of available disk space
- 8GB+ RAM recommended

## Quick Start

### Build both library and CLI components
```bash
docker compose run --rm build
```

### Run the WASI REPL
```bash
docker compose run --rm repl
```

### Run tests
```bash
docker compose run --rm test
```

## Available Services

### `build` - Main Build Service
Builds both the library and CLI WASI components with optimized settings.
```bash
docker compose run --rm build
```

### `build-dev` - Development Build
Builds components with debug information for development.
```bash
docker compose run --rm build-dev
```

### `build-library` - Library Component Only
Builds only the Scryer Prolog library component.
```bash
docker compose run --rm build-library
```

### `build-cli` - CLI Component Only
Builds only the CLI component.
```bash
docker compose run --rm build-cli
```

### `test` - Test Suite
Runs comprehensive tests on the built CLI component.
```bash
docker compose run --rm test
```

### `repl` - Interactive REPL
Launches an interactive Scryer Prolog session using the WASI component.
```bash
docker compose run --rm repl
```

### `dev` - Development Shell
Opens a shell with all build tools installed for manual development.
```bash
docker compose run --rm dev
```

### `validate-wit` - WIT Validation
Validates the WebAssembly Interface Type (WIT) files.
```bash
docker compose run --rm validate-wit
```

### `benchmark` - Performance Benchmark
Runs performance benchmarks on the WASI component.
```bash
docker compose run --rm benchmark
```

### `build-wasip1` - Legacy Build
Builds using the older wasm32-wasip1 target (fallback option).
```bash
docker compose run --rm build-wasip1
```

### `clean` - Clean Build Artifacts
Removes all WASI build artifacts.
```bash
docker compose run --rm clean
```

## Common Workflows

### Full Build and Test
```bash
# Clean previous builds
docker compose run --rm clean

# Build components
docker compose run --rm build

# Run tests
docker compose run --rm test

# Try the REPL
docker compose run --rm repl
```

### Development Workflow
```bash
# Enter development shell
docker compose run --rm dev

# Inside the shell, you can run:
cargo component build --profile=wasi-release --no-default-features --features=wasi-component
cd wasi/cli-component && cargo component build --release
```

### Debugging Build Issues
```bash
# Validate WIT files first
docker compose run --rm validate-wit

# Try development build for more verbose output
docker compose run --rm build-dev

# Or use the development shell for manual investigation
docker compose run --rm dev
```

## Build Outputs

After a successful build, you'll find:

- **CLI Component**: `target/scryer-prolog-cli.wasm`
- **Library Component**: `target/wasm32-wasip2/wasi-release/scryer_prolog.wasm`
- **CLI Component (standalone)**: `wasi/cli-component/target/wasm32-wasip2/release/scryer_prolog_cli.wasm`

## Using the Built Components

### Running a Prolog Query
```bash
# Using Docker
docker compose run --rm repl

# Or directly with wasmtime (if installed locally)
wasmtime run target/scryer-prolog-cli.wasm -- -q "member(X, [1,2,3])."
```

### Running a Prolog File
```bash
# Create a test file
echo "test :- write('Hello from WASI!'), nl." > test.pl

# Run it
docker run --rm -v $(pwd):/app -w /app \
  ghcr.io/bytecodealliance/wasmtime:latest \
  run --dir=. target/scryer-prolog-cli.wasm -- -f test.pl -q "test."
```

## Environment Variables

- `BUILD_PROFILE`: Set to `dev` for development builds (default: `release`)
- `WASMTIME_VERSION`: Override wasmtime image version
- `WASMER_VERSION`: Override wasmer image version

## Troubleshooting

### Build Fails with "clang not found"
The build service should install clang automatically. If it fails, try cleaning and rebuilding:
```bash
docker compose run --rm clean
docker compose run --rm build
```

### Out of Memory Errors
The build is configured to use available resources efficiently. If you still encounter issues:
1. Ensure Docker has at least 8GB RAM allocated
2. Close other applications to free memory
3. Try building components separately:
   ```bash
   docker compose run --rm build-library
   docker compose run --rm build-cli
   ```

### Component Validation Fails
Check WIT files are valid:
```bash
docker compose run --rm validate-wit
```

### Can't Find Built Components
Built files are stored in Docker volumes. To access them on your host:
1. Change the volume mapping in docker-compose.yml from `target-cache:/workspace/target` to `./target:/workspace/target`
2. Rebuild the components

## Docker Volume Management

The build uses Docker volumes for caching:
- `cargo-cache`: Cargo registry cache
- `cargo-git`: Cargo git dependencies
- `target-cache`: Build artifacts

To clear all caches:
```bash
docker compose down -v
```

## Advanced Usage

### Custom Build Commands
Use the dev shell for custom build configurations:
```bash
docker compose run --rm dev
# Then inside the container:
cargo component build --release --features custom-feature
```

### Cross-Platform Testing
The build automatically detects architecture (x86_64/aarch64) and uses appropriate tools.

### Integration with CI/CD
```yaml
# Example GitHub Actions workflow
- name: Build WASI Components
  run: docker compose run --rm build

- name: Test Components
  run: docker compose run --rm test
```
