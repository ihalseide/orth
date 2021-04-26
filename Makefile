build: core

debug: core
	gdb core

run: core
	./core

interpret: core
	cat orth.os sums.os - | ./core

core: core.o
	ld -o core core.o -M > core.map

core.o: core.s
	as -g -o core.o core.s -al > core.list

