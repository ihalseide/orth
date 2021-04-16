.global _start

_start:
	MOV R0, #0xA
/* branch to "other", which ends the program */
	B other
	MOV R0, #0xB

other:
	MOV R7, #1
	SWI 0

