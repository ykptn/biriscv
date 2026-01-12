#!/bin/bash

# Quick test script for tb_concept tests

cd "$(dirname "$0")"

echo "====================================="
echo "TB_CONCEPT Test Runner"
echo "====================================="
echo ""

if [ "$1" == "compare" ]; then
    echo "Running side-by-side comparison (MUL vs MULE)..."
    echo ""
    echo "--- Building and running with MUL (MODE=1) ---"
    make clean > /dev/null 2>&1
    make run TEST=comparison MODE=1 VCD_FILE=comparison_mul.vcd
    echo ""
    echo "--- Building and running with MULE (MODE=2) ---"
    make clean > /dev/null 2>&1
    make run TEST=comparison MODE=2 VCD_FILE=comparison_mule.vcd
    echo ""
    echo "====================================="
    echo "VCD files generated:"
    echo "  - comparison_mul.vcd"
    echo "  - comparison_mule.vcd"
    echo ""
    echo "View with: gtkwave comparison_mul.vcd comparison_mule.vcd"
    echo "====================================="
elif [ "$1" == "latency" ]; then
    echo "Running latency hiding demo (all modes)..."
    make clean > /dev/null 2>&1
    make run TEST=latency_hiding MODE=1 VCD_FILE=latency_mul.vcd
    make clean > /dev/null 2>&1
    make run TEST=latency_hiding MODE=2 VCD_FILE=latency_mule.vcd
    make clean > /dev/null 2>&1
    make run TEST=latency_hiding MODE=3 VCD_FILE=latency_cbm.vcd
    echo "VCD files: latency_mul.vcd, latency_mule.vcd, latency_cbm.vcd"
else
    echo "Usage: ./test.sh [compare|latency]"
    echo ""
    echo "  compare - Run comparison test (MUL vs MULE)"
    echo "  latency - Run latency hiding test (all modes)"
    echo ""
    echo "Or use makefile directly:"
    echo "  make run TEST=comparison MODE=1 VCD_FILE=test.vcd"
fi
