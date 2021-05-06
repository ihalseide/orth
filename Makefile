build: core

debug: core
	gdb core

interpret: core
	cat orth.os - | ./core

core: core.o
	ld -o core core.o

core.o: core.s
	as -g -o core.o core.s

