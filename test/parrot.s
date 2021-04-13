
	.set os_exit, 1
	.set os_read, 3
	.set os_write, 4

	.set stdin, 0
	.set stdout, 1
	.set stderr, 2

	.set IO_BUF_SIZE, 1024
	.set STACK_SIZE, 256

	.text

	.global _start
_start:
	ldr sp, =stack

	bl accept
	bl print

	mov r0, #0
	mov r7, #os_exit
	swi #0

accept:
	push {lr}

	mov r0, #5
	bl accept_n

	pop {lr}
	bx lr

print:
	push {lr}

	ldr r0, =io_buf_len
	ldr r0, [r0]
	bl print_n

	pop {lr}
	bx lr

accept_n:
	push {lr}

	mov r2, r0

	mov r0, #stdin
	ldr r1, =io_buf
	mov r7, #os_read
	swi #0

	ldr r5, =io_buf_len
	str r0, [r5]

	pop {lr}
	bx lr

print_n:
	push {lr}

	mov r2, r0

	mov r0, #stdout
	ldr r1, =io_buf
	mov r7, #os_write
	swi #0

	pop {lr}
	bx lr

	.data

	.space STACK_SIZE
stack:

io_buf_len:
	.word 0

io_buf:
	.space IO_BUF_SIZE

