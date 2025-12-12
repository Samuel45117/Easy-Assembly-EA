#!/usr/bin/env python3
"""EA -> NASM transpiler (prototype)

Suporta comandos de alto nível:
- ORG 0x7C00
- LENDER "texto"  -> imprime string via INT 0x10 teletype
- LENDER ident     -> chama rotina/label já definida
- FB / FILL_BOOT   -> preenche até 510 bytes e adiciona assinatura 0xAA55
- DB / DW          -> passthrough
- Blocos ASM { ... } -> passa assembly cru

Gera out.asm e (opcional) tenta invocar `nasm -f bin` para produzir boot.bin.
"""
import sys
import re
from pathlib import Path

class Transpiler:
    def __init__(self, start_label_counter: int = 0):
        self.lines = []
        self.label_counter = start_label_counter
        self.data_section = []
        self.asm = []
        self.defined_buffers = set()
        self.ds_valid = False

    def next_label(self, base="lbl"):
        self.label_counter += 1
        return f"{base}_{self.label_counter}"

    def emit(self, *l):
        for x in l:
            self.asm.append(x)

    def handle_org(self, args):
        a = args.strip()
        if a.upper() in ('BOIS', 'BIOS'):
            a = '0x7C00'
        self.emit(f"org {a}")

    def handle_entered(self, varname):
        if not varname:
            varname = 'entered'
        buf_label = f"{varname}_buf"
        read_label = self.next_label('read')
        done_label = self.next_label('read_done')
        clear_label = self.next_label('clear_buf')
        backspace_label = self.next_label('handle_backspace')
        
        # Não precisa reinicializar DS se já está válido
        if not self.ds_valid:
            self.emit("push cs", "pop ds")
            self.ds_valid = True
        
        # Limpa o buffer antes de começar
        self.emit("push di")
        self.emit(f"mov di, {buf_label}")
        self.emit("mov cx, 128")
        self.emit(f"{clear_label}:")
        self.emit("mov byte [di], 0")
        self.emit("inc di")
        self.emit("loop " + clear_label)
        self.emit("pop di")
        
        # Inicia leitura
        self.emit(f"mov di, {buf_label}")
        self.emit(f"{read_label}:")
        self.emit("xor ah, ah")
        self.emit("int 0x16")
        
        # Verifica Enter
        self.emit("cmp al, 0x0D")
        self.emit(f"je {done_label}")
        
        # Verifica Backspace
        self.emit("cmp al, 0x08")
        self.emit(f"je {backspace_label}")
        
        # Ignora caracteres de controle
        self.emit("cmp al, 0x20")
        self.emit(f"jb {read_label}")
        
        # Limita tamanho do buffer (127 caracteres + null terminator)
        self.emit("push di")
        self.emit("push ax")
        self.emit(f"mov ax, {buf_label}")
        self.emit("add ax, 127")
        self.emit("cmp di, ax")
        self.emit("pop ax")
        self.emit("pop di")
        self.emit(f"jae {read_label}")
        
        # Caractere válido: armazena e imprime
        self.emit("mov [di], al")
        self.emit("inc di")
        self.emit("push ax")
        self.emit("mov ah, 0x0E")
        self.emit("int 0x10")
        self.emit("pop ax")
        self.emit(f"jmp {read_label}")
        
        # Handler de backspace
        self.emit(f"{backspace_label}:")
        self.emit("push ax")
        self.emit(f"mov ax, {buf_label}")
        self.emit("cmp di, ax")
        self.emit("pop ax")
        self.emit(f"jbe {read_label}")
        self.emit("dec di")
        self.emit("mov byte [di], 0")
        self.emit("push ax")
        self.emit("mov ah, 0x0E")
        self.emit("mov al, 0x08")
        self.emit("int 0x10")
        self.emit("mov al, 0x20")
        self.emit("int 0x10")
        self.emit("mov al, 0x08")
        self.emit("int 0x10")
        self.emit("pop ax")
        self.emit(f"jmp {read_label}")
        
        self.emit(f"{done_label}:")
        
        # Adiciona quebra de linha após o Enter
        self.emit("mov byte [di], 0")
        self.emit("mov ah, 0x0E")
        self.emit("mov al, 0x0D")
        self.emit("int 0x10")
        self.emit("mov al, 0x0A")
        self.emit("int 0x10")
        
        # Define o buffer apenas se ainda não foi definido
        if buf_label not in self.defined_buffers:
            self.emit(f"{buf_label}: times 128 db 0")
            self.defined_buffers.add(buf_label)

    def handle_stage2_sectors(self, args):
        n = args.strip() or '1'
        lbl_load = self.next_label('load2')
        lbl_err = self.next_label('disk_err')
        self.emit("; Stage2 loader: read sectors and jump to 0x0000:0x8000")
        self.emit("push cs", "pop ds")
        self.emit(f"mov ah, 0x02")
        self.emit(f"mov al, {n}")
        self.emit("mov ch, 0")
        self.emit("mov cl, 2")
        self.emit("mov dh, 0")
        self.emit("mov bx, 0x8000")
        self.emit("mov ax, 0x0000", "mov es, ax")
        self.emit("int 0x13")
        self.emit("jc {0}".format(lbl_err))
        self.emit("push 0x0000", "push 0x8000", "retf")
        self.emit(f"{lbl_err}:")
        self.emit("hlt")

    def handle_fb(self):
        self.emit("times 510-($-$$) db 0", "dw 0xAA55")

    def handle_db(self, args):
        self.emit(f"db {args}")

    def handle_dw(self, args):
        self.emit(f"dw {args}")

    def handle_lender(self, arg):
        m = re.match(r'^"(.*)"$', arg)
        if m:
            text = m.group(1)
            msg_label = self.next_label('msg')
            loop_label = self.next_label('print')
            done_label = self.next_label('done')
            skip_label = self.next_label('skip')
            
            if not self.ds_valid:
                self.emit("push cs", "pop ds")
                self.ds_valid = True
                
            self.emit(f"jmp {skip_label}")
            if "'" in text and '"' in text:
                safe = text.replace("'", "\\'")
                self.emit(f"{msg_label}: db '{safe}',0")
            elif "'" in text:
                self.emit(f'{msg_label}: db "{text}",0')
            else:
                self.emit(f"{msg_label}: db '{text}',0")
            self.emit(f"{skip_label}:")
            self.emit(f"mov si, {msg_label}")
            self.emit(f"{loop_label}:")
            self.emit("lodsb")
            self.emit("test al, al")
            self.emit(f"jz {done_label}")
            self.emit("mov ah, 0x0E")
            self.emit("int 0x10")
            self.emit(f"jmp {loop_label}")
            self.emit(f"{done_label}:")
        else:
            self.emit(f"call {arg}")

    def handle_br(self):
        self.emit("mov ah, 0x0E")
        self.emit("mov al, 0x0D")
        self.emit("int 0x10")
        self.emit("mov al, 0x0A")
        self.emit("int 0x10")

    def handle_loop(self, label):
        """Cria um label para loop"""
        if not label:
            label = 'main_loop'
        self.emit(f"{label}:")

    def handle_jmp(self, label):
        """Pula para um label"""
        self.emit(f"jmp {label}")

    def parse(self, text):
        lines = text.splitlines()
        self.source_lines = lines
        in_asm = False
        asm_buf = []
        i = 0
        while i < len(lines):
            raw = lines[i]
            line = raw.strip()
            line = re.split(r"[;#]", line, maxsplit=1)[0].strip()
            if not line:
                i += 1
                continue
            if in_asm:
                if line == '}':
                    in_asm = False
                    for a in asm_buf:
                        self.emit(a)
                    asm_buf = []
                else:
                    asm_buf.append(line)
                i += 1
                continue
            if line.upper().startswith('ASM') and '{' in line:
                in_asm = True
                after = line.split('{',1)[1].strip()
                if after:
                    asm_buf.append(after)
                i += 1
                continue

            parts = line.split(None, 1)
            cmd = parts[0].upper()
            arg = parts[1] if len(parts) > 1 else ''
            
            if cmd == 'ORG':
                self.handle_org(arg)
            elif cmd == 'BR':
                self.handle_br()
            elif cmd == 'LOOP':
                self.handle_loop(arg.strip())
            elif cmd == 'JMP':
                self.handle_jmp(arg.strip())
            elif cmd == 'ENTERED':
                self.handle_entered(arg.strip())
            elif cmd == 'STAGE2_SECTORS':
                self.handle_stage2_sectors(arg)
            elif cmd == 'IF':
                cond = arg.strip()
                m = re.match(r"(\w+)\s*=\s*(?:\"(.+)\"|'(.+)'|([^\s]+))", cond)
                if not m:
                    self.emit(line)
                    i += 1
                    continue
                var = m.group(1)
                literal = m.group(2) or m.group(3) or m.group(4)
                block_lines = []
                if hasattr(self, 'source_lines') and self.source_lines:
                    j = i + 1
                    while j < len(self.source_lines):
                        ln = self.source_lines[j].strip()
                        if ln == '.':
                            break
                        block_lines.append(self.source_lines[j])
                        j += 1
                    i = j
                if not block_lines:
                    i += 1
                    continue
                buf_label = f"{var}_buf"
                lit_label = self.next_label('lit')
                ok_label = self.next_label('if_ok')
                end_label = self.next_label('if_end')
                skip_lit_label = self.next_label('skip_lit')
                cmp_lbl = self.next_label('cmp')
                
                if not self.ds_valid:
                    self.emit("push cs", "pop ds")
                    self.ds_valid = True
                
                # String literal - pula para não executar como código
                self.emit(f"jmp {skip_lit_label}")
                self.emit(f"{lit_label}: db '{literal}',0")
                self.emit(f"{skip_lit_label}:")
                
                # Comparação string byte a byte
                self.emit(f"push si")
                self.emit(f"push di")
                self.emit(f"mov si, {buf_label}")
                self.emit(f"mov di, {lit_label}")
                self.emit(f"{cmp_lbl}:")
                self.emit("mov al, [si]")
                self.emit("mov bl, [di]")
                self.emit("cmp al, bl")
                self.emit(f"jne {end_label}")
                self.emit("test al, al")
                self.emit(f"jz {ok_label}")
                self.emit("inc si")
                self.emit("inc di")
                self.emit(f"jmp {cmp_lbl}")
                self.emit(f"{ok_label}:")
                self.emit("pop di")
                self.emit("pop si")
                
                # Bloco interno do IF
                inner = Transpiler(self.label_counter)
                inner.parse('\n'.join(block_lines))
                for a in inner.asm:
                    self.emit(a)
                self.label_counter = inner.label_counter
                self.emit(f"jmp {self.next_label('after_if')}")
                self.emit(f"{end_label}:")
                self.emit("pop di")
                self.emit("pop si")
                self.emit(f"after_if_{self.label_counter}:")
            elif cmd in ('FB', 'FILL_BOOT'):
                self.handle_fb()
            elif cmd == 'DB':
                self.handle_db(arg)
            elif cmd == 'DW':
                self.handle_dw(arg)
            elif cmd == 'LENDER':
                self.handle_lender(arg.strip())
            else:
                self.emit(line)
            i += 1

    def write(self, out_path: Path):
        out = '\n'.join(self.asm) + '\n'
        out_path.write_text(out)

def main():
    if len(sys.argv) < 2:
        print("Usage: ea_transpiler.py <input.ea> [out.asm]")
        sys.exit(1)
    inp = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('out.asm')
    if not inp.exists():
        print(f"File not found: {inp}")
        sys.exit(2)

    src = inp.read_text()
    t = Transpiler()
    t.parse(src)
    t.write(out)
    print(f"Wrote {out}")

    try:
        import subprocess
        res = subprocess.run(['nasm', '-v'], capture_output=True)
        if res.returncode == 0:
            binname = inp.with_suffix('.bin').name if inp.suffix else 'out.bin'
            asm_path = str(out)
            print('nasm found, attempting to assemble to binary...')
            a = subprocess.run(['nasm', '-f', 'bin', asm_path, '-o', binname])
            if a.returncode == 0:
                print(f'Produced {binname}')
            else:
                print('nasm returned error; check out.asm for issues')
    except Exception:
        pass

if __name__ == '__main__':
    main()