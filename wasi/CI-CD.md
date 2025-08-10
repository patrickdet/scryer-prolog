# WASI CI/CD Documentation

## Overview

Scryer Prolog provides automated CI/CD pipelines for building and testing WebAssembly (WASI) components. These pipelines ensure that every commit and release produces validated, ISO-conformant WASI binaries.

## GitHub Actions Workflows

### 1. Main WASI Build Workflow (`wasi-build.yml`)

**Triggers:**
- Push to `master` or `wasi-build` branches
- Pull requests affecting WASI-related code
- Git tags (for releases)
- Manual workflow dispatch

**Jobs:**

#### Build Job
1. Sets up Rust with `wasm32-wasip2` target
2. Installs required tools:
   - `cargo-component` (v0.21.1)
   - `wasm-tools` (v1.235.0)
   - `wasmtime` (v28.0.0)
3. Builds core WASI component
4. Builds CLI component
5. Composes final WASI CLI
6. Uploads artifacts with version naming

#### ISO Conformity Test Job
1. Downloads built WASI components
2. Runs all 266 ISO Prolog conformity tests
3. Tests sample programs (factorial, family relations)
4. Reports test results
5. Fails the build if any ISO tests fail

#### Release Job (tags only)
1. Creates GitHub release
2. Attaches WASI components
3. Includes SHA-256 checksums
4. Auto-generates release notes

### 2. Docker Build Workflow (`wasi-docker-build.yml`)

**Triggers:**
- Manual workflow dispatch
- Weekly schedule (Sundays at 00:00 UTC)

**Purpose:**
- Alternative build method using Docker
- Ensures reproducible builds
- Useful for debugging build issues

## Artifacts

### Naming Convention

**For tagged releases:**
- `wasi-components-v1.2.3/`
  - `scryer-prolog-cli.wasm`
  - `scryer-prolog-core.wasm`

**For commits:**
- `wasi-components-abc12345/` (first 8 chars of SHA)
  - `scryer-prolog-cli.wasm`
  - `scryer-prolog-core.wasm`

### Component Descriptions

1. **`scryer-prolog-cli.wasm`** (~4MB)
   - Full CLI with REPL
   - File I/O support
   - Query execution
   - All standard libraries

2. **`scryer-prolog-core.wasm`** (~3.9MB)
   - Core Prolog engine
   - Embeddable in other WASI applications
   - WIT interface for integration

## ISO Conformity Testing

The CI pipeline runs comprehensive ISO Prolog conformity tests:

- **266 tests** covering:
  - Syntax and parsing
  - Term manipulation
  - Arithmetic operations
  - List operations
  - DCG support
  - Error handling

All tests must pass for a build to succeed.

## Using CI Artifacts

### From GitHub UI
1. Go to Actions tab
2. Select a successful workflow run
3. Download artifacts from the bottom of the page

### Via GitHub API
```bash
# Get latest artifact
gh api repos/mthom/scryer-prolog/actions/artifacts \
  --jq '.artifacts[0].archive_download_url' | \
  xargs gh api > artifacts.zip
```

### From Releases
For tagged versions, download directly from the Releases page.

## Local Testing

To replicate CI tests locally:

```bash
# Build WASI components
make wasi-component-release

# Run ISO tests
wasmtime run --dir=. target/scryer-prolog-cli.wasm \
  -f tests-pl/iso-conformity-tests.pl \
  -q "iso_conformity_tests:run_tests."
```

## Docker Build

For reproducible builds using Docker:

```bash
# Using docker-compose
docker compose run build

# Manual Docker build
docker build -t scryer-wasi-build -f wasi/Dockerfile .
docker run --rm -v $(pwd):/workspace scryer-wasi-build \
  cargo build --target wasm32-wasip2 --release \
  --no-default-features --features=wasi-component
```

## Troubleshooting CI

### Build Failures
1. Check Rust toolchain version
2. Verify `wasm32-wasip2` target installation
3. Check cargo-component compatibility

### Test Failures
1. Review ISO test output in artifacts
2. Check for library loading issues
3. Verify module initialization

### Docker Build Issues
1. Ensure Docker daemon is running
2. Check available disk space
3. Verify Docker Compose version

## Release Process

1. **Create Tag**
   ```bash
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   ```

2. **CI Automatically:**
   - Builds WASI components
   - Runs ISO conformity tests
   - Creates GitHub release
   - Attaches binaries and checksums

3. **Verify Release:**
   - Check release page
   - Download and test binaries
   - Verify checksums

## Maintenance

### Updating Dependencies
- Edit version numbers in workflow files
- Test locally before committing
- Monitor deprecation warnings

### Adding Tests
1. Add test files to `tests-pl/`
2. Update test runner in workflow
3. Ensure tests work with WASI runtime

### Performance Monitoring
- Check artifact sizes in CI logs
- Monitor build times
- Track test execution duration