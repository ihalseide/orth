/* <instruction> <destination>, <operand>, <operand...> */

.global _start

_start:
	MOV R1, #0xA
	ADD R0, R1, #0x14
	MOV R7, #1
	SWI 0

