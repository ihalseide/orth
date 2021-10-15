ARMGNU=arm-none-eabi
AS=$(ARMGNU)-as
LD=$(ARMGNU)-ld
OBJCOPY=$(ARMGNU)-objcopy
OBJDUMP=$(ARMGNU)-objdump

build: kernel7.img kernel.list

emulate: kernel.img
	qemu-system-arm -m 256 -M raspi2 -serial stdio -kernel kernel.elf -no-reboot -no-shutdown -S -s &
	gdb-multiarch -x gdbconfig

kernel.list: kernel.elf
	$(OBJDUMP) -d kernel.elf > kernel.list

kernel7.img: kernel.elf
	$(OBJCOPY) kernel.elf -O binary kernel7.img

kernel.elf: kernel.o linkerscript.ld
	$(LD) --no-undefined -T linkerscript.ld -Map kernel.map -o kernel.elf kernel.o

kernel.o: kernel.s
	$(AS) -o kernel.o kernel.s

