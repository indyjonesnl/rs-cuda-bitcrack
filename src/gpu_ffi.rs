/// GPU FFI bindings for CUDA-accelerated secp256k1 operations
///
/// This module provides Rust bindings to the CUDA implementation of secp256k1
/// operations. It falls back to CPU-only mode if CUDA is not available.

#[repr(C)]
pub struct GpuDeviceInfo {
    pub name: [u8; 256],
    pub compute_capability_major: i32,
    pub compute_capability_minor: i32,
    pub total_memory: usize,
    pub multiprocessor_count: i32,
}

impl GpuDeviceInfo {
    pub fn name_str(&self) -> String {
        let end = self.name.iter().position(|&c| c == 0).unwrap_or(256);
        String::from_utf8_lossy(&self.name[..end]).to_string()
    }
}

#[cfg(not(no_cuda))]
mod cuda_impl {
    use super::*;

    extern "C" {
        pub fn gpu_init(device_id: i32) -> bool;
        pub fn gpu_cleanup();
        pub fn gpu_search_address(
            target_address: *const u8,
            range_min: *const u8,
            range_max: *const u8,
            private_key_out: *mut u8,
        ) -> bool;
        pub fn gpu_generate_address(
            private_key: *const u8,
            address_out: *mut u8,
            address_type: i32,
        ) -> bool;
        pub fn gpu_get_device_info(device_id: i32, info: *mut GpuDeviceInfo) -> bool;
    }

    pub fn init(device_id: i32) -> Result<(), String> {
        unsafe {
            if gpu_init(device_id) {
                Ok(())
            } else {
                Err("Failed to initialize GPU".to_string())
            }
        }
    }

    pub fn cleanup() {
        unsafe {
            gpu_cleanup();
        }
    }

    pub fn search_address(
        target: &str,
        range_min: &[u8; 32],
        range_max: &[u8; 32],
    ) -> Option<[u8; 32]> {
        let mut private_key = [0u8; 32];
        let target_cstr = format!("{}\0", target);

        unsafe {
            if gpu_search_address(
                target_cstr.as_ptr(),
                range_min.as_ptr(),
                range_max.as_ptr(),
                private_key.as_mut_ptr(),
            ) {
                Some(private_key)
            } else {
                None
            }
        }
    }

    pub fn generate_address(private_key: &[u8; 32], address_type: i32) -> Option<String> {
        let mut address = [0u8; 35];

        unsafe {
            if gpu_generate_address(private_key.as_ptr(), address.as_mut_ptr(), address_type) {
                let end = address.iter().position(|&c| c == 0).unwrap_or(35);
                Some(String::from_utf8_lossy(&address[..end]).to_string())
            } else {
                None
            }
        }
    }

    pub fn get_device_info(device_id: i32) -> Option<GpuDeviceInfo> {
        let mut info = GpuDeviceInfo {
            name: [0; 256],
            compute_capability_major: 0,
            compute_capability_minor: 0,
            total_memory: 0,
            multiprocessor_count: 0,
        };

        unsafe {
            if gpu_get_device_info(device_id, &mut info as *mut GpuDeviceInfo) {
                Some(info)
            } else {
                None
            }
        }
    }
}

#[cfg(no_cuda)]
mod cuda_impl {
    use super::*;

    #[allow(dead_code)]
    pub fn init(_device_id: i32) -> Result<(), String> {
        Err("CUDA support not compiled - rebuild with CUDA Toolkit installed".to_string())
    }

    #[allow(dead_code)]
    pub fn cleanup() {}

    #[allow(dead_code)]
    pub fn search_address(
        _target: &str,
        _range_min: &[u8; 32],
        _range_max: &[u8; 32],
    ) -> Option<[u8; 32]> {
        None
    }

    #[allow(dead_code)]
    pub fn generate_address(_private_key: &[u8; 32], _address_type: i32) -> Option<String> {
        None
    }

    #[allow(dead_code)]
    pub fn get_device_info(_device_id: i32) -> Option<GpuDeviceInfo> {
        None
    }
}

// Public API (works with or without CUDA)
pub use cuda_impl::*;

#[cfg(not(no_cuda))]
pub fn is_cuda_available() -> bool {
    true
}

#[cfg(no_cuda)]
pub fn is_cuda_available() -> bool {
    false
}
