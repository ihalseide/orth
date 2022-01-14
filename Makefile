# Should be configured for preferred directory
BUILDPATH=build

TOOLS=arm-none-eabi
AS=$(TOOLS)-as
LD=$(TOOLS)-ld
OBJCOPY=$(TOOLS)-objcopy
OBJDUMP=$(TOOLS)-objdump

build: kernel7.img system.list

emulate: build
	qemu-system-arm -m 256 -M raspi2 -serial stdio -kernel "$(BUILDPATH)/kernel7.img" -no-reboot -no-shutdown -S -s &
	gdb-multiarch -x gdbconfig

system.list: system.elf
	$(OBJDUMP) -d $(BUILDPATH)/system.elf > $(BUILDPATH)/system.list

kernel7.img: system.elf
	$(OBJCOPY) $(BUILDPATH)/system.elf -O binary $(BUILDPATH)/kernel7.img

system.elf: system.o linkerscript.ld
	$(LD) -g --no-undefined -T linkerscript.ld -Map $(BUILDPATH)/system.map -o $(BUILDPATH)/system.elf $(BUILDPATH)/system.o

system.o: system.s
	$(AS) -g -o $(BUILDPATH)/system.o system.s

