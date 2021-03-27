build: program

run: build
	./program

debug: build
	gdb program

program: core.o
	ld -g -o program core.o
	
core.o: core.s
	as -adhlns="$@.lst" -g -o core.o core.s

clean:
	~/del.sh core.o core.o.lst program 

