femtoforth: crunch
	gcc -nostdlib -static -Wl,--build-id=none -o bin/femtoforth femto_forth.s

test:
	cat std.crunch.fth tst.fth | ./bin/femtoforth

crunch:
	./crunch_std.py

run: femtoforth
	cat std.crunch.fth - | ./bin/femtoforth

clean:
	rm bin/*
	rm std.crunch.fth
