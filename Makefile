ff: femtoforth.s
	gcc -nostdlib -static -Wl,--build-id=none -o femtoforth femtoforth.s

test: ff
	cat asm_test.fs | ./femtoforth

run: ff
	cat femtoforth.fs - | ./femtoforth

