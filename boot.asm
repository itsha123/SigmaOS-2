[org 0x7c00]

KERNEL_OFFSET equ 0x0500 ; 1280 byte reserved for BIOS

mov [BOOT_DRIVE], dl ; save drive number in boot drive variable

cli
xor ax, ax ; set ax to 0
mov ds, ax ; set ds to 0
mov es, ax ; set es to 0
mov ss, ax ; set ss to 0
mov sp, 0x0d00 ; 1024 bytes down for stack, 1024 bytes below for kernel
sti

mov bx, KERNEL_OFFSET
mov dh, 2

jmp jump_over

print_char:
    push si
    push ax
    push bx
    mov al, [si]
    mov ah, 0x0e
    mov bh, 0x00
    int 0x10
    pop bx
    pop ax
    pop si
    ret

jump_over:


mov si, my_char
call print_char

jmp $

call disk_load ; Load the kernel from disk into memory at KERNEL_OFFSET

call KERNEL_OFFSET ; run kernel

jmp $ ; infinite loop after kernel done

disk_load:
    pusha

    mov ah, 0x02
    mov al, dh
    mov ch, 0x00
    mov dh, 0x00
    mov cl, 0x02
    mov dl, [BOOT_DRIVE]

    int 0x13

    jc disk_error

    popa
    ret

disk_error:
    jmp $ ; if error loading file, infinite loop

BOOT_DRIVE db 0 ; initialize variable for drive number
my_char db 'a' ; character to print

times 510-($-$$) db 0
dw 0xaa55