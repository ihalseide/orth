
build: core

run: core
	./core

debug: core
	gdb core

core: core.o
	ld -g -o $@ $<
	
core.o: core.s
	as -adhlns="$@.lst" -g -o $@ $<

