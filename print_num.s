
	.set stdout, 1
	.set os_write, 4

	.global _start
_start:
	mov r4, #0
loop:
	mov r0, r4
	bl print_digit
	cmp r4, #16
	add r4, #1
	bne loop

	mov r7, #1
	swi #0

// [number] -> [number of character written]
print_unum:
	push {r4-r11, lr}

	mvn r1, #1              // init r2 all ones exept first bit

divide:
	eor r4, r4              // init remainder to zero
	mov r2, #32             // loop counter

div_loop:
	mov r3, r4
	ror r0, #31
	ror r3, #31
	tst r0, #1
	and r3, r1
	and r0, r1
	orrpl r3, #1

	sbc r3, #10
	movcs r4, r3

	sub r2, #1
	cmp r2, #0
	bne div_loop

	bl print_digit

	cmp r3, #0
	bne divide

	pop {r4-r11, lr}
	bx lr


print_digit:
	push {r4-r11, lr}

	ldr r1, =digits
	add r1, r0

	mov r0, #stdout
	mov r2, #1
	mov r7, #os_write
	swi #0

	pop {r4-r11, lr}
	bx lr

digits:
	.ascii "0123456789abcdefghijklmnopqrstuvwxzy"









