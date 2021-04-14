
build: build/myos.elf

build/boot.o: source/boot.s
	arm-none-eabi-gcc -mcpu=cortex-a7 -fpic -ffreestanding -c source/boot.s -o build/boot.o

build/kernel.o: source/kernel.c
	arm-none-eabi-gcc -mcpu=cortex-a7 -fpic -ffreestanding -std=gnu99 -c source/kernel.c -o build/kernel.o -O2 -Wall -Wextra

build/myos.elf: build/boot.o build/kernel.o
	arm-none-eabi-gcc -T source/kernel.ld -o build/myos.elf -ffreestanding -O2 -nostdlib build/boot.o build/kernel.o

