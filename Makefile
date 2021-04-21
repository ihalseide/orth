build: core

debug: core
	gdb core

run: core
	./core

core: core.o
	ld -o core core.o -M > core.map

core.o: core.s
	as -g -o core.o core.s -as > core.list

