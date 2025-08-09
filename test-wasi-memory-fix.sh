#!/bin/bash
set -e

echo "Testing WASI build with memory fix..."
echo "Profile wasi-release now uses:"
echo "  - lto = thin (instead of fat)"
echo "  - opt-level = z (size optimization)"
echo "  - codegen-units = 1"
echo ""

# Test with docker compose
echo "Starting build..."
docker compose run --rm --user root build-library 2>&1 | while IFS= read -r line; do
    # Monitor for memory-related errors or successful compilation
    if [[ "$line" == *"Killed"* ]] || [[ "$line" == *"memory"* ]] || [[ "$line" == *"Cannot allocate"* ]]; then
        echo "❌ MEMORY ISSUE DETECTED: $line"
        exit 1
    elif [[ "$line" == *"Compiling"* ]]; then
        echo "✓ Compiling: $(echo "$line" | grep -o 'Compiling.*')"
    elif [[ "$line" == *"error"* ]]; then
        # These are code errors, not memory errors - that's progress!
        echo "⚠️  Code error (not memory): $(echo "$line" | head -c 100)..."
    elif [[ "$line" == *"component built"* ]]; then
        echo "✅ BUILD SUCCESSFUL!"
    fi
done

echo ""
echo "Test complete. If you see compilation errors above (not memory errors),"
echo "that means the memory fix worked and we just need to fix the code issues."