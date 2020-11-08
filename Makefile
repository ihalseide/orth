femtoforth: femto_forth_2.s
	gcc -nostdlib -static -Wl,--build-id=none -o bin/femtoforth femto_forth_2.s

test:
	cat std.fth tst.fth | ./bin/femtoforth

run:
	cat std.fth - | ./bin/femtoforth

