
	.text
	.global _start
_start:
	mov r0, #1
	ldr r1, =msg
	mov r2, #msg_end-msg
	mov r7, #4
	swi #0

	mov r0, #0
	mov r7, #1
	swi #0

	.data
msg:
	.ascii "Hello, world!\n"
msg_end:

