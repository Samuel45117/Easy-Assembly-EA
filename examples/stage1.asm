org 0x7C00
push cs
pop ds
jmp skip_4
msg_1: db 'Loading HubbleOS...',0
skip_4:
mov si, msg_1
print_2:
lodsb
test al, al
jz done_3
mov ah, 0x0E
int 0x10
jmp print_2
done_3:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
push cs
pop ds
mov [boot_drive], dl
push cs
pop ds
mov dl, [boot_drive]
; Stage2 loader: read sectors and jump to 0x0000:0x8000
push cs
pop ds
mov ah, 0x02
mov al, 5
mov ch, 0
mov cl, 2
mov dh, 0
mov bx, 0x8000
mov ax, 0x0000
mov es, ax
int 0x13
jc disk_err_6
push 0x0000
push 0x8000
retf
disk_err_6:
hlt
boot_drive: db 0
times 510-($-$$) db 0
dw 0xAA55
