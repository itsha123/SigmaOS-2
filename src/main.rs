#![no_std]
#![no_main]

use uefi::prelude::*;

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    uefi::system::with_stdout(|stdout| {
        stdout.clear().unwrap();
    });
    log::info!("SigmaOS 2 is born.");

    let gop_handle = boot::get_handle_for_protocol::<uefi::proto::console::gop::GraphicsOutput>()
    .expect("Expected to find a GOP handle");
    let mut gop = boot::open_protocol_exclusive::<uefi::proto::console::gop::GraphicsOutput>(gop_handle)
    .expect("Expected to open the GOP protocol");

    // 1. Get the framebuffer configuration
    let stride = gop.current_mode_info().stride(); // Number of pixels per scan line

    // 2. Get mutable access to the raw pixel array
    let mut fb = gop.frame_buffer();
    // Grab it for post UEFI
    let fb_ptr = fb.as_mut_ptr();
    let fb_size = fb.size();

    let _memory_map = unsafe {
        boot::exit_boot_services(None) 
    };
    let raw_framebuffer: &mut [u8] = unsafe {
        core::slice::from_raw_parts_mut(fb_ptr, fb_size)
    };
    let row = 500;
    let col = 500;
    let pixel_index = (row * stride + col) * 4;

    raw_framebuffer[pixel_index]     = 255; // Blue
    raw_framebuffer[pixel_index + 1] = 0;   // Green
    raw_framebuffer[pixel_index + 2] = 0;   // Red
    raw_framebuffer[pixel_index + 3] = 0;   // Reserved
    loop {} // Freeze
}