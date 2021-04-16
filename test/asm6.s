/* <instruction> <destination>, <operand>, <operand...> 
multiplication requires use of registers, not constants (unlike adding and subtracting)*/

.global _start

_start:
	MOV R1, #0xA
	MOV R2, #0xA
	MUL R0, R1, R2
	MOV R7, #1
	SWI 0

