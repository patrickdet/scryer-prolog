# WASI Component Model Implementation Plan for Scryer Prolog

## Overview

This document outlines the implementation plan for adding WebAssembly System Interface (WASI) component model support to Scryer Prolog while maintaining the existing browser-targeted WASM build. The new build will target server-side WASM runtimes like Wasmtime and Wasmer using the latest WASI Preview 2 and Component Model specifications.

## Current State Analysis

### Existing WASM Build
- **Target**: `wasm32-unknown-unknown` (browser environment)
- **Build Tool**: wasm-pack
- **Bindings**: wasm-bindgen for JavaScript interop
- **Features Disabled**: All default features (ffi, repl, hostname, tls, http, crypto-full)
- **Module Location**: `src/wasm.rs`
- **Profiles**: Custom `wasm-dev` and `wasm-release` profiles

### Limitations
- No access to system resources (filesystem, network, etc.)
- Browser-specific bindings only
- Cannot run in server-side WASM runtimes
- No component model support

## Implementation Tasks

### Phase 1: Project Setup and Configuration

- [x] **Task 1.1**: Add WASI dependencies to Cargo.toml
  - Add `wit-bindgen` as a build dependency
  - Add `wasi` crate for WASI Preview 2 support
  - Create feature flag `wasi-component` for the new build target
  ```toml
  [features]
  wasi-component = ["dep:wasi"]
  
  [target.'cfg(all(target_arch = "wasm32", target_os = "wasi"))'.dependencies]
  wasi = "0.13"
  
  [build-dependencies]
  wit-bindgen = { version = "0.25", optional = true }
  ```

- [x] **Task 1.2**: Create new Cargo profile for WASI builds
  ```toml
  [profile.wasi-dev]
  inherits = "dev"
  opt-level = 2
  lto = "thin"
  
  [profile.wasi-release]
  inherits = "release"
  lto = "fat"
  strip = true
  ```

- [x] **Task 1.3**: Update build.rs to handle WASI component generation
  - Add conditional compilation for wit-bindgen when `wasi-component` feature is enabled
  - Generate bindings from WIT files during build

### Phase 2: WIT Interface Definition

- [x] **Task 2.1**: Create WIT interface definitions
  - Create `wit/` directory in project root
  - Define `scryer-prolog.wit` with core interfaces:
  ```wit
  package scryer:prolog@0.9.4;
  
  interface core {
    record machine-config {
      heap-size: option<u64>,
      stack-size: option<u64>,
    }
    
    resource machine {
      constructor(config: machine-config);
      
      consult-module-string: func(module-name: string, program: string) -> result<_, string>;
      run-query: func(query: string) -> result<query-state, string>;
    }
    
    resource query-state {
      next: func() -> result<option<solution>, string>;
    }
    
    variant solution {
      binding(list<tuple<string, term>>),
      true,
      false,
      exception(string),
    }
    
    variant term {
      atom(string),
      integer(s64),
      float(float64),
      string(string),
      list(list<term>),
      compound(string, list<term>),
      variable(string),
    }
  }
  
  world scryer-prolog {
    export core;
  }
  ```

- [x] **Task 2.2**: Create filesystem interface (optional)
  ```wit
  interface filesystem {
    use wasi:filesystem/types@0.2.0.{descriptor};
    
    consult-file: func(path: descriptor) -> result<_, string>;
  }
  ```

### Phase 3: WASI Module Implementation

- [x] **Task 3.1**: Create `src/wasi_component.rs` module
  - Implement wit-bindgen generated traits
  - Create WASI-compatible wrappers for Machine
  - Handle resource management and lifecycle

- [ ] **Task 3.2**: Implement core functionality
  ```rust
  use wit_bindgen::generate;
  
  generate!({
      world: "scryer-prolog",
      path: "wit",
  });
  
  struct ScryerPrologComponent;
  
  impl Guest for ScryerPrologComponent {
      // Implementation here
  }
  ```

- [x] **Task 3.3**: Add conditional compilation to lib.rs
  ```rust
  #[cfg(all(target_arch = "wasm32", target_os = "wasi"))]
  pub mod wasi_component;
  ```

### Phase 4: Build System Integration

- [x] **Task 4.1**: Create build scripts
  - `scripts/build-wasi-component.sh`:
  ```bash
  #!/bin/bash
  cargo build --target wasm32-wasi --no-default-features --features wasi-component
  wasm-tools component new target/wasm32-wasi/debug/scryer_prolog.wasm \
    -o target/wasm32-wasi/debug/scryer_prolog_component.wasm
  ```

- [x] **Task 4.2**: Add Makefile targets
  ```makefile
  .PHONY: wasi-component-dev wasi-component-release
  
  wasi-component-dev:
  	cargo build --profile=wasi-dev --target wasm32-wasi --no-default-features --features wasi-component
  	wasm-tools component new target/wasm32-wasi/wasi-dev/scryer_prolog.wasm \
  		-o target/wasm32-wasi/wasi-dev/scryer_prolog_component.wasm
  
  wasi-component-release:
  	cargo build --profile=wasi-release --target wasm32-wasi --no-default-features --features wasi-component
  	wasm-tools component new target/wasm32-wasi/wasi-release/scryer_prolog.wasm \
  		-o target/wasm32-wasi/wasi-release/scryer_prolog_component.wasm
  ```

### Phase 5: Testing Infrastructure

- [ ] **Task 5.1**: Set up Wasmtime testing framework
  - Add dev dependencies:
  ```toml
  [dev-dependencies]
  wasmtime = { version = "22", features = ["component-model"] }
  wasmtime-wasi = "22"
  ```

- [ ] **Task 5.2**: Create integration test harness
  - Create `tests/wasi_component/` directory
  - Implement test runner using Wasmtime:
  ```rust
  // tests/wasi_component/mod.rs
  use wasmtime::*;
  use wasmtime_wasi::{WasiCtx, WasiCtxBuilder};
  
  #[test]
  fn test_basic_query() {
      let engine = Engine::default();
      let mut linker = Linker::new(&engine);
      // Setup WASI imports
      wasmtime_wasi::add_to_linker(&mut linker, |s| s)?;
      
      let component = Component::from_file(&engine, "path/to/component.wasm")?;
      let instance = linker.instantiate(&mut store, &component)?;
      
      // Test implementation
  }
  ```

- [ ] **Task 5.3**: Port existing Prolog test files
  - Create test suite that runs .pl files through WASI component
  - Ensure compatibility with existing test expectations

### Phase 6: CI/CD Integration

- [ ] **Task 6.1**: Update GitHub Actions workflow
  ```yaml
  - name: Install wasm-tools
    run: |
      curl -L https://github.com/bytecodealliance/wasm-tools/releases/download/v1.0.0/wasm-tools-linux.tar.gz | tar xz
      sudo mv wasm-tools /usr/local/bin/
  
  - name: Build WASI Component
    run: make wasi-component-release
  
  - name: Run WASI Component Tests
    run: cargo test --features wasi-component --test wasi_component
  ```

- [ ] **Task 6.2**: Add WASI component artifacts to releases
  - Update release workflow to include component builds
  - Create separate download for WASI components

### Phase 7: Documentation

- [ ] **Task 7.1**: Create WASI component usage guide
  - Document how to use with Wasmtime
  - Document how to use with Wasmer
  - Provide example host implementations

- [ ] **Task 7.2**: Update README.md
  - Add WASI component build instructions
  - Document feature differences between browser and WASI builds
  - Add troubleshooting section

### Phase 8: Advanced Features (Optional)

- [ ] **Task 8.1**: Implement WASI filesystem support
  - Enable consulting files from WASI filesystem
  - Implement proper path handling

- [ ] **Task 8.2**: Add WASI networking support (when available)
  - Implement HTTP client functionality
  - Support for TCP/UDP predicates

- [ ] **Task 8.3**: Component composition examples
  - Create examples showing Scryer Prolog composed with other components
  - Document component linking patterns

## Testing Strategy

1. **Unit Tests**: Test individual WASI bindings
2. **Integration Tests**: Run full Prolog programs through WASI component
3. **Compatibility Tests**: Ensure existing Prolog libraries work
4. **Performance Tests**: Benchmark against native and browser builds
5. **Runtime Tests**: Test on multiple WASM runtimes (Wasmtime, Wasmer, WasmEdge)

## Success Criteria

- [ ] WASI component builds successfully with `cargo build --target wasm32-wasi`
- [ ] Component runs in Wasmtime without errors
- [ ] Core Prolog functionality works (consulting modules, running queries)
- [ ] Integration tests pass with >95% compatibility
- [ ] Documentation is complete and examples work
- [ ] CI/CD pipeline builds and tests WASI components
- [ ] Existing browser WASM build remains unchanged and functional

## Risks and Mitigations

1. **Risk**: API incompatibilities between browser and WASI builds
   - **Mitigation**: Use abstraction layer for platform-specific features

2. **Risk**: Performance regression in WASI runtime
   - **Mitigation**: Benchmark early and optimize critical paths

3. **Risk**: Limited WASI Preview 2 runtime support
   - **Mitigation**: Test on multiple runtimes, document requirements

4. **Risk**: Component model specification changes
   - **Mitigation**: Pin wit-bindgen version, monitor spec updates

## Timeline Estimate

- Phase 1-2: 1 week (Setup and Interface Definition)
- Phase 3-4: 2 weeks (Implementation and Build System)
- Phase 5-6: 1 week (Testing and CI/CD)
- Phase 7: 3 days (Documentation)
- Phase 8: 1-2 weeks (Optional advanced features)

**Total: 4-6 weeks for core implementation**

## References

- [WebAssembly Component Model](https://github.com/WebAssembly/component-model)
- [wit-bindgen Documentation](https://github.com/bytecodealliance/wit-bindgen)
- [WASI Preview 2](https://github.com/WebAssembly/WASI/blob/main/preview2/README.md)
- [Wasmtime Component Model](https://docs.wasmtime.dev/api/wasmtime/component/index.html)
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)