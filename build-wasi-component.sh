#!/bin/bash
set -e

echo "Building Scryer Prolog WASI Component..."

# Build and output to host directory
docker compose run --rm --user root build-library bash -c '
    set -e
    echo "Building with wasip2 target..."
    
    cargo build \
        --target wasm32-wasip2 \
        --profile=wasi-release \
        --no-default-features \
        --features=wasi-component
    
    # Check if it's already a component
    if wasm-tools validate target/wasm32-wasip2/wasi-release/scryer_prolog.wasm --features component-model 2>/dev/null; then
        echo "Output is already a component"
        cp target/wasm32-wasip2/wasi-release/scryer_prolog.wasm /workspace/target/scryer-prolog.wasm
    else
        echo "Creating component..."
        wasm-tools component new target/wasm32-wasip2/wasi-release/scryer_prolog.wasm \
            -o /workspace/target/scryer-prolog.wasm
    fi
    
    echo "Component built successfully!"
    ls -lh /workspace/target/scryer-prolog.wasm
'

echo "Done! Component is at target/scryer-prolog.wasm"