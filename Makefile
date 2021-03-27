BINS=program

run: build
	./program

debug: build
	gdb program

build: $(BINS)

%: %.o
	ld -g -o $@ $^
	
%.o: %.s
	as -adhlns="$@.lst" -g -o $@.o $^

clean:
	rm -f *.o
