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

# Flatten ELF -> raw binary
"$OBJCOPY" -O binary "$BUILD_DIR/kernel.elf" "$BUILD_DIR/kernel.bin"

# --- 3) Create a 1.44MB floppy image and write boot + kernel to it ---

dd if=/dev/zero of="$BUILD_DIR/floppy.img" bs=512 count=2880 status=none

dd if="$BUILD_DIR/boot.bin" of="$BUILD_DIR/floppy.img" conv=notrunc status=none

dd if="$BUILD_DIR/kernel.bin" of="$BUILD_DIR/floppy.img" bs=512 seek=1 conv=notrunc status=none

# --- 4) Build a bootable ISO (El Torito) using the floppy image ---
mkdir -p "$ISO_ROOT"
cp "$BUILD_DIR/floppy.img" "$ISO_ROOT/boot.img"

if command -v genisoimage >/dev/null 2>&1; then
  genisoimage -quiet \
    -o "$BUILD_DIR/os.iso" \
    -b boot.img \
    -c boot.cat \
    "$ISO_ROOT"
else
  echo "ERROR: need genisoimage to create an ISO." >&2
  exit 1
fi

echo "Built: $BUILD_DIR/os.iso"
