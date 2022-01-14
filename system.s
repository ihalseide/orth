	.equ SYSTIMERCLO, 0x3F003004

	.equ BCM_PERI_BASE, 0x3F000000
	.equ BCM_GPIO_BASE, 0x3F200000
	.equ GPU_MAIL_BASE, 0x3F00B880 // replaced 0x20... with 0x3F...

	.equ GPFSEL3, 0x3F20000C
	.equ GPFSEL4, 0x3F200010
	.equ GPSET1, 0x3F200020
	.equ GPCLR1, 0x3F20002C

	.section .data
	.align 4
	// Screen frame buffer
	.global FrameBufferInfo
FrameBufferInfo:
	.int 1024 // #0 Physical Width
	.int 768 // #4 Physical Height
	.int 1024 // #8 Virtual Width
	.int 768 // #12 Virtual Height
	.int 0 // #16 GPU - Pitch
	.int 16 // #20 Bit Depth
	.int 0 // #24 X
	.int 0 // #28 Y
	.int 0 // #32 GPU - Pointer
	.int 0 // #36 GPU - Size

	.section .init
	.align 2
	.global _start
_start:
	// Shut off extra cores
	//mrc p15, 0, r5, c0, c0, 5
	//and r5, r5, #3
	//cmp r5, #0
	//bne halt

	// Init stack
	mov sp, #0x8000
	b main

hang:
	wfe
	b hang

	.section .text
	.align 2
main:
	ldr r0, =GPFSEL4
	mov r1, #7
	lsl r1, #21
	mvn r1, r1
	and r1, r0, r1
	orr r1, #1
	lsl r1, #21
	str r1, [r0]

	ldr r0, =GPFSEL3
	mov r1, #7
	lsl r1, #15
	mvn r1, r1
	and r1, r0, r1
	orr r1, #1
	lsl r1, #15
	str r1, [r0]

loop:
	ldr r0, =GPSET1
	mov r1, #1
	lsl r1, #47-32
	str r1, [r0]

	ldr r0, =GPCLR1
	mov r1, #1
	lsl r1, #35-32
	str r1, [r0]

	bl wait

	ldr r0, =GPCLR1
	mov r1, #1
	lsl r1, #47-32
	str r1, [r0]

	ldr r0, =GPSET1
	mov r1, #1
	lsl r1, #35-32
	str r1, [r0]

	bl wait

	b loop

	// Set led and hang
error:

	mov r5, #5

	mov r0, #16
	mov r1, #1
	bl gpioSetFunction

	mov r0, #16
	mov r1, #0
	bl gpioSet

	b hang

// Wait for some time to pass, proportional to N
// Inputs:
//     r0: N
// Outputs:
//     r0: 0 upon success, N upon error
wait:
	push {lr}

	// Validate input
	cmp r0, #0
	poplt {pc}

	// while n > 0, decrement n
waitBegin$:
	cmp r0, #0
	beq waitEnd$
	sub r0, #1
	b waitBegin$
waitEnd$:

	// r0 is 0
	pop {pc}

	// Initialize screen buffer
	mov r0, #1024
	mov r1, #768
	mov r2, #16
	bl frameBufferInit

	// Test if the screen init was successful
	teq r0, #0
	beq error

	fbInfoAddr .req r4
	mov fbInfoAddr, r0

render$:

	fbAddr .req r3
	ldr fbAddr, [fbInfoAddr, #32]

	color .req r0
	y .req r1
	mov y, #768

drawRow$:

	x .req r2
	mov x, #1024

drawPixel$:

	strh color, [fbAddr]
	add fbAddr, #2
	sub x, #1
	teq x, #0
	bne drawPixel$
	
	sub y, #1
	add color, #1
	teq y, #0
	bne drawRow$

	b render$
	.unreq fbAddr
	.unreq fbInfoAddr
	.unreq x
	.unreq y

mailboxGetBase:
	ldr r0, =GPU_MAIL_BASE
	mov pc, lr

// Write data to mailbox
// Inputs:
//     r0: data
//     r1: mailbox
// Outputs:
//     none
mailboxWrite:
	// Validate inputs
	tst r0, #0b1111
	movne pc, lr
	cmp r1, #15
	movhi pc, lr

	channel .req r1
	value .req r2
	mov value, r0
	push {lr}
	bl mailboxGetBase
	mailbox .req r0

wait1$:
	// Get current mailbox status
	status .req r3
	ldr status, [mailbox, #0x18]

	tst status, #0x80000000
	.unreq status
	bne wait1$

	add value, channel
	.unreq channel

	// store the result
	str value, [mailbox, #0x20]
	.unreq value
	.unreq mailbox
	pop {pc}

// Read data from mailbox
// Inputs:
//     r0: mailbox to read from
// Outputs:
//     r0: data
mailboxRead:
	// Validate mailbox input
	cmp r0, #15
	movhi pc, lr

	channel .req r1
	mov channel, r0
	push {lr}
	bl mailboxGetBase
	mailbox .req r0
	
rightMail$:
wait2$:
	// get current status
	status .req r2
	ldr status, [mailbox, #0x18]

	// Loop until the 30th bit of status is 0
	tst status, #0x40000000
	.unreq status
	bne wait2$

	// Read mailbox
	mail .req r2
	ldr mail, [mailbox, #0]

	// Check that the channel is the one we want
	inChan .req r3
	and inChan, mail, #0b1111
	teq inChan, channel
	.unreq inChan
	bne rightMail$
	.unreq mailbox
	.unreq channel

	// Return the result
	and r0, mail, #0xfffffff0
	.unreq mail
	pop {pc}

// Initialize the frame buffer used for the GPU
// Inputs:
//     r0: width
//     r1: height
//     r2: bit depth
frameBufferInit:
	width .req r0
	height .req r1
	bitDepth .req r2

	// Validate our inputs: width, height both <= 4096, and bitDepth <= 32
	cmp width, #4096
	cmpls height, #4096
	cmpls bitDepth, #32
	result .req r0
	movhi result, #0
	movhi pc, lr

	// Write the inputs into the frame buffer
	fbufInfoAddr .req r3
	push {lr}
	ldr fbufInfoAddr, =FrameBufferInfo
	str width, [fbufInfoAddr, #0]
	str height, [fbufInfoAddr, #4]
	str width, [fbufInfoAddr, #8]
	str height, [fbufInfoAddr, #12]
	str bitDepth, [fbufInfoAddr, #20]
	.unreq width
	.unreq height
	.unreq bitDepth

	// Send the address of the frame buffer + 0x40000000 to the mailbox
	mov r0, fbufInfoAddr
	add r0, #0x40000000
	mov r1, #1
	bl mailboxWrite

	// Receive the reply from the mailbox
	mov r0, #1
	bl mailboxRead

	// If the reply is not 0, the method has failed. We return 0 to indicate failure
	teq result, #0
	movne result, #0
	popne {pc}

	// Return a pointer to the frame buffer info.
	mov result, fbufInfoAddr
	pop {pc}
	.unreq result
	.unreq fbufInfoAddr

gpioGetAddress:
	ldr r0, =BCM_GPIO_BASE
	mov pc, lr

// ...
gpioSetFunction:
	cmp r0, #53
	cmpls r1, #7
	movhi pc, lr

	push {lr}
	mov r2, r0
	bl gpioGetAddress

funcLoop$:
	cmp r2, #9
	subhi r2, #10
	addhi r0, #4
	bhi funcLoop$

	add r2, r2, lsl #1
	lsl r1, r2
	str r1, [r0]
	pop {pc}

// Set a GPIO value
// Inputs:
//     r0: pin number
//     r1: value to set the pin to
gpioSet:
	pinNum .req r0
	pinVal .req r1

	// Validate input pin
	cmp pinNum, #53
	movhi pc, lr

	mov r2, pinNum
	.unreq pinNum
	pinNum .req r2
	bl gpioGetAddress
	gpioAddr .req r0

	pinBank .req r3
	lsr pinBank, pinNum, #5
	lsl pinBank, #2
	add gpioAddr, pinBank
	.unreq pinBank

	and pinNum, #31
	setBit .req r3
	mov setBit, #1
	lsl setBit, pinNum
	.unreq pinNum

	teq pinVal, #0
	.unreq pinVal
	streq setBit, [gpioAddr, #40]
	strne setBit, [gpioAddr, #28]
	.unreq setBit
	.unreq gpioAddr
	pop {pc}


	// -- old code! --

	// INFO:
	// * R0-R7 = scratch registers
	// * R8 = current execution token (XT)
	// * R9 = top element of the stack
	// * R10 = virtual instruction pointer (IP)
	// * R11 = return stack pointer (RP)
	// * R12 = 
	// * R13 = stack pointer (SP)

	// Constants:

	.equ F_IMMEDIATE, 0b10000000 // immediate word flag bit
	.equ F_HIDDEN, 0b01000000 // hidden word flag bit
	.equ F_COMPILE, 0b00100000 // compile-only word flag bit
	.equ F_LENMASK, 0b00011111 // 31
	.equ TIB_SIZE, 1024          // (bytes) size of terminal input buffer
	.equ TOB_SIZE, 1024          // (bytes) size of terminal output buffer
	.equ RSTACK_SIZE, 512*4      // (bytes) size of the return stack
	.equ STACK_SIZE, 64*4        // (bytes) size of the data stack

	// Macros:
	.set link, 0

	// Push to return stack
	.macro rpush reg
		str \reg, [r11, #-4]!
	.endm

	// Pop from return stack
	.macro rpop reg
		ldr \reg, [r11], #4
	.endm

	// The inner interpreter
	.macro NEXT
		ldr r8, [r10], #4 // r10 = the virtual instruction pointer
		ldr r0, [r8]      // r8 = xt of current word
		bx r0             // (r0 = temp)
	.endm

	// Define an assembly word
	.macro defcode name, len, label, flags=0
	.data
	.align 2                 // link field
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags         // name field
	.ascii "\name"
	.space F_LENMASK-\len
	.align 2
xt_\label:                   // code field
	.int code_\label
	.text                    // start defining the code after the macro
	.align 2
	code_\label:
	.endm

	// Define a high-level word (indirect threaded)
	.macro defword name, len, label, flags=0
	.data
	.align 2              // link field
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags     // name field
	.ascii "\name"
	.space F_LENMASK-\len
	.align 2
	.global xt_\label
xt_\label:                // xt: colon interpreter
	.int enter_colon
	params_\label:            // parameters
	.endm

	// Data:

	// Label for relative branches within "defword" macros
	.macro label name
		.int \name - .
	.endm

	.data
	.align 2
var_eundef:
	.int xt_quit        // Word to execute if a word not in the dictionary is compiled
var_dict:
	.int dictionary     // dictionary start
var_base:
	.int 10             // number base
var_h:
	.int free           // compilation pointer
var_state:
	.int 0              // interpret mode
var_latest:
	.int the_last_word  // latest word pointer
var_source:
	.int source         // source addr
var_s_zero:
	.int stack_start    // parameter stack base address
var_r_zero:
	.int rstack_start   // return stack base address
var_to_in:              // input buffer
	.int 0
var_num_tib:
	.int 0
var_to_out:             // output pointer
	.int 0
var_num_tob:
	.int 0
output_buffer:
	.space TOB_SIZE
input_buffer:
	.space TIB_SIZE
	.align 2
	.space STACK_SIZE          // Parameter stack grows downward and underflows into the return stack
stack_start:
	.align 2
	.space RSTACK_SIZE         // Return stack grows downward
rstack_start:
	.align 2
dictionary:                    // Start of dictionary

	// Assembly:

	.section .text
	.align 2
	.global _interpreter
_interpreter:
	ldr sp, =stack_start
	ldr r11, =rstack_start
	ldr r10, =code               // Start up the inner interpreter
	NEXT
code:
	.int xt_quit

enter_colon:
	rpush r10       // Save the return address to the return stack
	add r10, r8, #4 // Get the next instruction
	NEXT

enter_variable:    // A word whose parameter list is a 1-cell value
	push {r9}
	add r9, r8, #4 // Push the address of the value
	NEXT

enter_constant:      // A word whose parameter list is a 1-cell value
	push {r9}
	ldr r9, [r8, #4] // Push the value
	NEXT

	// Subroutine for integer division and modulo
	// This algorithm for unsigned DIVMOD is extracted from
	// 'ARM Software Development Toolkit User Guide v2.50' published by ARM in 1997-1998
	// args: r0=numerator, r1=denominator
	// returns: r0=remainder, r1 = denominator, r2=quotient
	// There is no need to save any registers because this subroutine just uses R0-R3
fn_divmod:
	mov r3, r1
	cmp r3, r0, LSR #1
fn_divmod1:
	movls r3, r3, LSL #1
	cmp r3, r0, LSR #1
	bls fn_divmod1
	mov r2, #0
fn_divmod2:
	cmp r0, r3
	subcs r0, r0, r3
	adc r2, r2, r2
	mov r3, r3, LSR #1
	cmp r3, r1
	bhs fn_divmod2
	bx lr

	// ----- Constant Words -----

	defcode "D0", 2, d_zero
	push {r9}
	ldr r0, =var_dict
	ldr r9, [r0]
	NEXT

	defcode "R0", 2, r_zero
	push {r9}
	ldr r0, =var_r_zero
	ldr r9, [r0]
	NEXT

	defcode "S0", 2, s_zero
	push {r9}
	ldr r0, =var_s_zero
	ldr r9, [r0]
	NEXT

	defcode "tib-size", 8, tib_size
	push {r9}
	mov r9, #TIB_SIZE
	NEXT

	defcode "tib", 3, tib
	push {r9}
	ldr r9, =input_buffer
	NEXT

	defcode "tob-size", 8, tob_size
	push {r9}
	mov r9, #TOB_SIZE
	NEXT

	defcode "tob", 3, tob
	push {r9}
	ldr r9, =output_buffer
	NEXT

	defcode "fhidden", 7, fhidden
	push {r9}
	mov r9, #F_HIDDEN
	NEXT

	defcode "fimmediate", 10, fimmediate
	push {r9}
	mov r9, #F_IMMEDIATE
	NEXT

	defcode "flenmask", 8, flenmask
	push {r9}
	mov r9, #F_LENMASK
	NEXT

	defcode "cell", 4, cell
	push {r9}
	mov r9, #4
	NEXT

	defcode "cells", 5, cells
	lsl r9, #2           // (x * 4) = (x << 2)
	NEXT

	defcode "true", 4, true // true = -1
	push {r9}
	mov r9, #-1
	NEXT

	defcode "false", 5, false // false = 0
	push {r9}
	mov r9, #0
	NEXT

	defcode "#name", 5, num_name
	push {r9}
	mov r9, #F_LENMASK
	NEXT

	// ----- Variable Words -----

	defcode "#tib", 4, num_tib     // variable
	push {r9}
	ldr r9, =var_num_tib
	NEXT

	defcode "def->in", 7, to_in
	push {r9}
	ldr r9, =var_to_in
	NEXT

	defcode "state", 5, state
	push {r9}
	ldr r9, =var_state
	NEXT

	defcode "latest", 6, latest
	push {r9}
	ldr r9, =var_latest
	NEXT

	defcode "h", 1, h              // variable that holds the current compilation address
	push {r9}
	ldr r9, =var_h
	NEXT

	defcode "base", 4, base        // number base
	push {r9}
	ldr r9, =var_base
	NEXT

	// ----- Primitive words -----

	defcode "exit", 4, exit
	rpop r10
	NEXT

	defcode "[']", 3, lit   // ( -- x )
	push {r9}               // Push the next instruction value to the stack.
	ldr r9, [r10], #4
	NEXT

	defcode ",", 1, comma   // ( x -- )
	ldr r0, =var_h
	cpy r1, r0
	ldr r0, [r0]        // r0 = here
	str r9, [r0], #4    // *here = TOS
	str r0, [r1]        // H += 4
	pop {r9}
	NEXT

	defcode "c,", 2, c_comma  // ( c -- ) compile char
	ldr r0, =var_h
	cpy r1, r0
	ldr r0, [r0]
	strb r9, [r0], #1     // *H = TOS
	str r0, [r1]          // H += 1
	pop {r9}
	NEXT

	defcode "SP@", 3, sp_fetch
	push {r9}
	mov r9, sp
	NEXT

	defcode "SP!", 3, sp_store
	mov sp, r9
	NEXT

	defcode "RP@", 3, rp_fetch
	push {r9}
	ldr r9, [r11]
	NEXT

	defcode "RP!", 3, rp_store
	mov r11, r9
	pop {r9}
	NEXT

	defcode "->R", 3, to_r     // ( -- x R: x -- )
	rpush r9
	pop {r9}
	NEXT

	defcode "R->", 3, r_from   // ( x -- R: -- x )
	push {r9}
	rpop r9
	NEXT

	defcode "dup", 3, dup     // ( x -- x x )
	push {r9}
	NEXT

	defcode "drop", 4, drop   // ( x -- )
	pop {r9}
	NEXT

	defcode "nip", 3, nip     // ( x1 x2 -- x2 )
	pop {r0}
	NEXT

	defcode "swap", 4, swap   // ( x1 x2 -- x2 x1 )
	pop {r0}
	push {r9}
	mov r9, r0
	NEXT

	defcode "over", 4, over   // ( x1 .x2 -- x1 x2 .x1 )
	ldr r0, [sp]          // get a copy of the second item on stack
	push {r9}             // push TOS to the rest of the stack
	mov r9, r0            // TOS = copy of the second item from earlier
	NEXT

	defcode "tuck", 4, tuck   // ( x1 x2 -- x2 x1 x2 )
	pop {r0}
	push {r9}
	push {r0}
	NEXT

	defcode "rot", 3, rot     // ( x1 x2 x3 -- x2 x3 x1 )
	pop {r0}              // r0 = x2
	pop {r1}              // r1 = x1
	push {r0}
	push {r9}
	mov r9, r1            // TOS = x1
	NEXT

	defcode "-rot", 4, minus_rot   // ( x1 x2 x3 -- x3 x1 x2 )
	pop {r0}                   // r0 = x2
	pop {r1}                   // r1 = x1
	push {r9}
	push {r1}
	mov r9, r0                 // TOS = x2
	NEXT

	defcode "2dup", 4, two_dup  // ( x1 x2 -- x1 x2 x1 x2 )
	ldr r1, [sp]            // r1 = x1
	push {r9}
	push {r1}
	NEXT

	defcode "2drop", 5, two_drop // ( x1 x2 -- )
	pop {r0}
	pop {r9}
	NEXT

	defcode "2swap", 5, two_swap // ( x1 x2 x3 x4 -- x3 x4 x1 x2 )
	pop {r0}                 // r0 = x3
	pop {r1}                 // r1 = x2
	pop {r2}                 // r2 = x1
	push {r0}
	push {r9}
	push {r2}
	mov r9, r1               // TOS = x2
	NEXT

	defcode "2over", 5, two_over // ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
	pop {r3}
	pop {r2}
	pop {r1}
	push {r1}
	push {r2}
	push {r3}
	push {r9}
	push {r1}
	mov r9, r2
	NEXT

	defcode "1+", 2, one_plus   // increment
	add r9, #1
	NEXT

	defcode "1-", 2, one_minus  // decrement
	sub r9, #1
	NEXT

	defcode "max", 3, max // ( x1 x2 -- x1|x2 )
	pop {r0}
	cmp r9, r0
	movlt r9, r0
	NEXT

	defcode "min", 3, min // ( x1 x2 -- x1|x2 )
	pop {r0}
	cmp r9, r0
	movgt r9, r0
	NEXT

	defcode "+", 1, plus // ( x1 x2 -- x3 )
	pop {r1}         // r1 = x1
	add r9, r1
	NEXT

	defcode "-", 1, minus // ( x1 x2 -- x3 )
	pop {r1}          // r1 = x1
	sub r9, r1, r9    // x3 = x1 - x2
	NEXT

	defcode "*", 1, star  // ( x1 x2 -- x3 )
	pop {r1}          // r1 = x1
	mov r2, r9        // r2 = x2
	mul r9, r1, r2    // x3 = x1 * x2
	NEXT

	// Double signed multiply
	// UMULL{S}{cond} RdLo, RdHi, Rn, Rm
	// SMULL{S}{cond} RdLo, RdHi, Rn, Rm
	// high word half is on top
	defcode "d*", 2, d_star  // ( n1 n2 -- D )
	pop {r0}
	mov r1, r9
	smull r2, r9, r0, r1
	push {r2}
	NEXT

	// ( x1 x2 -- x3 ) where x3 = (x1 << x2)
	defcode "lsl", 3, lsl
	pop {r0}
	lsl r0, r9
	mov r9, r0
	NEXT

	// ( x1 x2 -- x3 ) where x3 = (x1 >> x2)
	defcode "lsr", 3, lsr
	pop {r0}
	lsr r0, r9
	mov r9, r0
	NEXT

	// ( x1 x2 -- f )
	defcode "=", 1, equals
	pop {r0}
	cmp r9, r0
	eor r9, r9         // 0 for false
	mvneq r9, r9       // invert for true
	NEXT

	// ( x1 x2 -- f )
	defcode "<>", 2, not_equals
	pop {r0}
	cmp r9, r0
	eor r9, r9    // 0 for false
	mvnne r9, r9  // invert for true
	NEXT

	defcode "<", 1, less
	pop {r0}
	cmp r0, r9      // r9 < r0
	eor r9, r9
	mvnlt r9, r9
	NEXT

	defcode ">", 1, more
	pop {r0}
	cmp r0, r9      // r9 > r0
	eor r9, r9
	mvngt r9, r9
	NEXT

	defcode "and", 3, and
	pop {r0}
	and r9, r9, r0
	NEXT

	defcode "or", 2, or
	pop {r0}
	orr r9, r9, r0
	NEXT

	defcode "xor", 3, xor
	pop {r0}
	eor r9, r9, r0
	NEXT

	defcode "not", 3, not
	mvn r9, r9
	NEXT

	defcode "negate", 6, negate
	neg r9, r9
	NEXT

	// ( x a -- )
	defcode "!", 1, store
	pop {r0}
	str r0, [r9]
	pop {r9}
	NEXT

	// ( x a -- )
	defcode "+!", 2, plus_store
	pop {r0}
	ldr r1, [r9]
	add r0, r1
	str r0, [r9]
	pop {r9}
	NEXT

	// ( c a -- )
	defcode "c!", 2, c_store
	pop {r0}
	strb r0, [r9]
	pop {r9}
	NEXT

	// ( a -- x )
	defcode "@", 1, fetch
	ldr r9, [r9]
	NEXT

	// ( a -- c )
	defcode "c@", 2, c_fetch 
	ldrb r9, [r9]
	NEXT
	
	defcode "branch", 6, branch   // ( -- ) relative branch
	ldr r0, [r10]
	add r10, r0
	NEXT

	defcode "0branch", 7, zero_branch  // ( x -- )
	cmp r9, #0
	ldreq r0, [r10]              // Set the IP to the next codeword if 0,
	addeq r10, r0
	addne r10, #4                // but increment IP otherwise.
	pop {r9}                     // discard TOS
	NEXT

	defcode "execute", 7, execute // ( xt -- )
	mov r8, r9   // r8 = the xt
	ldr r0, [r8] // (indirect threaded)
	pop {r9}     // pop the stack
	bx r0
	// Unreachable. No next

	defcode "cmove", 5, cmove // ( a1 a2 u -- ) move u chars from a1 to a2
	eor r0, r0 // r0 = index
	pop {r2}   // r2 = a2
	pop {r1}   // r1 = a1
	b cmove_check
cmove_body:
	ldrb r3, [r1, r0]
	strb r3, [r2, r0]
	add r0, #1
cmove_check:
	cmp r0, r9
	blt cmove_body
	pop {r9}
	NEXT

	// ( a1 a2 u -- )
	defcode "cmove>", 6, cmove_from 
	mov r2, r9 // r2 = index
	pop {r1} // r1 = a2
	pop {r0} // r0 = a1
	b cmove_from_check
cmove_from_body:
	ldrb r3, [r0, r2]
	strb r3, [r1, r2]
	sub r2, #1
cmove_from_check:
	cmp r2, #0
	bge cmove_from_body
	pop {r9}
	NEXT

	// ( n m -- r q ) division remainder and quotient
	// Warning: susceptible to division by zero
	defcode "/mod", 4, slash_mod 
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	NEXT

	// TODO: handle error of division by zero

	// Warning: susceptible to division by zero
	// ( n m -- q ) division remainder and quotient
	defcode "/", 1, slash 
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r2
	NEXT

	// Warning: susceptible to division by zero
	// ( n m -- r ) division remainder and quotient
	defcode "mod", 3, mod 
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r0
	NEXT

	// -- Higher-level code --

	// Write an unsigned number to (the end of) a buffer
	// Note: track with "u->str.forth"
	// ( n:unsigned str:addr len:unsigned -- len:unsigned )
	defword "u->str", 6, u_to_str 
	// ( n addr len -- addr len )
	// Iterate backwards...
	.int xt_one_minus, xt_dup, xt_to_r // save original buffer length
	// ( n str index )
u_str_begin$:
		.int xt_dup, xt_lit, 0, xt_more, xt_not               // ( index >= 0 )
		.int xt_rot, xt_dup, xt_lit, 0, xt_less, xt_minus_rot // ( n > 0 )
		.int xt_and
	.int xt_zero_branch
	label u_str_end // ( n str index )
		.int xt_rot, xt_base, xt_fetch, xt_slash_mod // ( str index q r )
		.int xt_n_to_digit, xt_to_r, xt_minus_rot    // ( q str index )
		.int xt_two_dup, xt_plus, xt_r_from          // ( q str index addr digit )
		.int xt_swap, xt_store                       // ( q str index )
		.int xt_one_minus                            // ( q str index-1 )
u_str_end$:
	.int xt_r_from         // ( n str index length )
	.int xt_swap, xt_minus // ( n str real_length )
	.int xt_rot, xt_drop   // ( str real_length )
	.int xt_exit

	// Write unsigned int to the static string buffer
	// ( n:u -- addr len:u )
	defword "u->string", 9, u_to_string
	.int xt_lit, u_to_string_buf, xt_lit, 32 // ( n addr buflen )
	.int xt_u_to_str                 // ( addr len )
	.int xt_lit, 32, xt_over         // ( addr len buflen len )
	.int xt_minus, xt_rot            // ( len remaining addr )
	.int xt_plus, xt_swap            // ( addr-start len )
u_to_string_buf: .space 32

	// ( x1 x2 x3 -- x1 x2 x3 x1 x2 x3 )
	defword "3dup", 4, three_dup
	.int xt_dup
	.int xt_two_over
	.int xt_rot
	.int xt_exit

	// ( x -- )
	defword "literal", 7, literal, F_COMPILE+F_IMMEDIATE 
	.int xt_lit, xt_lit, xt_comma
	.int xt_comma
	.int xt_exit

	defword "entercolon", 10, entercolon
	.int xt_lit, enter_colon
	.int xt_exit

	defword "entervariable", 13, entervariable
	.int xt_lit, enter_variable
	.int xt_exit

	defword "enterconstant", 13, enterconstant
	.int xt_lit, enter_constant
	.int xt_exit

	defword ";", 1, semicolon, F_COMPILE+F_IMMEDIATE
	.int xt_lit, xt_exit, xt_comma      // compile exit code
	.int xt_latest, xt_fetch, xt_hide   // toggle the hide flag to show the word
	.int xt_bracket                     // enter the immediate interpreter
	// no exit

	defword ":", 1, colon
	.int xt_header
	.int xt_entercolon, xt_comma        // make the word run docol
	.int xt_latest, xt_fetch, xt_hide   // hide the word
	.int xt_rbracket                    // enter the compiler
	// no exit

	// ( -- ) create link field
	defword "link", 4, link
	.int xt_here, xt_align, xt_h, xt_store
	.int xt_here                        // here = this new link address
	.int xt_latest, xt_fetch, xt_comma  // link field points to previous word
	.int xt_latest, xt_store            // make this link field address the latest word
	.int xt_exit

	defword "header:", 7, header // ( -- ) create link and name field in dictionary
	.int xt_link
	.int xt_lit, ' '
	.int xt_word                  // ( a )
	.int xt_dup, xt_dup
	.int xt_c_fetch               // ( a a len )
	.int xt_num_name, xt_min
	.int xt_swap, xt_c_store      // ( a )
	.int xt_num_name, xt_one_plus, xt_plus
	.int xt_h, xt_store
	.int xt_exit

	defword "align", 5, align // ( a1 -- a2 )
	.int xt_lit, 3, xt_plus
	.int xt_lit, 3, xt_not, xt_and // a2 = (a1+(4-1)) & ~(4-1);
	.int xt_exit

	defword "here", 4, here // current compilation address
	.int xt_h, xt_fetch
	.int xt_exit

	defword "[", 1, bracket, F_COMPILE+F_IMMEDIATE // ( -- ) interpret mode
	.int xt_state, xt_fetch
	.int xt_zero_branch
	label already_interpret
	.int xt_false, xt_state, xt_store
	.int xt_quit
already_interpret:
	.int xt_exit

	// ( -- ) compiler
	defword "]", 1, rbracket
	.int xt_true, xt_state, xt_store
compile:
	.int xt_lit, xt_sep_q
	.int xt_word
	.int xt_count                      // ( a u )
	.int xt_two_dup
	.int xt_find, xt_dup
	.int xt_zero_branch            // ( a u link|0 )
	label compile_no_find
	.int xt_nip, xt_nip            // ( link )
	.int xt_dup, xt_question_immediate
	.int xt_zero_branch
	label compile_normal
	.int xt_to_xt
	.int xt_execute      // immediate
	.int xt_branch
	label compile
compile_normal:
	.int xt_to_xt, xt_comma
	.int xt_branch
	label compile
compile_no_find:
	.int xt_drop
	.int xt_two_dup                // ( a u a u )
	.int xt_str_to_d               // ( a u d e|0 )
	.int xt_zero_branch
	label compile_number
	.int xt_two_drop               // ( a u d -- a u )
	.int xt_drop                   // ( -- a )
	.int xt_lit, TIB_SIZE          // ( -- a u )
	.int xt_parse_string_lit       // ( a u -- a2 u2 f )
	.int xt_zero_branch
	label compile_string
	.int xt_two_drop
	.int xt_lit, compile_msg
	.int xt_lit, compile_msg_len
	.int xt_print
	.int xt_branch
	label compile
compile_string:
	.int xt_compile_string_lit    // ( a u -- )
	.int xt_branch
	label compile
compile_number:
	.int xt_d_to_n
	.int xt_lit, xt_lit, xt_comma // compiles "lit #"
	.int xt_comma
	.int xt_two_drop
	.int xt_branch
	label compile
compile_msg: .ascii " error: could not compile word"
compile_msg_len: .int compile_msg_len - compile_msg

	defword "def>link", 8, to_link // ( xt -- link )
	.int xt_lit, 4+1+F_LENMASK, xt_minus
	.int xt_exit

	defword "def>name", 8, to_name // ( link -- a )
	.int xt_lit, 4, xt_plus
	.int xt_exit

	defword ">xt", 3, to_xt // ( link -- xt )
	.int xt_lit, 4+1+F_LENMASK
	.int xt_plus
	.int xt_exit

	defword ">params", 7, to_params // ( link -- a2 )
	.int xt_lit, 4+1+F_LENMASK+4, xt_plus
	.int xt_exit

	defword "hidden?", 7, question_hidden // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_fhidden, xt_and, xt_bool
	.int xt_exit

	defword "immediate?", 10, question_immediate // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_fimmediate, xt_and, xt_bool
	.int xt_exit

	defword "count", 5, count // ( a1 -- a2 c )
	.int xt_dup               // ( a1 a1 )
	.int xt_one_plus, xt_swap // ( a2 a1 )
	.int xt_c_fetch           // ( a2 c )
	.int xt_exit

	// ( a u1 -- d u2 ), assume u1 > 0
	defword "str->d", 6, str_to_d
	.int xt_over, xt_c_fetch
	.int xt_lit, '-', xt_equals
	.int xt_zero_branch               // ( a u1 )
	label str_to_d_positive
	.int xt_one_minus                 // len--
	.int xt_swap
	.int xt_one_plus                  // addr++
	.int xt_swap
	.int xt_str_to_ud                 // ( ud u2 )
	.int xt_swap, xt_negate, xt_swap  // ( d u2 )
	.int xt_over, xt_zero_equals
	.int xt_zero_branch
	label str_to_d_not_zero
	.int xt_rot, xt_negate, xt_minus_rot
str_to_d_not_zero:
	.int xt_exit
str_to_d_positive:
	.int xt_str_to_ud                 // ( a u1 -- d u2 )
	.int xt_exit

	defword "d->n", 4, d_to_n // ( d -- n )
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label d_to_n_positive
	.int xt_negate
d_to_n_positive:
	.int xt_exit

	// ( n -- a u )
	defword "n->str", 6, n_to_str
	.int xt_dup                  // ( n n )
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label n_positive             // ( n )
	.int xt_negate               // ( u )
	.int xt_u_to_str             // ( a u )
	.int xt_one_plus             // length+1
	.int xt_swap, xt_one_minus   // ( u a )
	.int xt_lit, '-'             // ( u a '-' )
	.int xt_over, xt_c_store     // ( u a )
	.int xt_swap                 // ( a u )
	.int xt_exit
n_positive: // ( n )
	.int xt_u_to_str // ( a u )
	.int xt_exit

	defword "hide", 4, hide // ( link -- )
	.int xt_to_name
	.int xt_dup, xt_c_fetch
	.int xt_fhidden, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	defword "NEWLINE", 7, cr
	.int xt_lit, '\n'
	.int xt_exit

	defword "BLANK", 5, bl
	.int xt_lit, 32
	.int xt_exit

	// ( a1 u1 a2 u2 -- f ) compare counted strings
	defword "compare", 7, compare          
	.int xt_rot, xt_swap               // ( a1 a2 u2 u1 )
	.int xt_two_dup, xt_equals, xt_zero_branch
	label compare_len_neq
	.int xt_drop                       // ( a1 a2 u2 )
compare_next:
	.int xt_dup, xt_zero_branch
	label compare_eql
	.int xt_minus_rot
	.int xt_two_dup
	.int xt_c_fetch, xt_swap
	.int xt_c_fetch, xt_equals
	.int xt_zero_branch
	label compare_neq
	.int xt_one_plus, xt_swap
	.int xt_one_plus, xt_swap
	.int xt_rot
	.int xt_one_minus
	.int xt_branch
	label compare_next
compare_eql:
	.int xt_drop, xt_drop, xt_drop
	.int xt_true
	.int xt_exit
compare_neq:
	.int xt_drop, xt_drop, xt_drop
	.int xt_false
	.int xt_exit
compare_len_neq:
	.int xt_two_drop, xt_two_drop
	.int xt_false
	.int xt_exit

	// ( a u -- link | 0 )
	defword "find", 4, find                
	.int xt_latest, xt_fetch           // ( a u link )
find_link:
	.int xt_dup
	.int xt_zero_branch
	label find_no_find                 // ( a u link )
	.int xt_dup, xt_question_hidden
	.int xt_not, xt_zero_branch
	label find_skip_hidden
	.int xt_dup, xt_two_swap, xt_rot   // ( link a1 len1 link )
	.int xt_to_name, xt_count         // ( link a1 len1 a2 len2 )
	.int xt_flenmask, xt_and
	.int xt_two_over                   // ( link a1 len1 a2 len2 a1 len1 )
	.int xt_compare, xt_not
	.int xt_zero_branch
	label find_found
	.int xt_rot                        // ( a1 len1 link )
find_skip_hidden:
	.int xt_fetch
	.int xt_branch
	label find_link
find_found:
	.int xt_two_drop
	.int xt_exit
find_no_find:
	.int xt_two_drop, xt_drop
	.int xt_false
	.int xt_exit

	defword "0=", 2, zero_equals
	.int xt_lit, 0, xt_equals
	.int xt_exit

	// makes the most recently defined word immediate (word is not itself immediate)
	defword "immediate", 9, immediate 
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fimmediate, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	// ( c1 -- a1 ) scan source for word delimited by c1 and copy it to the memory pointed to by `here`
	defword "word", 4, word           // ( c1 -- a1 )
	// TODO
	.int xt_exit

the_last_word:

	// ( i*x R: j*x -- i*x R: )
	defword "quit", 4, quit 
	.int xt_r_zero, xt_rp_store    // clear return stack
	.int xt_break
	.int xt_bracket
quit_interpret:
	.int xt_lit, xt_sep_q, xt_word
	.int xt_count                  // ( a u )
	.int xt_two_dup
	.int xt_find, xt_dup
	.int xt_zero_branch            // ( a u link|0 )
	label quit_no_find
	.int xt_nip, xt_nip
	.int xt_to_xt, xt_execute
	.int xt_branch
	label quit_interpret
quit_no_find:
	.int xt_drop
	.int xt_two_dup                // ( a u a u )
	.int xt_str_to_d               // ( a u d e|0 )
	.int xt_zero_branch
	label quit_number
	.int xt_two_drop               // ( a u d -- a u )
	.int xt_eundef, xt_fetch, xt_execute
	.int xt_branch
	label quit_interpret
quit_number:
	.int xt_d_to_n
	.int xt_nip, xt_nip
	.int xt_branch
	label quit_interpret

