use isobemak::{build_iso, IsoImage, BootInfo, UefiBootInfo, IsoLayoutProfile, IsoImageFile};
use std::path::PathBuf;

fn main() {
    let mut build_command = std::process::Command::new("cargo");

    build_command.args(&["build",  "--target", "x86_64-unknown-uefi"]);

    let status = build_command.status().expect("Build should have succeeded");

    if !status.success() {
        panic!("Kernel compilation failed!");
    }
    // 1. Define your source and destination paths
    let source_path = PathBuf::from("target/x86_64-unknown-uefi/debug/SigmaOS-2.efi");
    let dest_path = PathBuf::from("target/x86_64-unknown-uefi/debug/BOOTX64.EFI");

    // 2. Rename the file
    std::fs::rename(&source_path, &dest_path)
        .expect("Expected to successfully rename the EFI binary to BOOTX64.EFI");

    let file_mapping = IsoImageFile {
        source: PathBuf::from("target/x86_64-unknown-uefi/debug/BOOTX64.EFI"),
        destination: "EFI/BOOT/BOOTX64.EFI".to_string(),
    };
    
    let iso_image = IsoImage {
        volume_id: Some("SIGMAOS2".to_string()),
        files: vec![file_mapping],
        boot_info: BootInfo {
            bios_boot: None,
            uefi_boot: Some(UefiBootInfo {
                boot_image: PathBuf::from("target/x86_64-unknown-uefi/debug/BOOTX64.EFI"),
                kernel_image: PathBuf::from("target/x86_64-unknown-uefi/debug/BOOTX64.EFI"),
                destination_in_iso: "EFI/BOOT/BOOTX64.EFI".to_string(),
                additional_efi_boot_files: vec![],
                grub_cfg_content: None,
            }),
        },
        layout_profile: IsoLayoutProfile::emulator(),
    };

    build_iso(&PathBuf::from("target/SigmaOS-2.iso"), &iso_image, true)
        .expect("Expected to successfully build the ISO image");
}