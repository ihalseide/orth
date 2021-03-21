
run: clean all
	./forth

forth: forth.o
	ld forth.o -o forth
	
forth.o: forth2.s
	as forth1.s -o forth.o

forth2.s:
	python3 escape.py forth2.fs > forth2.s

clean:
	rm forth2.s
	rm forth.o
	rm forth
