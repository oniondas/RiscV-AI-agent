#!/bin/bash
set -e

echo "========================================"
echo "  RISC-V Test Fetcher & Builder Script  "
echo "========================================"

# Check for compiler
if ! command -v riscv64-unknown-elf-gcc &> /dev/null; then
    echo "[ERROR] riscv64-unknown-elf-gcc not found."
    echo "Please install it first inside WSL:"
    echo "sudo apt update && sudo apt install gcc-riscv64-unknown-elf autoconf"
    exit 1
fi

# Clone the official repository
if [ ! -d "$HOME/riscv-tests" ]; then
    echo "[+] Cloning riscv-tests repository..."
    git clone https://github.com/riscv-software-src/riscv-tests.git "$HOME/riscv-tests"
    cd "$HOME/riscv-tests"
    git submodule update --init --recursive
else
    echo "[+] riscv-tests folder already exists. Entering it..."
    cd "$HOME/riscv-tests"
fi

# Build the tests
echo "[+] Configuring and compiling ISA test suites..."
autoconf
./configure --prefix="$(pwd)/install"
make XLEN=32 -k -j $(nproc) isa || true

# Extract bin files for our C++ Testbench
echo "[+] Converting rv32ui-p-* tests to raw binaries (.bin)..."
WORKSPACE_DIR="/mnt/c/Users/Shounak Das/.gemini/antigravity/scratch/intern_case_study"
mkdir -p "$WORKSPACE_DIR/src/tests_bin"

for f in isa/rv32ui-p-*; do
    # Skip any metadata or dump files
    if [[ "$f" == *.dump ]]; then continue; fi
    if [[ ! -f "$f" ]]; then continue; fi
    
    basename=$(basename "$f")
    echo " -> Extracting $basename to src/tests_bin/"
    riscv64-unknown-elf-objcopy -O binary "$f" "$WORKSPACE_DIR/src/tests_bin/$basename.bin"
done

echo ""
echo "[SUCCESS] All generated .bin files have been copied to src/tests_bin/"
echo "You can now run 'python rag_pipeline.py' sequentially test all of them!"
