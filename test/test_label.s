	.data
label:
	.word label2

	.text
	.global _start
_start:
	ldr r2, =label
	ldr r1, [r2]
	ldr r0, [r1]
quit:
	mov r7, #1
	swi #0

label2:
	.word 42
