.global _start

_start:
	MOV R7, #3 @ System call for keyboard
	MOV R0, #0 @ - input stream from keyboard
	MOV R2, #1 @ - Read 1 char
	LDR R1, =character
	SWI 0

_upper:
	LDR R1, =character
	LDR R0, [R1]

	BIC R0, R0, #32
	
	STR R0, [R1]

_write:
	MOV R7, #4 @ System call to output to screen
	MOV R0, #1
	MOV R2, #1
	LDR R1, =character
	SWI 0

end:
	MOV R7, #1
	SWI 0

.data
character:
	.ascii " "
