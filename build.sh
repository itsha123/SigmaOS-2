#!/usr/bin/env bash
set -euo pipefail

# Build outputs go into ./build
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ISO_ROOT="$BUILD_DIR/iso_root"

mkdir -p "$BUILD_DIR"

# --- Clean previous build artifacts ---
rm -f \
  "$BUILD_DIR/boot.bin" \
  "$BUILD_DIR/kernel.o" \
  "$BUILD_DIR/kernel.elf" \
  "$BUILD_DIR/kernel.bin" \
  "$BUILD_DIR/floppy.img" \
  "$BUILD_DIR/os.iso"
rm -rf "$ISO_ROOT"

# --- 1) Assemble BIOS boot sector ---
nasm -f bin "$ROOT_DIR/boot.asm" -o "$BUILD_DIR/boot.bin"

# --- 2) Build a freestanding 32-bit kernel binary from kernel.cpp ---
if [[ -x "$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-g++" && -x "$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-ld" && -x "$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-objcopy" ]]; then
  CC="$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-g++"
  LD="$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-ld"
  OBJCOPY="$ROOT_DIR/i686-elf-tools-linux/bin/i686-elf-objcopy"
else
  echo "ERROR: i686-elf-* toolchain not found." >&2
  exit 1
fi

"$CC" -m32 -ffreestanding -O2 -Wall -Wextra \
  -fno-exceptions -fno-rtti -fno-pic -fno-pie \
  -nostdlib -c "$ROOT_DIR/kernel.cpp" -o "$BUILD_DIR/kernel.o"

"$LD" -m elf_i386 -Ttext 0x0500 -e kernel_main -o "$BUILD_DIR/kernel.elf" "$BUILD_DIR/kernel.o"

# turn kernel elf into raw binary
"$OBJCOPY" -O binary "$BUILD_DIR/kernel.elf" "$BUILD_DIR/kernel.bin"

KERNEL_BIN="$BUILD_DIR/kernel.bin"

# Flatten ELF -> raw binary
mkdir -p "$ISO_ROOT"

BOOT_IMG="$ISO_ROOT/boot.img"
rm -f "$BOOT_IMG"

kernel_size=$(stat -c%s "$KERNEL_BIN")
perl -e 'print pack("v", shift)' "$kernel_size" | dd of="$BUILD_DIR/boot.bin" bs=1 seek=508 conv=notrunc status=none

cat "$BUILD_DIR/boot.bin" > "$BOOT_IMG"

# append to preloaded bytes if i want (currently appending kernel)
cat "$KERNEL_BIN" >> "$BOOT_IMG"

# Pad boot.img to a whole number of 512-byte sectors
boot_size=$(stat -c%s "$BOOT_IMG")
pad=$(( (512 - (boot_size % 512)) % 512 ))
if (( pad != 0 )); then
  dd if=/dev/zero bs=1 count="$pad" status=none >> "$BOOT_IMG"
fi

# Compute how many 512-byte sectors to preload
boot_size=$(stat -c%s "$BOOT_IMG")
boot_sectors=$(( boot_size / 512 ))

if command -v genisoimage >/dev/null 2>&1; then
  genisoimage -quiet \
    -o "$BUILD_DIR/os.iso" \
    -b boot.img \
    -no-emul-boot \
    -boot-load-size "$boot_sectors" \
    -c boot.cat \
    "$ISO_ROOT"
else
  echo "ERROR: need genisoimage to create an ISO." >&2
  exit 1
fi

echo "Built: $BUILD_DIR/os.iso"
