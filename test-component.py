#!/usr/bin/env python3
"""Test Scryer Prolog WASI Component"""

import sys
try:
    from wasmtime import Store, Module, Engine, Config, WasiConfig
    import wasmtime.loader
except ImportError:
    print("Please install wasmtime-py: pip install wasmtime")
    sys.exit(1)

def test_component():
    # Configure the engine
    config = Config()
    config.wasm_component_model = True
    engine = Engine(config)
    
    # Create store with WASI
    store = Store(engine)
    
    # Load the component
    print("Loading WASI component...")
    with open("target/scryer-prolog.wasm", "rb") as f:
        component_bytes = f.read()
    
    try:
        module = Module(engine, component_bytes)
        print(f"✓ Component loaded successfully ({len(component_bytes) / 1024 / 1024:.1f} MB)")
        
        # List exports
        print("\nExports:")
        for export in module.exports(store):
            print(f"  - {export}")
        
        # Since this is a library component, we need to instantiate it differently
        # The component exports scryer:prolog/core@0.9.4 interface
        
        print("\nComponent type: Library (exports scryer:prolog/core@0.9.4)")
        print("This component needs to be composed with a CLI runner to be executable.")
        
    except Exception as e:
        print(f"Error loading component: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(test_component())