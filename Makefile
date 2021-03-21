
run: all
	./forth

all: forth

forth: forth.o
	ld forth.o -o forth
	
forth.o: forth2.s
	as forth1.s -mbig-endian -o forth.o

forth2.s:
	python3 escape.py forth2.fs > forth2.s

