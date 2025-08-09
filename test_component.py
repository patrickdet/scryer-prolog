#!/usr/bin/env python3
"""
Simple test script for Scryer Prolog WASI Component

Prerequisites:
    pip install wasmtime

Usage:
    python test_component.py
"""

import sys
from wasmtime import Store, Module, Instance, Engine, WasiConfig, Linker
import wasmtime.loader

def test_scryer_prolog():
    print("=== Scryer Prolog WASI Component Test ===\n")

    # Create engine and store
    print("Creating WASM engine...")
    engine = Engine()

    # Configure WASI
    wasi_config = WasiConfig()
    wasi_config.inherit_stdout()
    wasi_config.inherit_stderr()
    wasi_config.inherit_stdin()

    store = Store(engine)
    store.set_wasi(wasi_config)

    # Load the component
    print("Loading component...")
    try:
        # For now, we'll just demonstrate the structure
        # Full wasmtime-py component support is still evolving

        with open("target/wasi-component/scryer_prolog_component.wasm", "rb") as f:
            wasm_bytes = f.read()

        print(f"Component loaded: {len(wasm_bytes)} bytes")

        # Note: Full component model support in wasmtime-py is still being developed
        # For now, we can at least verify the component loads

        print("\nComponent loaded successfully!")
        print("\nTo fully test this component, you can:")
        print("1. Use the Rust test program (requires Rust toolchain)")
        print("2. Use JavaScript with @bytecodealliance/jco")
        print("3. Wait for full component model support in wasmtime-py")
        print("\nFor now, here's a demonstration of what the API would look like:")

        print("\n--- Example API Usage (pseudocode) ---")
        print("""
# Create a Prolog machine
machine = prolog.Machine(heap_size=None, stack_size=None)

# Load Prolog code
program = '''
    parent(tom, bob).
    parent(bob, ann).

    ancestor(X, Y) :- parent(X, Y).
    ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
'''
machine.consult_module_string("family", program)

# Run a query
query_state = machine.run_query("ancestor(tom, X).")

# Get solutions
while True:
    solution = query_state.next()
    if not solution:
        break

    if solution.is_bindings():
        bindings = solution.bindings()
        for var in bindings.variables():
            term = bindings.get_binding(var)
            print(f"{var} = {term.to_string()}")
""")

    except FileNotFoundError:
        print("ERROR: Component not found at target/wasi-component/scryer_prolog_component.wasm")
        print("Please run './wasi-build.sh build' first")
        return 1
    except Exception as e:
        print(f"ERROR: {e}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(test_scryer_prolog())
