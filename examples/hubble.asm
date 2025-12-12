org 0x7C00
push cs
pop ds
jmp skip_4
msg_1: db 'Hello HubbleOS from HUBBLUEMU',0
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
times 510-($-$$) db 0
dw 0xAA55
