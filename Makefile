
build: core

run: core
	./core

debug: core
	gdb core

core: core.x
	mv core.x core

# Executable files end with .x
%.x: %.o
	ld -g -o $@ $<
	
%.o: %.s
	as -adhlns="$@.lst" -g -o $@ $<

