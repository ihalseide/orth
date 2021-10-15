ARMGNU=arm-none-eabi
AS=$(ARMGNU)-as
LD=$(ARMGNU)-ld
OBJCOPY=$(ARMGNU)-objcopy
OBJDUMP=$(ARMGNU)-objdump

build: kernel7.img system.list

emulate: kernel7.img
	qemu-system-arm -m 256 -M raspi2 -serial stdio -kernel kernel7.elf -no-reboot -no-shutdown -S -s &
	gdb-multiarch -x gdbconfig

system.list: system.elf
	$(OBJDUMP) -d system.elf > system.list

kernel7.img: system.elf
	$(OBJCOPY) system.elf -O binary kernel7.img

system.elf: system.o linkerscript.ld
	$(LD) --no-undefined -T linkerscript.ld -Map system.map -o system.elf system.o

system.o: system.s
	$(AS) -o system.o system.s

