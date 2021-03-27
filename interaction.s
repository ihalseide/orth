
	.text
	.global _start
_start:
	bl print_output
	mov r0, #0
	mov r7, #1
	swi #0

accept:
	ldr r4, =lr_backup
	str lr, [r4]
	mov r5, r0
	mov r6, #0
accept_call:
	mov r0, #0
	ldr r1, =input_buf
	add r1, r6
	mov r2, r5
	sub r2, r6
	mov r7, #3
	swi #0
	add r6, r0

	cmp r6, r5
	blt accept_call

	ldr lr, [r4]
	bx lr

print_buffer:
	mov r0, #1
	ldr r1, =input_buf
	mov r2, #256
	mov r7, #4
	swi #0
	bx lr

print_output:
	ldr r4, =lr_backup
	str lr, [r4]

	mov r0, #1
	ldr r1, =output
	mov r2, #11
	mov r7, #4
	swi #0

	ldr lr, [r4]
	bx lr

	.data
input_buf:
	.space 256

output:
	.ascii "Hey yo!\0boy"

lr_backup:
	.word 0

