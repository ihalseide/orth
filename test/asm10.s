.data
.balign 4
myvar1:
	.word 3
.balign 4
myvar2:
	.word 4

.text
.balign 4
.global _start
_start:
	ldr r1, addr_myvar1
	ldr r1, [r1]
	ldr r2, addr_myvar2
	ldr r2, [r2]
	add r0, r1, r2
	mov r7, #1
	swi 0

addr_myvar1: .word myvar1
addr_myvar2: .word myvar2
