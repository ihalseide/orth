ARMGNU=arm-none-eabi
AS=$(ARMGNU)-as
LD=$(ARMGNU)-ld
OBJCOPY=$(ARMGNU)-objcopy
OBJDUMP=$(ARMGNU)-objdump
BUILDPATH=build

build: builddir kernel7.img system.list

builddir:
	mkdir -p -v $(BUILDPATH)

emulate: kernel7.img
	qemu-system-arm -m 256 -M raspi2 -serial stdio -kernel $(BUILDPATH)/kernel7.elf -no-reboot -no-shutdown -S -s &
	gdb-multiarch -x gdbconfig

system.list: system.elf
	$(OBJDUMP) -d $(BUILDPATH)/system.elf > $(BUILDPATH)/system.list

kernel7.img: system.elf
	$(OBJCOPY) $(BUILDPATH)/system.elf -O binary $(BUILDPATH)/kernel7.img

system.elf: system.o linkerscript.ld
	$(LD) --no-undefined -T linkerscript.ld -Map $(BUILDPATH)/system.map -o $(BUILDPATH)/system.elf $(BUILDPATH)/system.o

system.o: system.s
	$(AS) -o $(BUILDPATH)/system.o system.s

