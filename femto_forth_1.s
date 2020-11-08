/* Forth implementation.
 * On ARMv7 architecture.
 * In assembly.
 * Called "FemtoForth".
 * by Izak Nathanael Halseide
 */

/* Begin macros. */

	/* The NEXT macro completes the current forth word and moves on to the next one. */
	.macro NEXT
	ldr r0, [r11]
	add r11, #4
	ldr pc, [r0]
	.endm

	/* The PUSH_RSP macro:
     * Stores the current Forth word currently in R11 into
	 * the position pointed to by the Return Stack Pointer, which is R10
	 */
	.macro PUSH_RSP
	stmdb r10!, {r11}
	.endm

	/* The POP_RSP macro: retrieves the top of the Return Stack into R11. */
	.macro POP_RSP
	ldmia r10!, {r11}
	.endm

/* End of macros. */

/* Begin immediate values. */

	/* These constants are used for setting flags on special words */
	.set F_IMMED, 0x80
	.set F_HIDDEN, 0x20
	.set F_LENMASK, 0x1f

/* End immediate values. */

	/* Branch to the entry point */
	b main

	/* DOCOL: The Forth word interpreter, which expects the codeword address to be in R0 */
DOCOL:
	PUSH_RSP
	ADD R0, #4
	MOV R11, R0
	NEXT

/* Begin Forth word definitions. */

name_DROP:
	.word 0
	.byte 4
	.ascii "DROP"
	.align
DROP:
	.word code_DROP
code_DROP:
	add sp, sp, #4
	NEXT

name_SWAP:
	.word name_DROP
	.byte 4
	.ascii "SWAP"
	.align
SWAP:
	.word code_SWAP
code_SWAP:
	pop {r0, r1}
	push {r0}
	push {r1}
	NEXT

name_DUPLICATE:
	.word name_SWAP
	.byte 9
	.ascii "DUPLICATE"
	.align
DUPLICATE:
	.word code_DUPLICATE
code_DUPLICATE:
	ldr r0, [sp]
	push {r0}
	NEXT

name_OVER:
	.word name_DUPLICATE
	.byte 4
	.ascii "OVER"
	.align
OVER:
	.word code_OVER
code_OVER:
	ldr r0, [sp, #4]
	push {r0}
	NEXT

name_ROTATE:
	.word name_OVER
	.byte 6
	.ascii "ROTATE"
	.align
ROTATE:
	.word code_ROTATE
code_ROTATE:
	pop {r0, r1, r2}
	push {r0}
	push {r1, r2}
	NEXT

name_DROP_TWO:
	.word name_ROTATE
	.byte 5
	.ascii "DROP2"
	.align
DROP_TWO:
	.word code_DROP_TWO
code_DROP_TWO:
	add sp, sp, #8
	NEXT

name_DUPLICATE_TWO:
	.word name_DROP_TWO
	.byte 10
	.ascii "DUPLICATE2"
	.align
DUPLICATE_TWO:
	.word code_DUPLICATE_TWO
code_DUPLICATE_TWO:
	ldr r0, [sp]
	ldr r1, [sp,#4]
	push {r0, r1}
	NEXT

name_SWAP_TWO:
	.word name_DUPLICATE_TWO
	.byte 5
	.ascii "SWAP2"
	.align
SWAP_TWO:
	.word code_SWAP_TWO
code_SWAP_TWO:
	pop {r0, r1, r2, r3}
	push {r0, r1}
	push {r2, r3}
	NEXT

name_OVER_TWO:
	.word name_SWAP_TWO
	.byte 5
	.ascii "OVER2"
	.align
OVER_TWO:
	.word code_OVER_TWO
code_OVER_TWO:
	ldr r0, [sp, #8]
	ldr r1, [sp, #12]
	push {r0, r1}
	NEXT

name_Q_DUPLICATE:
	.word name_OVER_TWO
	.byte 10
	.ascii "?DUPLICATE"
	.align
Q_DUPLICATE:
	.word code_Q_DUPLICATE
code_Q_DUPLICATE:
	ldr r0, [sp]
	cmp r0, #0
	pushne {r0}
	NEXT

name_INCREMENT:
	.word name_Q_DUPLICATE
	.byte 2
	.ascii "1+"
	.align
INCREMENT:
	.word code_INCREMENT
code_INCREMENT:
	pop {r0}
	add r0, r0, #1
	push {r0}
	NEXT

name_DECREMENT:
	.word name_INCREMENT
	.byte 2
	.ascii "1-"
	.align
DECREMENT:
	.word code_DECREMENT
code_DECREMENT:
	pop {r0}
	sub r0, r0, #1
	push {r0}
	NEXT

name_ADD:
	.word name_DECREMENT
	.byte 1
	.ascii "+"
	.align
ADD:
	.word code_ADD
code_ADD:
	pop {r0, r1}
	add r0, r0, r1
	push {r0}
	NEXT

name_NEGATE:
	.word name_ADD
	.byte 6
	.ascii "NEGATE"
	.align
NEGATE:
	.word code_NEGATE
code_NEGATE:
	POP {R0}
	MOV R1, #0
	SUB R0, R1, R0
	PUSH {R0}
	NEXT
	
name_SUBTRACT:
	.word name_NEGATE
	.byte 1
	.ascii "-"
	.align
SUBTRACT:
	.word code_SUBTRACT
code_SUBTRACT:
	pop {r0, r1}
	sub r0, r1, r0
	push {r0}
	NEXT

name_MULTIPLY:
	.word name_SUBTRACT
	.byte 1
	.ascii "*"
	.align
MULTIPLY:
	.word code_MULTIPLY
code_MULTIPLY:
	pop {r0, r1}
	mul r2, r0, r1
	push {r2}
	NEXT

name_DIVIDE:
	.word name_MULTIPLY
	.byte 1
	.ascii "/"
	.align
DIVIDE:
	.word code_DIVIDE
code_DIVIDE:
	pop {r1} /* denominator */
	pop {r2} /* numerator */
	cmp r2, #0
	beq DIVIDE_by_zero
	sdiv r0, r2, r1
	NEXT
DIVIDE_by_zero:
	mov r0, #0
	push {r0}
	NEXT

/* Unsigned division */
name_U_DIVIDE:
	.word name_DIVIDE
	.byte 2
	.ascii "U/"
	.align
U_DIVIDE:
	.word code_U_DIVIDE
code_U_DIVIDE:
	pop {r1} /* denominator */
	pop {r2} /* numerator */
	cmp r2, #0
	beq U_DIVIDE_by_zero
	udiv r0, r2, r1
	NEXT
U_DIVIDE_by_zero:
	mov r0, #0
	push {r0}
	NEXT

name_EQUAL:
	.word name_U_DIVIDE
	.byte 1
	.ascii "="
	.align
EQUAL:
	.word code_EQUAL
code_EQUAL:
	pop {r0, r1}
	mov r2, #0
	cmp r0, r1
	subeq r2, r2, #1
	push {r2}
	NEXT

name_NOT_EQUAL:
	.word name_EQUAL
	.byte 2
	.ascii "!="
	.align
NOT_EQUAL:
	.word code_NOT_EQUAL
code_NOT_EQUAL:
	pop {r0, r1}
	mov r2, #0
	cmp r0, r1
	subne r2, r2, #1
	push {r2}
	NEXT
	
name_GREATER:
	.word name_NOT_EQUAL
	.byte 1
	.ascii "<"
	.align
GREATER:
	.word code_GREATER
code_GREATER:
	pop {r0, r1}
	mov r2, #0
	cmp r1, r0
	subgt r2, r2, #1
	push {r2}
	NEXT

name_GREATER_EQUAL:
	.word name_GREATER
	.byte 2
	.ascii "<="
	.align
GREATER_EQUAL:
	.word code_GREATER_EQUAL
code_GREATER_EQUAL:
	pop {r0, r1}
	mov r2, #0
	cmp r1, r0
	subge r2, r2, #1
	push {r2}
	NEXT

name_SMALLER:
	.word name_GREATER_EQUAL
	.byte 1
	.ascii "<"
	.align
SMALLER:
	.word code_SMALLER
code_SMALLER:
	pop {r0, r1}
	mov r2, #0
	cmp r1, r0
	sublt r2, r2, #1
	push {r2}
	NEXT

name_SMALLER_EQUAL:
	.word name_GREATER
	.byte 2
	.ascii ">="
	.align
SMALLER_EQUAL:
	.word code_SMALLER_EQUAL
code_SMALLER_EQUAL:
	pop {r0, r1}
	mov r2, #0
	cmp r1, r0
	suble r2, r2, #1
	push {r2}
	NEXT
	
name_ZERO_EQUAL:
	.word name_SMALLER_EQUAL
	.byte 2
	.ascii "0="
	.align
ZERO_EQUAL:
	.word code_ZERO_EQUAL
code_ZERO_EQUAL:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	subeq r1, r1, #1
	push {r1}
	NEXT

name_ZERO_NOT:
	.word name_ZERO_EQUAL
	.byte 3
	.ascii "0!="
	.align
ZERO_NOT:
	.word code_ZERO_NOT
code_ZERO_NOT:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	subne r1, r1, #1
	push {r1}
	NEXT

name_ZERO_GREATER:
	.word name_ZERO_NOT
	.byte 2
	.ascii "0<"
	.align
ZERO_GREATER:
	.word code_ZERO_GREATER
code_ZERO_GREATER:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	subgt r1, r1, #1
	push {r1}
	NEXT

name_ZERO_GREATER_EQUAL:
	.word name_ZERO_GREATER
	.byte 3
	.ascii "0<="
	.align
ZERO_GREATER_EQUAL:
	.word code_ZERO_GREATER_EQUAL
code_ZERO_GREATER_EQUAL:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	subge r1, r1, #1
	push {r1}
	NEXT

name_ZERO_SMALLER:
	.word name_ZERO_GREATER_EQUAL
	.byte 2
	.ascii "0>"
	.align
ZERO_SMALLER:
	.word code_ZERO_SMALLER
code_ZERO_SMALLER:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	sublt r1, r1, #1
	push {r1}
	NEXT

name_ZERO_SMALLER_EQUAL:
	.word name_ZERO_SMALLER
	.byte 3
	.ascii "0>="
	.align
ZERO_SMALLER_EQUAL:
	.word code_ZERO_SMALLER_EQUAL
code_ZERO_SMALLER_EQUAL:
	pop {r0}
	mov r1, #0
	cmp r0, #0
	suble r1, r1, #1
	push {r1}
	NEXT

name_AND:
	.word name_ZERO_SMALLER_EQUAL
	.byte 1
	.ascii "&"
	.align
AND:
	.word code_AND
code_AND:
	pop {r0, r1}
	and r0, r0, r1
	push {r0}
	NEXT

name_OR:
	.word name_AND
	.byte 1
	.ascii "|"
	.align
OR:
	.word code_OR
code_OR:
	pop {r0, r1}
	orr r0, r0, r1
	push {r0}
	NEXT

name_XOR:
	.word name_OR
	.byte 1
	.ascii "^"
	.align
XOR:
	.word code_XOR
code_XOR:
	pop {r0, r1}
	eor r0, r0, r1
	push {r0}
	NEXT

name_INVERT:
	.word name_XOR
	.byte 1
	.ascii "~"
	.align
INVERT:
	.word code_INVERT
code_INVERT:
	pop {r0}
	mvn r1, #0
	eor r0, r0, r1
	push {r0}
	NEXT	

name_L_SHIFT_LEFT:
	.word name_INVERT
	.byte 6
	.ascii "LSHIFT"
	.align
L_SHIFT_LEFT:
	.word code_L_SHIFT_LEFT
code_L_SHIFT_LEFT:
	POP {R0, R1}
	LSL R0, R1, R0
	PUSH {R0}
	NEXT

name_L_SHIFT_RIGHT:
	.word name_L_SHIFT_LEFT
	.byte 6
	.ascii "RSHIFT"
	.align
L_SHIFT_RIGHT:
	.word code_L_SHIFT_RIGHT
code_L_SHIFT_RIGHT:
	POP {R0, R1}
	LSR R0, R1, R0
	PUSH {R0}
	NEXT

name_A_SHIFT_RIGHT:
	.word name_L_SHIFT_LEFT
	.byte 7
	.ascii "ARSHIFT"
	.align
A_SHIFT_RIGHT:
	.word code_A_SHIFT_RIGHT
code_A_SHIFT_RIGHT:
	POP {R0, R1}
	ASR R0, R1, R0
	PUSH {R0}
	NEXT

name_EXIT:
	.word name_A_SHIFT_RIGHT
	.byte 4
	.ascii "EXIT"
	.align
EXIT:
	.word code_EXIT
code_EXIT:
	POP_RSP
	NEXT

name_LITERAL:
	.word name_EXIT
	.byte 7
	.ascii "LITERAL"
	.align
LITERAL:
	.word code_LITERAL
code_LITERAL:
	ldr r0, [r11]
	push {r0}
	add r11, r11, #4
	NEXT

name_STORE:
	.word name_LITERAL
	.byte 1
	.ascii "!"
	.align
STORE:
	.word code_STORE
code_STORE:
	pop {r0, r1}
	str r1, [r0]
	NEXT

name_FETCH:
	.word name_STORE
	.byte 1
	.ascii "@"
	.align
FETCH:
	.word code_FETCH
code_FETCH:
	pop {r0}
	ldr r0, [r0]
	push {r0}
	NEXT

name_STORE_BYTE:
	.word name_FETCH
	.byte 2
	.ascii "C!"
	.align
STORE_BYTE:
	.word code_STORE_BYTE
code_STORE_BYTE:
	pop {r0, r1}
	strb r1, [r0]
	NEXT

name_FETCH_BYTE:
	.word name_STORE_BYTE
	.byte 2 
	.ascii "C@"
	.align
FETCH_BYTE:
	.word code_FETCH_BYTE
code_FETCH_BYTE:
	pop {r0}
	mov r1, #0
	ldrb r1, [r0]
	push {r1}
	NEXT

name_STATE:
	.word name_FETCH_BYTE
	.byte 5
	.ascii "STATE"
	.align
STATE:
	.word code_STATE
code_STATE:
	ldr r0, =var_STATE
	push {r0}
	NEXT

name_LATEST:
	.word name_STATE
	.byte 6
	.ascii "LATEST"
	.align
LATEST:
	.word code_LATEST
code_LATEST:
	ldr r0, =var_LATEST
	push {r0}
	NEXT

name_HERE:
	.word name_LATEST
	.byte 4
	.ascii "HERE"
	.align
HERE:
	.word code_HERE
code_HERE:
	ldr r0, =var_HERE
	push {r0}
	NEXT

name_S0:
	.word name_HERE
	.byte 2
	.ascii "S0"
	.align
S0:
	.word code_S0
code_S0:
	ldr r0, =var_S0
	push {r0}
	NEXT

name_BASE:
	.word name_S0
	.byte 4
	.ascii "BASE"
	.align
BASE:
	.word code_BASE
code_BASE:
	ldr r0, =var_BASE
	push {r0}
	NEXT

name_VERSION:
	.word name_BASE
	.byte 7
	.ascii "VERSION"
	.align
VERSION:
	.word code_VERSION
code_VERSION:
	mov r0, #1
	push {r0}
	NEXT

name_R0:
	.word name_BASE
	.byte 2
	.ascii "R0"
	.align
R0:
	.word code_R0
code_R0:
	ldr r0, =return_stack_top
	ldr r0, [r0]
	push {r0}
	NEXT

name_DOCOL:
	.word name_R0
	.byte 5
	.ascii "DOCOL"
	.align
__DOCOL:
	.word code_DOCOL
code_DOCOL:
	ldr r0, =DOCOL
	push {r0}
	NEXT

name_FLAG_IMM:
	.word name_DOCOL
	.byte 7
	.ascii "F_IMMED"
	.align
FLAG_IMM:
	.word code_FLAG_IMM
code_FLAG_IMM:
	mov r0, #F_IMMED
	push {r0}
	NEXT

name_FLAG_HID:
	.word name_FLAG_IMM
	.byte 8
	.ascii "F_HIDDEN"
	.align
FLAG_HID:
	.word code_FLAG_HID
code_FLAG_HID:
	mov r0, #F_HIDDEN
	push {r0}
	NEXT

name_FLAG_MSK:
	.word name_FLAG_HID
	.byte 9
	.ascii "F_LENMASK"
	.align
FLAG_MSK:
	.word code_FLAG_MSK
code_FLAG_MSK:
	mov r0, #F_LENMASK
	push {r0}
	NEXT

name_HIDDEN:
	.word name_DOCOL
HIDDEN:
	.word code_HIDDEN
code_HIDDEN:
	NEXT

name_HIDE:
	.word name_HIDDEN
HIDE:
	.word code_HIDE
code_HIDE:
	NEXT

name_TO_R:
	.word name_HIDE
	.byte 2
	.ascii ">R"
	.align
TO_R:
	.word code_TO_R
code_TO_R:
	MOV R0, R11
	POP {R11}
	PUSH_RSP
	MOV R11, R0
	NEXT

name_FROM_R:
	.word name_TO_R
	.byte 2
	.ascii "R>"
	.align
FROM_R:
	.word code_FROM_R
code_FROM_R:
	MOV R0, R11
	POP_RSP
	PUSH {R11}
	MOV R11, R0
	NEXT

name_RSP_FETCH:
	.word name_FROM_R
	.byte 4
	.ascii "RSP@"
	.align
RSP_FETCH:
	.word code_RSP_FETCH
code_RSP_FETCH:
	PUSH {R10}
	NEXT

name_RSP_STORE:
	.word name_RSP_FETCH
	.byte 4
	.ascii "RSP!"
	.align
RSP_STORE:
	.word code_RSP_STORE
code_RSP_STORE:
	POP {R10}
	NEXT

name_R_DROP:
	.word name_RSP_STORE
	.byte 5
	.ascii "RDROP"
	.align
R_DROP:
	.word code_R_DROP
code_R_DROP:
	ADD R10, R10, #4
	NEXT

name_DSP_FETCH:
	.word name_R_DROP
	.byte 4
	.ascii "DSP@"
	.align
DSP_FETCH:
	.word code_DSP_FETCH
code_DSP_FETCH:
	MOV R0, sp
	PUSH {R0}
	NEXT

name_DSP_STORE:
	.word name_DSP_FETCH
	.byte 4
	.ascii "DSP!"
	.align
DSP_STORE:
	.word code_DSP_STORE
code_DSP_STORE:
	POP {R0}
	MOV sp, R0
	NEXT

/* Begin Forth I/O words */

name_KEY:
	.word name_DSP_STORE
	.byte 3
	.ascii "KEY"
	.align
KEY:
code_KEY:
	NEXT

name_EMIT:
	.word name_KEY
	.byte 4
	.ascii "EMIT"
	.align
EMIT:
code_EMIT:
	NEXT

name_WORD:
	.word name_EMIT
	.byte 4
	.ascii "WORD"
	.align
WORD:
code_WORD:
	NEXT

name_NUMBER:
	.word name_WORD
	.byte 6
	.ascii "NUMBER"
	.align
NUMBER:
code_NUMBER:
	NEXT

name_FIND:
	.word name_NUMBER
	.byte 4
	.ascii "FIND"
	.align
FIND:
	.word code_FIND
code_FIND:
	NEXT

/* Begin Forth compilation words. */

name_CREATE:
	.word name_FIND
	.byte 6
	.ascii "CREATE"
	.align
CREATE:
	.word code_CREATE
code_CREATE:
	NEXT

name_COMMA:
	.word name_CREATE
	.byte 1
	.ascii ","
	.align
COMMA:
	.word code_COMMA
code_COMMA:
	pop {R0}
	bl _comma
	NEXT

	/* _comma: Append the content of R0 to HERE and increment HERE */
_comma:
	LDR R3, =var_HERE
	LDR R1, [R3]
	STR R0, [R1]
	ADD R1, R1, #4
	STR R1, [R3]
	/* Return */
	BX lr

name_L_BRACKET:
	.word name_COMMA
	.byte 0x81 /* F_IMMED | 1 */
	.ascii "["
	.align
L_BRACKET:
	.word code_L_BRACKET
code_L_BRACKET:
	LDR R0, =var_STATE
	MOV R1, #0
	STR R1, [R0]
	NEXT	

name_R_BRACKET:
	.word name_L_BRACKET
	.byte 1
	.ascii "]"
	.align
R_BRACKET:
	.word code_R_BRACKET
code_R_BRACKET:
	LDR R0, =var_STATE
	MOV R1, #1
	STR R1, [R0]
	NEXT

name_COLON:
	.word name_R_BRACKET
	.byte 1
	.ascii ":"
	.align
COLON:
	.word code_COLON
code_COLON:

name_SEMICOLON:
	.word name_COLON
	.byte 1
	.ascii ";"
	.align
SEMICOLON:
	.word code_SEMICOLON
code_SEMICOLON:
	NEXT

name_IMMEDIATE:
	.word name_SEMICOLON
	.byte 9
	.ascii "IMMEDIATE"
	.align
IMMEDIATE:
	.word code_IMMEDIATE
code_IMMEDIATE:
	NEXT

name_TICK:
	.word name_IMMEDIATE
	.byte 1
	.ascii "`"
	.align
TICK:
	.word code_TICK
code_TICK:
	NEXT

name_BRANCH:
	.word name_TICK
	.byte 6
	.ascii "BRANCH"
	.align
BRANCH:
	.word code_BRANCH
code_BRANCH:
	NEXT

name_ZERO_BRANCH:
	.word name_BRANCH
	.byte 7
	.ascii "0BRANCH"
	.align
ZERO_BRANCH:
	.word code_ZERO_BRANCH
code_ZERO_BRANCH:
	NEXT

name_QUIT:
	.word name_ZERO_BRANCH
	.byte 4
	.ascii "QUIT"
	.align
QUIT:
	.word code_QUIT
code_QUIT:
	NEXT

name_INTERPRET:
	.word name_QUIT
	.byte 9
	.ascii "INTERPRET"
	.align
INTERPRET:
	.word code_INTERPRET
code_INTERPRET:
	NEXT

/* End definitions of Forth compilation words. */

	/* This is the main entry point. */ 
	.globl main
main:
	LDR R0, =QUIT
	LDR R11, =cold_start
	NEXT

	/* Cold start starts the interpretter with "QUIT" */
cold_start:
	.word QUIT

/* Begin the main data section. */ 

	.data

version_message:
	.ascii "FemtoForth version 0.0.1"
version_message_len:
	.word 24

var_STATE:
	.word 0
var_LATEST:
	.word 0
var_HERE:
	.word 0
var_S0:
	.word 0
var_R0:
	.word 0
var_BASE:
	.word 10
return_stack_top:
	.word 0

	.end
