
	.set stdout, 1
	.set os_write, 4

	.global _start
_start:
	mov r0, #12
	bl print_unum

	mov r7, #1
	swi #0

// [number] -> [number of character written]
print_unum:
	push {r4-r11, lr}

	mvn r1, #1              // init r2 all ones exept first bit
	mov r5, #0

divide:
	eor r4, r4              // init remainder to zero
	mov r2, #32             // loop counter

div_loop:
	mov r3, r4
	ror r0, #31
	ror r3, #31
	and r5, r3, #1
	tst r0, #1
	and r0, r1
	and r3, r1
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
	push {r0, r4-r11, lr}

	cmp r0, #35
	bgt range_err
	cmp r0, #0
	blt range_err

	ldr r1, =digits
	add r1, r0

	mov r0, #stdout
	mov r2, #1
	mov r7, #os_write
	swi #0

	pop {r0, r4-r11, lr}
	bx lr

range_err:
	mov r0, #-1

	pop {r0, r4-r11, lr}
	bx lr
	
digits:
	.ascii "0123456789abcdefghijklmnopqrstuvwxzy"









