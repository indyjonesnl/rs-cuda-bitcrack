# CUDA Setup Guide for rs-cuda-bitcrack

This guide will help you set up CUDA support to enable GPU-accelerated Bitcoin puzzle solving on your NVIDIA RTX 5070 laptop.

## Prerequisites

- NVIDIA RTX 5070 GPU (or any CUDA-capable NVIDIA GPU)
- Linux operating system (Ubuntu 22.04/24.04 recommended)
- GCC/G++ compiler
- Git

## Step 1: Install NVIDIA Drivers

First, install the latest NVIDIA drivers for your GPU:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nvidia-driver-560  # Or latest available version

# Check installation
nvidia-smi
```

You should see your RTX 5070 listed with driver information.

## Step 2: Install CUDA Toolkit

The NVIDIA RTX 5070 uses the **Ada Lovelace architecture (SM 8.9)**.

**IMPORTANT**: This project is configured to use **nvidia-cuda-toolkit** from Ubuntu's repositories, NOT Flatpak CUDA.

### Recommended: Install nvidia-cuda-toolkit (Ubuntu/Debian)

```bash
# Install nvidia-cuda-toolkit from system repositories
sudo apt update
sudo apt install nvidia-cuda-toolkit

# Verify installation
nvcc --version

# Add to PATH if needed (usually automatic)
echo 'export PATH=/usr/lib/nvidia-cuda-toolkit/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

**Note**: Ubuntu's nvidia-cuda-toolkit package installs to `/usr/lib/nvidia-cuda-toolkit/` and `/usr/bin/nvcc`, not `/usr/local/cuda/`.

### Alternative: NVIDIA Official CUDA Toolkit (for newer CUDA versions)

If you need CUDA 12.0+ for full SM 8.9 support (Ubuntu's package may be older):

```bash
# Add NVIDIA package repositories
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update

# Install CUDA Toolkit
sudo apt install cuda-toolkit-12-6

# Add to PATH
echo 'export PATH=/usr/local/cuda-12.6/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

## Step 3: Verify CUDA Installation

```bash
# Check NVCC compiler location
which nvcc
# Should output: /usr/bin/nvcc or /usr/local/cuda-XX.X/bin/nvcc

# Check CUDA version
nvcc --version
# Should output something like:
# Cuda compilation tools, release 11.5 (Ubuntu package) or 12.6 (NVIDIA package)

# Check GPU is detected
nvidia-smi
# Should show your RTX 5070
```

**For Ubuntu nvidia-cuda-toolkit package:**
- NVCC location: `/usr/bin/nvcc` (symlink) → `/usr/lib/nvidia-cuda-toolkit/bin/nvcc`
- CUDA version: Typically 11.5 or 11.7 (depending on Ubuntu version)
- Architecture support: Up to SM 8.6 (RTX 3090/A6000)

**For NVIDIA official CUDA toolkit:**
- NVCC location: `/usr/local/cuda-12.6/bin/nvcc`
- CUDA version: 12.0+ (supports SM 8.9 for RTX 5070)
- Full Ada Lovelace support

## Step 4: Build rs-cuda-bitcrack with CUDA Support

Once CUDA is installed, rebuild the project:

```bash
# Clean previous builds
cargo clean

# Build with CUDA support
cargo build --release

# Verify CUDA is enabled
cargo run
```

You should see:
```
✓ CUDA support compiled
✓ GPU initialized successfully
  Device: NVIDIA GeForce RTX 5070
  Compute: 8.9
  Memory: 8 GB (or your GPU's memory)
  SMs: 40 (streaming multiprocessors)
```

## Step 5: Run GPU-Accelerated Tests

```bash
# Run quick tests (1-30)
cargo test

# Run all tests including GPU-intensive ones
cargo test -- --ignored

# Run specific puzzle test
cargo test test_puzzle_66 -- --nocapture --ignored
```

## Architecture Notes

### RTX 5070 Specifications
- **Architecture**: Ada Lovelace (SM 8.9)
- **CUDA Cores**: 5120 (approximate)
- **Memory**: 8-16 GB GDDR6
- **Compute Capability**: 8.9
- **Peak FP32**: ~30-35 TFLOPS

### Build Configuration

The build system automatically detects your GPU's compute capability and sets the appropriate architecture flags:

```rust
// In build.rs:
"-arch=sm_89"  // For RTX 5070 (Ada Lovelace)
```

If you have a different GPU, the build system will detect it automatically.

## Troubleshooting

### Issue: "CUDA not available"

**Solution**: Make sure CUDA Toolkit is installed and `nvcc` is in your PATH:
```bash
which nvcc
# Should output: /usr/local/cuda-XX.X/bin/nvcc
```

### Issue: "libcudart.so not found"

**Solution**: Add CUDA lib64 to your library path:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

Add this to `~/.bashrc` to make it permanent.

### Issue: Compilation errors with "sm_89"

**Solution**: Your CUDA version might be too old. RTX 5070 (SM 8.9) requires CUDA 12.0+.

Update CUDA Toolkit to version 12.0 or later.

### Issue: GPU not detected

**Solution**: Check NVIDIA driver:
```bash
nvidia-smi

# If not working, reinstall drivers:
sudo apt purge nvidia-*
sudo apt install nvidia-driver-560
sudo reboot
```

## Performance Expectations

### CPU vs GPU Performance

| Puzzle | Range Size | CPU Time | GPU Time (RTX 5070) | Speedup |
|--------|-----------|----------|---------------------|---------|
| 1-20   | <1M keys  | <1 min   | <1 sec              | ~100x   |
| 30     | 1B keys   | ~5 min   | ~3 sec              | ~100x   |
| 40     | 1T keys   | ~days    | ~minutes            | ~1000x  |
| 50+    | >1PB keys | infeasible | hours-days         | >10000x |

## Next Steps

With CUDA enabled:

1. **Run benchmarks**: Test your GPU performance on smaller puzzles
2. **Optimize batch sizes**: Tune the GPU workload for your specific hardware
3. **Monitor temperatures**: Use `nvidia-smi -l 1` to watch GPU utilization and temp
4. **Scale up**: Try solving unsolved puzzles (66+) with GPU acceleration

## Additional Resources

- [NVIDIA CUDA Documentation](https://docs.nvidia.com/cuda/)
- [RTX 5070 Specifications](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/)
- [Jean-Luc Pons' VanitySearch](https://github.com/JeanLucPons/VanitySearch)
- [Bitcoin Puzzle Challenge](https://privatekeys.pw/puzzles/bitcoin-puzzle-tx)

## Security Notice

This tool is intended for:
- Recovery of lost Bitcoin private keys (with authorization)
- Educational purposes and cryptographic research
- Solving the Bitcoin Puzzle challenge fairly

Unauthorized use to access others' funds is illegal and unethical.
