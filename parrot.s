
	.set stdin, 0
	.set stdout, 1
	.set stderr, 2

	.text

	.global _start
_start:
	bl accept
	bl print
	mov r0, #0
	mov r7, #1
	swi #0

accept:
	ldr r4, =lr_backup
	str lr, [r4]

	mov r0, #stdin
	ldr r1, =buffer
	mov r2, #256
	mov r7, #3
	swi #0

	ldr r5, =buffer_len
	str r0, [r5]

	ldr lr, [r4]
	bx lr

print:
	ldr r4, =lr_backup
	str lr, [r4]

	mov r0, #stdout
	ldr r1, =buffer
	ldr r2, =buffer_len
	ldr r2, [r2]
	mov r7, #4
	swi #0

	ldr lr, [r4]
	bx lr

	.data

buffer_len:
	.word 0

buffer:
	.space 256

lr_backup:
	.word 0

