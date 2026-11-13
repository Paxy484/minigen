AS      = m68k-linux-gnu-as
LD      = m68k-linux-gnu-ld
OBJCOPY = m68k-linux-gnu-objcopy

all: minigen.bin

minigen.bin: minigen.s
	$(AS) -m68000 minigen.s -o minigen.o
	$(LD) -Ttext=0x00000000 minigen.o -o minigen.elf
	$(OBJCOPY) -O binary minigen.elf minigen.bin

clean:
	rm -f minigen.o minigen.elf minigen.bin