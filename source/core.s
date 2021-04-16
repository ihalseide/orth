// Forth Implementation in ARMv7 assembly for GNU/Linux eabi
// by Izak Nathanael Halseide
// Notes:
// * This is an indirect threaded forth.
// * The top of the parameter stack is stored in register R9
// * The parameter stack pointer (PSP) is stored in register R13
// * The parameter stack grows downwards
// * The return stack pointer (RSP) is stored in register R11
// * The return stack grows downwards.
// * The forth virtual instruction pointer (IP) is stored in register R10.
// * The address of the current execution token (XT) is usually stored in register R8

// Word bitmasks constant
.set F_LENMASK,   0b00011111

// Next as a macro => faster code
.macro NEXT
	ldr r8, [r10], #4       // r10 = the virtual instruction pointer
	ldr r0, [r8]            // r8 = xt of current word
	bx r0
.endm

.data

.align 2
input_buffer: .space 1024

.align 2
var_h: .word freespace

.align 2
freespace:

.text

init_code: .word xt_quit

.global _start
_start:
	ldr sp, =0x100           // init parameter stack (grows down from 0x100)
	ldr r11, =0x8000         // init return stack (grows down from 0x8000)

	mov r9, #0               // zero out the top of the stack register

	ldr r10, =init_code      // launch the interpreter with the "init" word
	NEXT


enter:
	str r10, [r11, #-4]!    // Save the return address to the return stack
	add r10, r8, #4         // Get the next instruction
	NEXT


next:                       // The inner interpreter
	NEXT


exit:                       // End a forth word.
	ldr r10, [r11], #4      // ip = pop return stack
	NEXT


do_variable:               // A word whose parameter list is a 1-cell value
	push {r9}              // Prepare a push for r9.
	add r9, r8, #4         // Push the address of the value
	NEXT


do_constant:               // A word whose parameter list is a 1-cell value
	push {r9}              // Prepare a push for r9.
	ldr r9, [r8, #4]       // Push the value
	NEXT


lit:
	push {r9}            // Push to the stack.
	ldr r9, [r10], #4    // Get the next cell value and skip the IP over it.
	NEXT


comma:
	ldr r0, =var_h
	ldr r0, [r0]
	cpy r1, r0         // r1 = *h
	ldr r0, [r0]       // r0 = h

	str r9, [r0, #4]!  // *h = TOS
	str r0, [r1]       // h += 4b

	pop {r9}
	NEXT


c_comma:
	ldr r0, =var_h
	ldr r0, [r0]
	cpy r1, r0
	ldr r0, [r0]

	strb r9, [r0, #1]!      // This line is the only difference with "comma" (see above)
	str r0, [r1]

	pop {r9}
	NEXT


dup:
	push {r9}
	NEXT


drop:
	pop {r9}
	NEXT


swap:
	pop {r0}
	push {r9}
	mov r9, r0
	NEXT


nip:                            // nip ( x y -- y )
	pop {r0}
	NEXT


over:
	ldr r0, [r13]       // r0 = get the second item on stack
	push {r9}           // push TOS to the rest of the stack
	mov r9, r0          // TOS = r0
	NEXT


to_r:
	str r9, [r11, #-4]!
	pop {r9}
	NEXT


r_from:
	push {r9}
	ldr r9, [r11], #4
	NEXT


plus:
	pop {r0}
	add r9, r0
	NEXT


minus:
	pop {r0}
	sub r9, r0, r9    // r9 = r0 - r9
	NEXT


star:
	pop {r0}
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	NEXT


equals:
	pop {r0}
	cmp r9, r0
	moveq r9, #F_TRUE
	movne r9, #F_FALSE
	NEXT


less:
	pop {r0}
	cmp r0, r9      // r9 < r0
	movlt r9, #F_TRUE
	movge r9, #F_FALSE
	NEXT


more:
	pop {r0}
	cmp r0, r9      // r9 > r0
	movgt r9, #F_TRUE
	movle r9, #F_FALSE
	NEXT


and:
	pop {r0}
	and r9, r9, r0
	NEXT


or:
	pop {r0}
	orr r9, r9, r0
	NEXT


xor:
	pop {r0}
	eor r9, r9, r0
	NEXT


invert:
	mvn r9, r9
	NEXT


negate:
	neg r9, r9
	NEXT


store:
	pop {r0}
	str r0, [r9]
	pop {r9}
	NEXT


fetch:
	ldr r9, [r9]
	NEXT


c_store:
	pop {r0}
	strb r0, [r9]
	pop {r9}
	NEXT


c_fetch:
	mov r0, r0
	ldrb r9, [r9]
	NEXT


branch:                       // note: not a relative branch!
	ldr r10, [r10]
	NEXT


zero_branch:                  // note: not a relative branch
	cmp r9, #0
	ldreq r10, [r10]          // Set the IP to the next codeword if 0,
	addne r10, #4             // or increment IP otherwise
	pop {r9}                  // DO pop the stack
	NEXT


execute:
	mov r8, r9        // r8 = the xt
	pop {r9}          // pop the stack
	ldr r0, [r8]      // r0 = code address
	bx r0


accept:                   // ( c-addr u -- u2 )
	mov r7, #sys_read     // make a read system call
	mov r0, #stdin
	pop {r1}              // buf = {pop}
	mov r2, r9            // count = TOS
	swi #0

	cmp r0, #0            // the call returns a negative number upon an error,
	movlt r0, #0          // so zero chars were received

	mov r9, r0            // push number of chars received
	NEXT


// key ( -- c )
key:
	// TODO
	NEXT


// emit ( c -- )
emit:
	// TODO
	NEXT


find:                       // ( addr u -- xt )
	ldr r0, =var_latest     // r0 = current word link field address
	ldr r0, [r0]            // (r0 will be correctly dereferenced again in the 1st iteration of loop #1)
	pop {r1}                // r1 = address of string to find
1: // Loop through the dictionary linked list.
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq 3f

	ldrb r2, [r0, #4]       // get word length+flags byte
	and r2, #F_LENMASK
	cmp r2, r9              // compare the lengths
	bne 1b

	add r2, r0, #5          // r2 = start address of word name string buffer
	eor r3, r3              // r3 = 0 index
2: // Loop through both strings to test for equality.
	ldrb r4, [r1, r3]       // compare input string char to word char
	ldrb r5, [r2, r3]
	cmp r4, r5
	bne 1b                  // if they are ever not equal, the strings aren't equal

	cmp r3, r9              // keep looping until the whole strings have been compared
	add r3, #1              // increment index (starts at index 1)
	bne 2b

	mov r9, r0              // return the link field address
	pop {r0}
	NEXT
3: // Did not find a matching word
	eor r9, r9
	NEXT


word:                       // word - ( char -- addr )
	ldr r1, =const_tib      // r1 = r2 = tib
	ldr r1, [r1]
	mov r2, r1

	ldr r3, =var_to_in      // r1 += >in, so r1 = pointer into the buffer
	ldr r3, [r3]
	ldr r3, [r3]
	add r1, r3

	ldr r3, =var_num_tib    // r2 += #tib, so r2 = last char address in buffer
	ldr r3, [r3]
	ldr r3, [r3]
	add r2, r3

	mov r0, r9              // r0 = char

	ldr r9, =var_h          // push the dictionary pointer, which is used as a buffer area, "pad"
	ldr r9, [r9]            // r4 = r9 = h
	ldr r9, [r9]
	mov r4, r9
word_skip:                      // skip leading whitespace
	cmp r1, r2              // check for if it reached the end of the buffer
	beq word_done

	ldrb r3, [r1], #1       // get next char
	cmp r0, r3
	beq word_skip
word_copy:
	strb r3, [r4, #1]!

	cmp r1, r2
	beq word_done

	ldrb r3, [r1], #1       // get next char
	cmp r0, r3
	bne word_copy
word_done:
	mov r3, #' '            // write a space to the end of the pad
	str r3, [r4]

	sub r4, r9              // get the length of the word written to the pad
	strb r4, [r9]           // store the length byte into the first char of the pad

	ldr r0, =const_tib        // get length inside the input buffer (includes the skipped whitespace)
	ldr r0, [r0]
	sub r1, r0

	ldr r0, =var_to_in      // store back to the variable ">in"
	ldr r0, [r0]
	str r1, [r0]

	NEXT                  // TOS (r9) has been pointing to the pad addr the whole time


psp_fetch:
	push {r9}
	mov r9, sp
	NEXT


psp_store:
	mov sp, r9
	NEXT


rsp_fetch:
	push {r9}
	mov r9, r11
	NEXT


rsp_store:
	mov r11, r9
	pop {r9}
	NEXT


// / ( n m -- q ) division quotient
slash:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r2
	NEXT


// /mod ( n m -- r q ) division remainder and quotient
slash_mod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	NEXT


// mod ( n m -- r ) division remainder
mod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r0
	NEXT


// Function for integer division and modulo
// copy from: https://github.com/organix/pijFORTHos, jonesforth.s
// args: r0=numerator, r1=denominator
// returns: r0=remainder, r1 = denominator, r2=quotient
fn_divmod:
	mov r3, r1
	cmp r3, r0, LSR #1
1:
	movls r3, r3, LSL #1
	cmp r3, r0, LSR #1
	bls 1b
	mov r2, #0
2:
	cmp r0, r3
	subcs r0, r0, r3
	adc r2, r2, r2
	mov r3, r3, LSR #1
	cmp r3, r1
	bhs 2b

	bx lr

