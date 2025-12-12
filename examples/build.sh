#!/bin/bash

echo "=== Building HubbleOS ==="

# Compila Stage1 (bootloader)
echo "1. Compiling Stage1 bootloader..."
python3 ea_transpiler.py Stage1.ea stage1.asm
if [ $? -ne 0 ]; then
    echo "Error: Failed to transpile Stage1"
    exit 1
fi

nasm -f bin stage1.asm -o stage1.bin
if [ $? -ne 0 ]; then
    echo "Error: Failed to assemble Stage1"
    exit 1
fi

# Verifica se Stage1 tem exatamente 512 bytes
SIZE=$(stat -c%s stage1.bin 2>/dev/null || stat -f%z stage1.bin 2>/dev/null)
if [ "$SIZE" -ne 512 ]; then
    echo "Error: Stage1 must be exactly 512 bytes, got $SIZE bytes"
    exit 1
fi
echo "   Stage1: 512 bytes ✓"

# Compila Stage2 (shell)
echo "2. Compiling Stage2 shell..."
python3 ea_transpiler.py Stage2.ea stage2.asm
if [ $? -ne 0 ]; then
    echo "Error: Failed to transpile Stage2"
    exit 1
fi

nasm -f bin stage2.asm -o stage2.bin
if [ $? -ne 0 ]; then
    echo "Error: Failed to assemble Stage2"
    exit 1
fi

SIZE2=$(stat -c%s stage2.bin 2>/dev/null || stat -f%z stage2.bin 2>/dev/null)
echo "   Stage2: $SIZE2 bytes"

# Calcula quantos setores o Stage2 ocupa (arredonda para cima)
SECTORS=$(( ($SIZE2 + 511) / 512 ))
echo "   Stage2 sectors needed: $SECTORS"

# Verifica se precisa atualizar STAGE2_SECTORS
CURRENT_SECTORS=$(grep "STAGE2_SECTORS" Stage1.ea | awk '{print $2}')
if [ "$SECTORS" -gt "$CURRENT_SECTORS" ]; then
    echo ""
    echo "WARNING: Stage2 needs $SECTORS sectors but Stage1.ea has STAGE2_SECTORS $CURRENT_SECTORS"
    echo "Update Stage1.ea to: STAGE2_SECTORS $SECTORS"
    echo ""
fi

# Junta Stage1 + Stage2 em um arquivo de disco
echo "3. Creating bootable disk image..."

# Cria arquivo de disco vazio de 1.44MB (tamanho de um disquete)
dd if=/dev/zero of=boot.bin bs=512 count=2880 2>/dev/null

# Escreve Stage1 no primeiro setor
dd if=stage1.bin of=boot.bin bs=512 count=1 conv=notrunc 2>/dev/null

# Escreve Stage2 começando no setor 2 (offset 512 bytes)
dd if=stage2.bin of=boot.bin bs=512 seek=1 conv=notrunc 2>/dev/null

TOTAL=$(stat -c%s boot.bin 2>/dev/null || stat -f%z boot.bin 2>/dev/null)
echo "   Disk image: $TOTAL bytes (1.44MB floppy)"

echo ""
echo "=== Build Complete ==="
echo "Bootable image: boot.bin"
echo "Stage1 (sector 0): 512 bytes"
echo "Stage2 (sector 1+): $SIZE2 bytes ($SECTORS sectors)"
echo ""
echo "To test with QEMU:"
echo "  qemu-system-x86_64 -drive format=raw,file=boot.bin"
echo ""
echo "To test with QEMU (alternative):"
echo "  qemu-system-i386 -fda boot.bin"