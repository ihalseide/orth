
run: core
	./bin/core

core: core.o
	ld -g -o bin/core bin/core.o
	
core.o: core.s
	as -g -o bin/core.o core.s


