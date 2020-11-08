femtoforth: femto_forth_2.s
	gcc -nostdlib -static -Wl,--build-id=none -o bin/femtoforth femto_forth_2.s
	./crunch_std.py

test:
	cat std.crunch.fth tst.fth | ./bin/femtoforth

run:
	cat std.cruch.fth - | ./bin/femtoforth

