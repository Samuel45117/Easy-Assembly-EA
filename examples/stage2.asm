org 0x8000
push cs
pop ds
mov si, debug_msg
mov ah, 0x0E
debug_loop:
lodsb
test al, al
jz debug_done
int 0x10
jmp debug_loop
debug_done:
jmp start_shell
debug_msg: db 'Stage2 loaded!', 0x0D, 0x0A, 0
start_shell:
push cs
pop ds
jmp skip_4
msg_1: db 'HubbleOS Boot Manager',0
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
jmp skip_8
msg_5: db "Type 'help' for commands",0
skip_8:
mov si, msg_5
print_6:
lodsb
test al, al
jz done_7
mov ah, 0x0E
int 0x10
jmp print_6
done_7:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
main_loop:
jmp skip_12
msg_9: db 'Hubbsh> ',0
skip_12:
mov si, msg_9
print_10:
lodsb
test al, al
jz done_11
mov ah, 0x0E
int 0x10
jmp print_10
done_11:
push di
mov di, commands_buf
mov cx, 128
clear_buf_15:
mov byte [di], 0
inc di
loop clear_buf_15
pop di
mov di, commands_buf
read_13:
xor ah, ah
int 0x16
cmp al, 0x0D
je read_done_14
cmp al, 0x08
je handle_backspace_16
cmp al, 0x20
jb read_13
push di
push ax
mov ax, commands_buf
add ax, 127
cmp di, ax
pop ax
pop di
jae read_13
mov [di], al
inc di
push ax
mov ah, 0x0E
int 0x10
pop ax
jmp read_13
handle_backspace_16:
push ax
mov ax, commands_buf
cmp di, ax
pop ax
jbe read_13
dec di
mov byte [di], 0
push ax
mov ah, 0x0E
mov al, 0x08
int 0x10
mov al, 0x20
int 0x10
mov al, 0x08
int 0x10
pop ax
jmp read_13
read_done_14:
mov byte [di], 0
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
commands_buf: times 128 db 0
jmp skip_lit_20
lit_17: db 'help',0
skip_lit_20:
push si
push di
mov si, commands_buf
mov di, lit_17
cmp_21:
mov al, [si]
mov bl, [di]
cmp al, bl
jne if_end_19
test al, al
jz if_ok_18
inc si
inc di
jmp cmp_21
if_ok_18:
pop di
pop si
push cs
pop ds
jmp skip_25
msg_22: db 'Available commands:',0
skip_25:
mov si, msg_22
print_23:
lodsb
test al, al
jz done_24
mov ah, 0x0E
int 0x10
jmp print_23
done_24:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_29
msg_26: db '  help   - Show this help',0
skip_29:
mov si, msg_26
print_27:
lodsb
test al, al
jz done_28
mov ah, 0x0E
int 0x10
jmp print_27
done_28:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_33
msg_30: db '  clear  - Clear screen',0
skip_33:
mov si, msg_30
print_31:
lodsb
test al, al
jz done_32
mov ah, 0x0E
int 0x10
jmp print_31
done_32:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_37
msg_34: db '  dir    - List files',0
skip_37:
mov si, msg_34
print_35:
lodsb
test al, al
jz done_36
mov ah, 0x0E
int 0x10
jmp print_35
done_36:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_41
msg_38: db '  about  - About HubbleOS',0
skip_41:
mov si, msg_38
print_39:
lodsb
test al, al
jz done_40
mov ah, 0x0E
int 0x10
jmp print_39
done_40:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp after_if_42
if_end_19:
pop di
pop si
after_if_42:
jmp skip_lit_46
lit_43: db 'clear',0
skip_lit_46:
push si
push di
mov si, commands_buf
mov di, lit_43
cmp_47:
mov al, [si]
mov bl, [di]
cmp al, bl
jne if_end_45
test al, al
jz if_ok_44
inc si
inc di
jmp cmp_47
if_ok_44:
pop di
pop si
mov ah, 0x00
mov al, 0x03
int 0x10
push cs
pop ds
jmp skip_51
msg_48: db 'HubbleOS Boot Manager',0
skip_51:
mov si, msg_48
print_49:
lodsb
test al, al
jz done_50
mov ah, 0x0E
int 0x10
jmp print_49
done_50:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp after_if_52
if_end_45:
pop di
pop si
after_if_52:
jmp skip_lit_56
lit_53: db 'dir',0
skip_lit_56:
push si
push di
mov si, commands_buf
mov di, lit_53
cmp_57:
mov al, [si]
mov bl, [di]
cmp al, bl
jne if_end_55
test al, al
jz if_ok_54
inc si
inc di
jmp cmp_57
if_ok_54:
pop di
pop si
push cs
pop ds
jmp skip_61
msg_58: db 'Directory listing:',0
skip_61:
mov si, msg_58
print_59:
lodsb
test al, al
jz done_60
mov ah, 0x0E
int 0x10
jmp print_59
done_60:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_65
msg_62: db '  No files found',0
skip_65:
mov si, msg_62
print_63:
lodsb
test al, al
jz done_64
mov ah, 0x0E
int 0x10
jmp print_63
done_64:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp after_if_66
if_end_55:
pop di
pop si
after_if_66:
jmp skip_lit_70
lit_67: db 'about',0
skip_lit_70:
push si
push di
mov si, commands_buf
mov di, lit_67
cmp_71:
mov al, [si]
mov bl, [di]
cmp al, bl
jne if_end_69
test al, al
jz if_ok_68
inc si
inc di
jmp cmp_71
if_ok_68:
pop di
pop si
push cs
pop ds
jmp skip_75
msg_72: db 'HubbleOS v0.1',0
skip_75:
mov si, msg_72
print_73:
lodsb
test al, al
jz done_74
mov ah, 0x0E
int 0x10
jmp print_73
done_74:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp skip_79
msg_76: db 'A simple bootable OS',0
skip_79:
mov si, msg_76
print_77:
lodsb
test al, al
jz done_78
mov ah, 0x0E
int 0x10
jmp print_77
done_78:
mov ah, 0x0E
mov al, 0x0D
int 0x10
mov al, 0x0A
int 0x10
jmp after_if_80
if_end_69:
pop di
pop si
after_if_80:
jmp main_loop
