
run: bin/forth1
	./bin/forth1

forth1: forth1.o
	ld -g -o bin/forth1 bin/forth1.o
	
forth1.o: forth1.s
	as -g -o bin/forth1.o forth1.s


