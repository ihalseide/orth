
run: build
	./core

debug: build
	gdb core

build: core

core: core.o
	ld -g -o $@ $<
	
core.o: core.s
	as -adhlns="$@.lst" -g -o $@ $<

