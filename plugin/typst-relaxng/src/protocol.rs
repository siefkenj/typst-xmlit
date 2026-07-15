//! Hand-written implementation of the Typst plugin protocol
//! (<https://typst.app/docs/reference/foundations/plugin/#protocol>).
//!
//! Exported functions receive the byte lengths of their arguments, read the
//! argument bytes from the host into one buffer, and send a single byte
//! buffer back. Returning 0 signals success; returning 1 signals that the
//! sent buffer is a UTF-8 error message.

#[cfg(target_arch = "wasm32")]
#[link(wasm_import_module = "typst_env")]
extern "C" {
    fn wasm_minimal_protocol_write_args_to_buffer(ptr: *mut u8);
    fn wasm_minimal_protocol_send_result_to_host(ptr: *const u8, len: usize);
}

/// Read the concatenated argument bytes (total length `total`) from the host.
pub fn read_args(total: usize) -> Vec<u8> {
    #[cfg_attr(not(target_arch = "wasm32"), allow(unused_mut))]
    let mut buf = vec![0u8; total];
    #[cfg(target_arch = "wasm32")]
    unsafe {
        wasm_minimal_protocol_write_args_to_buffer(buf.as_mut_ptr());
    }
    buf
}

/// Send `result` to the host and produce the protocol return code.
pub fn respond(result: Result<Vec<u8>, String>) -> i32 {
    let (bytes, code) = match result {
        Ok(b) => (b, 0),
        Err(e) => (e.into_bytes(), 1),
    };
    #[cfg(target_arch = "wasm32")]
    unsafe {
        wasm_minimal_protocol_send_result_to_host(bytes.as_ptr(), bytes.len());
    }
    #[cfg(not(target_arch = "wasm32"))]
    let _ = &bytes;
    code
}
