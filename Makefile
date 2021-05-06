build: core

debug: core
	gdb core

interpret: core
	cat orth.os - | ./core

core: core.o
	ld -o core core.o

core.o: source.s core.s
	as -g -o core.o core.s

source.s: source.os
	python3 asm_string.py source.os -o source.s

