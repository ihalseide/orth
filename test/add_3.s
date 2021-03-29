
	.global _start
_start:
	mov r0, #1
	mov r1, #2
	add r0, r1, #3

	mov r7, #1
	swi #0

