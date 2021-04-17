build: core

debug: core
	gdb core

run: core
	./core

core: core.o
	ld -g -o core core.o

core.o: core.s
	as -g -o core.o core.s

