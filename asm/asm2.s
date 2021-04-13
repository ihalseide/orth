.text
.global _start
_start:
/* The number 265 is not allowed because it is bigger than a BYTE */
	MOV R0, #265
	MOV R7, #1
SWI 0
