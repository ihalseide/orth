
	.set F_IMMEDIATE, 0b10000000
	.set F_HIDDEN,    0b01000000
	.set F_LENMASK,   0b00111111    

	.global _start
_start:
	mov r0, #0

	ldr r2, =value
	ldr r2, [r2]
	tst r2, #F_HIDDEN
	beq end

	mov r0, #1

end:
	mov r7, #1
	swi #0

value:
	.word 0b00001001

