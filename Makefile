LD=arm-none-eabi-ld
AS=arm-none-eabi-as

build: main

debug: main
	gdb bin/main

main: main.o
	$(LD) -o bin/main bin/main.o

main.o: main.s bin
	$(AS) -o bin/main.o main.s

bin:
	mkdir bin

