#!/bin/bash

# Test Dual-Mode Bitcoin Puzzle Testing
# This script demonstrates how tests run in both CPU and GPU modes

echo "======================================"
echo "Dual-Mode Bitcoin Puzzle Testing Demo"
echo "======================================"
echo

# Check if GPU is available
echo "1. Checking GPU availability..."
cargo run --quiet 2>/dev/null | grep -E "(GPU|CUDA)" || true
echo

# Run tests for puzzles 1-5 to show dual mode
echo "2. Running dual-mode tests for puzzles 1-5..."
echo "   Each puzzle will be tested in both CPU and GPU modes"
echo

for i in {01..05}; do
    echo "--- Puzzle $i ---"

    # Run CPU test
    echo -n "  CPU Test: "
    if timeout 10 cargo test --quiet "test_puzzle_${i}_cpu" 2>&1 | grep -q "test result: ok"; then
        echo "✓ PASSED"
    else
        echo "✗ FAILED"
    fi

    # Run GPU test
    echo -n "  GPU Test: "
    if timeout 10 cargo test --quiet "test_puzzle_${i}_gpu" 2>&1 | grep -q "test result: ok"; then
        echo "✓ PASSED"
    else
        echo "✗ FAILED (or GPU not available)"
    fi

    echo
done

echo "3. Running tests with output to show mode detection..."
echo
echo "Example output from Puzzle 3:"
timeout 10 cargo test "test_puzzle_03" -- --nocapture 2>&1 | grep -E "(CPU Mode|GPU Mode|test result)" || true
echo

echo "======================================"
echo "Summary:"
echo "- Each puzzle has two test functions: *_cpu and *_gpu"
echo "- CPU tests always run using pure Rust implementation"
echo "- GPU tests use CUDA when available, skip otherwise"
echo "- Both modes verify the same Bitcoin addresses are found"
echo "======================================"