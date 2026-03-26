use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Register custom cfg
    println!("cargo:rustc-check-cfg=cfg(no_cuda)");

    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=cuda_wrapper.cpp");
    println!("cargo:rerun-if-changed=cuda_wrapper.h");

    let cuda_available = check_cuda_available();

    if !cuda_available {
        println!("cargo:warning=CUDA not available - GPU acceleration will be disabled");
        println!("cargo:warning=Install CUDA Toolkit to enable GPU features");
        println!("cargo:rustc-cfg=no_cuda");
        return;
    }

    println!("cargo:warning=Building with CUDA support");
    println!("cargo:rustc-cfg=feature=\"cuda\"");

    let nvcc = find_nvcc().expect("CUDA should be available");
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Compile C++ sources with nvcc
    let cpp_files = vec![
        "cuda_src/SECP256K1.cpp",
        "cuda_src/Int.cpp",
        "cuda_src/Point.cpp",
        "cuda_src/IntGroup.cpp",
        "cuda_src/IntMod.cpp",
        "cuda_src/Base58.cpp",
        "cuda_src/hash/sha256.cpp",
        "cuda_src/hash/sha256_sse.cpp",
        "cuda_src/hash/ripemd160.cpp",
        "cuda_src/hash/ripemd160_sse.cpp",
        "cuda_wrapper.cpp",
    ];

    let cuda_files = vec![
        "cuda_src/GPU/SearchKernel.cu",
    ];

    // Get GPU architecture from environment or use default
    // sm_86: RTX 3090, A6000, etc. (Ampere)
    // sm_87: A100 (Ampere)
    // sm_89: RTX 5070, 5080, 5090 (Ada Lovelace) - requires CUDA 12.0+
    // sm_90: H100 (Hopper) - requires CUDA 12.0+
    let gpu_arch = env::var("CUDA_ARCH").unwrap_or_else(|_| {
        // Auto-detect GPU architecture if possible, otherwise default to sm_120
        // sm_89: Ada Lovelace (RTX 40xx)
        // sm_100/sm_120: Blackwell (RTX 50xx)
        detect_gpu_arch().unwrap_or_else(|| "sm_120".to_string())
    });

    // Detect driver's CUDA version to avoid toolkit/driver mismatch
    let driver_cuda_ver = detect_driver_cuda_version();
    if let Some(ref ver) = driver_cuda_ver {
        println!("cargo:warning=Driver supports CUDA: {}", ver);
    }

    // Extract compute capability number from gpu_arch (e.g., "sm_89" -> "89")
    let compute_cap = gpu_arch.strip_prefix("sm_").unwrap_or("89");

    println!("cargo:warning=Using GPU architecture: {}", gpu_arch);
    println!("cargo:warning=Set CUDA_ARCH env var to override (e.g., CUDA_ARCH=sm_89)");

    // Use -gencode to generate SASS only (no PTX) to avoid toolkit/driver PTX version mismatch.
    // When the toolkit is newer than the driver, embedded PTX can cause
    // "unsupported toolchain" errors even though SASS would work fine.
    let gencode_flag = format!(
        "-gencode=arch=compute_{},code={}",
        compute_cap, gpu_arch
    );

    // Compile C++ files
    for file in &cpp_files {
        println!("cargo:rerun-if-changed={}", file);

        // Add SSE flags for SSE-optimized files
        let mut compiler_opts = "-fPIC".to_string();
        if file.contains("_sse.cpp") {
            compiler_opts.push_str(",-msse,-msse2,-mssse3,-msse4.1");
        }

        let status = Command::new(&nvcc)
            .args(&[
                "-c",
                "-O3",
                "-std=c++14",
                "--compiler-options", &compiler_opts,
                "-Icuda_src",  // Add include path for our sources
                &gencode_flag,
                "-o",
            ])
            .arg(out_dir.join(format!("{}.o", file.replace("/", "_").replace(".cpp", ""))))
            .arg(file)
            .status()
            .expect("Failed to compile C++ file");

        if !status.success() {
            panic!("Failed to compile {}", file);
        }
    }

    // Compile CUDA files
    for file in &cuda_files {
        println!("cargo:rerun-if-changed={}", file);

        let status = Command::new(&nvcc)
            .args(&[
                "-c",
                "-O3",
                "-std=c++14",
                "--compiler-options", "-fPIC",
                "-Icuda_src",  // Add include path for our sources
                &gencode_flag,
                "-o",
            ])
            .arg(out_dir.join(format!("{}.o", file.replace("/", "_").replace(".cu", ""))))
            .arg(file)
            .status()
            .expect("Failed to compile CUDA file");

        if !status.success() {
            panic!("Failed to compile {}", file);
        }
    }

    // Link all object files
    let mut object_files: Vec<PathBuf> = cpp_files
        .iter()
        .map(|f| out_dir.join(format!("{}.o", f.replace("/", "_").replace(".cpp", ""))))
        .collect();

    object_files.extend(
        cuda_files
            .iter()
            .map(|f| out_dir.join(format!("{}.o", f.replace("/", "_").replace(".cu", "")))),
    );

    let lib_path = out_dir.join("libcuda_bitcrack.a");

    let status = Command::new("ar")
        .arg("rcs")
        .arg(&lib_path)
        .args(&object_files)
        .status()
        .expect("Failed to create static library");

    if !status.success() {
        panic!("Failed to create static library");
    }

    // Add CUDA library paths
    println!("cargo:rustc-link-search=native={}", out_dir.display());
    println!("cargo:rustc-link-search=native=/usr/local/cuda/lib64");

    println!("cargo:rustc-link-lib=static=cuda_bitcrack");
    println!("cargo:rustc-link-lib=cudart");
    println!("cargo:rustc-link-lib=stdc++");
}

fn find_nvcc() -> Option<String> {
    // Check CUDA installations, prioritizing user-specified version
    let nvcc_paths = vec![
        "/usr/local/cuda/bin/nvcc",                 // Standard CUDA install (symlink to current version)
        "nvcc",                                      // In PATH
        "/usr/bin/nvcc",                             // System install (nvidia-cuda-toolkit)
        "/usr/lib/nvidia-cuda-toolkit/bin/nvcc",    // Debian/Ubuntu nvidia-cuda-toolkit package
    ];

    for nvcc_path in nvcc_paths {
        if let Ok(output) = Command::new(nvcc_path).arg("--version").output() {
            if output.status.success() {
                println!("cargo:warning=Found CUDA compiler at: {}", nvcc_path);

                // Try to get version
                if let Ok(stdout) = String::from_utf8(output.stdout) {
                    for line in stdout.lines() {
                        if line.contains("release") {
                            println!("cargo:warning=CUDA version: {}", line.trim());
                        }
                    }
                }

                return Some(nvcc_path.to_string());
            }
        }
    }

    None
}

fn detect_gpu_arch() -> Option<String> {
    // Query the GPU's compute capability via nvidia-smi
    if let Ok(output) = Command::new("nvidia-smi")
        .args(&["--query-gpu=compute_cap", "--format=csv,noheader"])
        .output()
    {
        if let Ok(stdout) = String::from_utf8(output.stdout) {
            let cap = stdout.trim();
            if !cap.is_empty() {
                // Convert "12.0" -> "sm_120", "8.9" -> "sm_89"
                let sm = cap.replace(".", "");
                let arch = format!("sm_{}", sm);
                println!("cargo:warning=Auto-detected GPU compute capability: {} ({})", cap, arch);
                return Some(arch);
            }
        }
    }
    None
}

fn detect_driver_cuda_version() -> Option<String> {
    // Run nvidia-smi to get the driver's supported CUDA version
    if let Ok(output) = Command::new("nvidia-smi").output() {
        if let Ok(stdout) = String::from_utf8(output.stdout) {
            // Look for "CUDA Version: X.Y" in nvidia-smi output
            for line in stdout.lines() {
                if let Some(pos) = line.find("CUDA Version:") {
                    let ver_str = line[pos + 14..].trim();
                    // Extract just the version number (e.g., "13.1")
                    let ver: String = ver_str.chars()
                        .take_while(|c| c.is_ascii_digit() || *c == '.')
                        .collect();
                    if !ver.is_empty() {
                        return Some(ver);
                    }
                }
            }
        }
    }
    None
}

fn check_cuda_available() -> bool {
    find_nvcc().is_some()
}
