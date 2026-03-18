[org 0x7c00]

KERNEL_OFFSET equ 0x0500 ; 1280 byte reserved for BIOS

cli
xor ax, ax ; set ax to 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x1500 ; 1024 bytes down for stack, 4096 bytes below for bootloader
sti

mov [BOOT_DRIVE], dl ; save drive number in boot drive variable

mov si, info_string_1
call print_string

; move kernel from 0x7e00 to 0x0500
cld
mov si, 0x7e00
mov di, KERNEL_OFFSET
mov cx, [kernel_bytes]
rep movsb

call KERNEL_OFFSET ; run kernel

; if there's an error, print
mov si, error_string_1
call print_string
mov si, error_string_2
call print_string
jmp $ ; hang

print_string:
    push si
    push ax
    push bx
.loop:
    mov al, [si]
    cmp al, 0
    je .done
    mov ah, 0x0e
    mov bh, 0x00
    int 0x10
    inc si
    jmp .loop
.done:
    pop bx
    pop ax
    pop si
    ret

BOOT_DRIVE db 0 ; initialize variable for drive number
error_string_1 db 'Boot error: ', 0
error_string_2 db 'Kernel broken', 0
error_string_3 db 'Unknown (o_O)', 0
info_string_1 db 'Info: No error message after this = failure running kernel', 0

kernel_bytes dw 0 ; will be filled in by build script with size of kernel in bytes
times 510-($-$$) db 0
dw 0xaa55