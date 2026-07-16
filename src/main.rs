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
    loop {}
}