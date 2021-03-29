	.data
label:
	.word label2

label1:
	.word 12

	.text
	.global _start
_start:
	ldr r2, =label1
	//ldr r1, [r2]
	ldr r0, [r2]
quit:
	mov r7, #1
	swi #0

label2:
	.word 42
