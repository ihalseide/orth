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
	.equ F_HIDDEN,    0b01000000 // hidden word flag bit
	.equ F_COMPILE,   0b00100000 // compile-only word flag bit
	.equ F_LENMASK,   0b00011111 // 31
	.equ TIB_SIZE, 1024          // (bytes) size of terminal input buffer
	.equ RSTACK_SIZE, 512*4      // (bytes) size of the return stack
	.equ STACK_SIZE, 64*4        // (bytes) size of the return stack

	// Macros:

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
	.set link, 0
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
var_to_in:
	.int 0
var_num_tib:
	.int 0
input_buffer: .space TIB_SIZE
	.align 2
	.space STACK_SIZE          // Parameter stack grows downward and underflows into the return stack
stack_start:
	.align 2
	.space RSTACK_SIZE         // Return stack grows downward
rstack_start:
	.align 2
dictionary:                    // Start of dictionary

	// Assembly:

	.text
	.align 2
	.global _start
code:
	.int xt_quit
_start:                        // MAIN entry point
	ldr sp, =stack_start
	ldr r11, =rstack_start
	ldr r10, =code             // Start up the inner interpreter
	NEXT

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

	defcode "tib-size", 8, tib_size // constant
	push {r9}
	mov r9, #TIB_SIZE
	NEXT

	defcode "tib", 3, tib          // constant
	push {r9}
	ldr r9, =input_buffer
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

	defcode "fcompile", 8, fcompile
	push {r9}
	mov r9, #F_COMPILE
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
	eor r9, r9
	mvn r9, r9
	NEXT

	defcode "false", 5, false // false = 0
	push {r9}
	eor r9, r9
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

	defcode ">in", 3, to_in        // variable
	push {r9}
	ldr r9, =var_to_in
	NEXT

	defcode "state", 5, state      // variable
	push {r9}
	ldr r9, =var_state
	NEXT

	defcode "latest", 6, latest    // variable
	push {r9}
	ldr r9, =var_latest
	NEXT

	defcode "h", 1, h              // variable that holds the current compilation address
	push {r9}
	ldr r9, =var_h
	NEXT

	defcode "base", 4, base        // variable
	push {r9}
	ldr r9, =var_base
	NEXT

	// -----  Exception variable words -----

	defcode "eundefc", 7, eundefc
	push {r9}
	ldr r9, =var_eundefc
	NEXT

	defcode "eundef", 6, eundef
	push {r9}
	ldr r9, =var_eundef
	NEXT

	// ----- Primitive words -----

	defcode "break", 5, break
breakpoint:
	mov r0, r0
	NEXT

	defcode "exit", 4, exit
	rpop r10
	NEXT

	defcode "[']", 3, lit   // ( -- x )
	push {r9}           // Push the next instruction value to the stack.
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

	defcode "c,", 2, c_comma
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

	defcode ">R", 2, to_r     // ( -- x R: x -- )
	rpush r9
	pop {r9}
	NEXT

	defcode "R>", 2, r_from   // ( x -- R: -- x )
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

	defcode "1+", 2, one_plus
	add r9, #1
	NEXT

	defcode "1-", 2, one_minus
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

	// ( -- ) relative branch
	defcode "branch", 6, branch 
	ldr r0, [r10]
	add r10, r0
	NEXT

	// ( x -- )
	defcode "0branch", 7, zero_branch 
	cmp r9, #0
	ldreq r0, [r10]              // Set the IP to the next codeword if 0,
	addeq r10, r0
	addne r10, #4                // but increment IP otherwise.
	pop {r9}                     // discard TOS
	NEXT

	// ( xt -- )
	defcode "execute", 7, execute 
	mov r8, r9                // r8 = the xt
	ldr r0, [r8]              // (indirect threaded)
	pop {r9}                  // pop the stack
	bx r0
	// no next

	// ( a1 a2 u -- ) move u chars from a1 to a2
	defcode "cmove", 5, cmove 
	eor r0, r0            // r0 = index
	pop {r2}              // r2 = a2
	pop {r1}              // r1 = a1
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
	mov r2, r9                  // r2 = index
	pop {r1}                    // r1 = a2
	pop {r0}                    // r0 = a1
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

	// convert string to unsigned double
	// ( a u1 -- ud u2 )
	defcode "str>ud", 6, str_to_ud 
	pop {r0}                   // r0 = addr
	eor r1, r1                 // r1 = d.high
	eor r2, r2                 // r2 = d.low
	ldr r4, =var_base          // get the current number base
	ldr r4, [r4]
	b to_num_test
to_num1:
	ldrb r3, [r0], #1          // get next char in the string
	cmp r3, #'a'               // if it's less than 'a', it's not lower case
	blt to_num2
	sub r3, #32                // convert the 'a'-'z' from lower case to upper case
to_num2:
	cmp r3, #'9'+1             // if char is less than '9' its probably a decimal digit
	blt to_num3
	cmp r3, #'A'               // if it's a character between '9' and 'A', it's an error
	blt to_num_done
	cmp r3, #'0'               // if it's a character below '0', it's an error
	blt to_num_done
	sub r3, #7                 // a valid char for a base>10, so convert it so that 'A' signifies 10
to_num3:
	sub r3, #'0'               // convert char digit to value
	cmp r3, r4                 // if digit >= base then it's an error
	bge to_num_done
	cmp r3, #0
	blt to_num_done
	mul r5, r1, r4             // multiply the high-word by the base
	mov r1, r5
	// UMULL{S}{cond} RdLo, RdHi, Rn, Rm
	umull r5, r6, r2, r4       // multiply the low-word by the base and carry into high word
	add r1, r6
	add r2, r5, r3             // add the digit value to the low word (no need to carry)
	sub r9, #1                 // decrement length remaining
to_num_test:
	cmp r9, #0                 // if length=0 then it's done converting
	bgt to_num1
to_num_done:                   // number conversion done
	push {r2}                  // push the low word
	push {r1}                  // push the high word
	NEXT

	// convert unsigned integer to string
	// ( u1 -- a u2 )
	defcode "u>str", 5, u_to_str
	// Make space for the number string
	mov r4, #0                // r4 = index
	ldr r5, =var_h
	ldr r5, [r5]              // r5 = here (temporary space to write the digits)
	add r5, #F_LENMASK+12     // leave a space for prefix minus sign
	// Get the number base
	ldr r6, =var_base         // r6 = number base
	ldr r6, [r6]
	// Early return for invalid base
	cmp r6, #1
	bgt good_base
	push {r6}
	eor r9, r9                // ( a 0 )
	NEXT
good_base:
	cmp r9, #0
	bne base_div
	// Write a 0 to the pad if u is 0
	mov r0, #'0'
	str r0, [r5]
	push {r5}
	mov r9, #1
	NEXT
base_div_body:
	mov r0, r9         // numerator = u (TOS)
	mov r1, r6         // denominator = base
	bl fn_divmod
	strb r3, [r5, r4]  // u % base -> pad[i]
	mov r9, r2         // u / base -> u
	add r4, #1
base_div:
	cmp r9, #0
	bne base_div_body
base_done:
	// Reverse the pad array
	mov r9, r4          // TOS = pad length
	eor r0, r0          // r0 = pad index #1
	sub r1, r4, #1      // r1 = pad index #2
	b reverse
reverse:
	// Get the characters on the opposite sides of the array
	ldrb r2, [r5, r0]
	ldrb r3, [r5, r1]
	// Convert values to digits
	cmp r2, #9
	addgt r2, #7
	cmp r3, #9
	addgt r3, #7
	add r2, #'0'
	add r3, #'0'
	// Swap characters
	strb r2, [r5, r1]
	strb r3, [r5, r0]
	// Move indices towards each other
	add r0, #1
	sub r1, #1
reverse_check:
	cmp r0, r1
	ble reverse
	// done, return
	push {r5}       // second item on stack is the pad start address
	NEXT

	// Code:

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

	// ( a u1 -- u2 )
	defword "accept", 6, accept
	.int xt_dup, xt_to_r             // ( a u1 R: u1 )
accept_char:
	.int xt_dup, xt_zero_branch
	label accept_done
	.int xt_swap
	.int xt_key                      // ( u a c R: u1 )
	.int xt_dup, xt_lit, 10, xt_equals
	.int xt_not, xt_zero_branch
	label accept_break
	.int xt_over, xt_store           // ( u a R: u1 )
	.int xt_one_plus
	.int xt_swap
	.int xt_one_minus
	.int xt_branch
	label accept_char
accept_break:
	.int xt_drop
accept_done:
	.int xt_drop                     // ( u R: u1 )
	.int xt_r_from
	.int xt_swap, xt_minus
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

	// ( -- ) create link and name field in dictionary
	defword "header:", 7, header
	.int xt_link
	.int xt_lit, xt_sep_q
	.int xt_word                  // ( a )
	.int xt_dup, xt_dup
	.int xt_c_fetch               // ( a a len )
	.int xt_num_name, xt_min
	.int xt_swap, xt_c_store      // ( a )
	.int xt_num_name, xt_one_plus, xt_plus
	.int xt_h, xt_store
	.int xt_exit

	// ( -- )
	defword "align", 5, align
	.int xt_lit, 3, xt_plus
	.int xt_lit, 3, xt_not, xt_and // a2 = (a1+(4-1)) & ~(4-1);
	.int xt_exit

	defword "here", 4, here // current compilation address
	.int xt_h, xt_fetch
	.int xt_exit

	// ( -- ) interpret mode
	defword "[", 1, bracket, F_COMPILE+F_IMMEDIATE
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
	.int xt_eundefc, xt_fetch, xt_execute
	.int xt_branch
	label compile
compile_number:
	.int xt_d_to_n
	.int xt_lit, xt_lit, xt_comma // compiles "lit #"
	.int xt_comma
	.int xt_two_drop
	.int xt_branch
	label compile

	// ( xt -- link )
	defword ">link", 5, to_link
	.int xt_lit, 4+1+F_LENMASK, xt_minus
	.int xt_exit

	// ( link -- a )
	defword ">name", 5, to_name
	.int xt_lit, 4, xt_plus
	.int xt_exit

	// ( link -- xt )
	defword ">xt", 3, to_xt
	.int xt_lit, 4+1+F_LENMASK
	.int xt_plus
	.int xt_exit

	// ( link -- a2 )
	defword ">params", 7, to_params
	.int xt_lit, 4+1+F_LENMASK+4, xt_plus
	.int xt_exit

	// ( link -- f )
	defword "hidden?", 7, question_hidden
	.int xt_to_name, xt_c_fetch
	.int xt_fhidden, xt_and, xt_bool
	.int xt_exit

	// ( link -- f )
	defword "immediate?", 10, question_immediate
	.int xt_to_name, xt_c_fetch
	.int xt_fimmediate, xt_and, xt_bool
	.int xt_exit

	// ( link -- f )
	defword "compilation?", 12, compilation_q
	.int xt_to_name, xt_c_fetch
	.int xt_fcompile, xt_and, xt_bool
	.int xt_exit

	// ( a1 -- a2 c )
	defword "count", 5, count
	.int xt_dup               // ( a1 a1 )
	.int xt_one_plus, xt_swap // ( a2 a1 )
	.int xt_c_fetch           // ( a2 c )
	.int xt_exit

	// ( a u1 -- d u2 ), assume u1 > 0
	defword "str>d", 5, str_to_d
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

	// ( d -- n )
	defword "d>n", 3, d_to_n
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label d_to_n_positive
	.int xt_negate
d_to_n_positive:
	.int xt_exit

	// ( n -- a u )
	defword "n>str", 5, n_to_str
	.int xt_dup                       // ( n n )
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label n_positive                  // ( n )
	.int xt_negate                    // ( u )
	.int xt_u_to_str                  // ( a u )
	.int xt_one_plus                  // length+1
	.int xt_swap, xt_one_minus        // ( u a )
	.int xt_lit, '-'                  // ( u a '-' )
	.int xt_over, xt_c_store          // ( u a )
	.int xt_swap                      // ( a u )
	.int xt_exit
n_positive:                           // ( n )
	.int xt_u_to_str                  // ( a u )
	.int xt_exit

	// ( link -- )
	defword "hide", 4, hide
	.int xt_to_name
	.int xt_dup, xt_c_fetch
	.int xt_fhidden, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	defword "CR", 2, cr
	.int xt_lit, '\n'
	.int xt_exit

	defword "BL", 2, bl
	.int xt_lit, 32
	.int xt_exit

	defword "space", 5, space
	.int xt_bl, xt_emit
	.int xt_exit

	// ( x -- f )
	defword "bool", 4, bool                
	.int xt_zero_branch
	label bool_done
	.int xt_true
	.int xt_exit
bool_done:
	.int xt_false
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

	defword "immediate", 9, immediate // makes the most recently defined word immediate (word is not itself immediate)
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fimmediate, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	defword "compilation", 11, compilation, F_IMMEDIATE
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fcompile, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	// ( c1 -- a1 ) scan source for word delimited by c1 and copy it to the memory pointed to by `here`
	defword "word", 4, word           // ( c1 -- a1 )
word_input:
	.int xt_source                // ( c1 a u )
	.int xt_dup, xt_zero_equals
	.int xt_zero_branch           // ( c1 a u )
	label word_copy
	.int xt_two_drop              // ( c1 )
	.int xt_refill, xt_drop       // ( c1 )
	.int xt_branch
	label word_input
word_copy:                        // ( c1 a u )
	.int xt_to_r                  // ( c1 a R: u )   >R
	.int xt_over                  // ( c1 a c1 )
	.int xt_skip                  // ( c1 a3 )
	.int xt_swap, xt_two_dup      // ( a3 c1 a3 c1 )
	.int xt_scan                  // ( a3 c1 a4 )
	.int xt_nip                   // ( a3 a4 )
	.int xt_dup, xt_tib, xt_minus // update >in
	.int xt_to_in, xt_store
	.int xt_over, xt_minus        // ( a3 u )
	.int xt_r_from, xt_max        // ( a3 u R: )      R>
	.int xt_dup, xt_to_r          // ( a3 u R: u )   >R
	.int xt_here                  // ( a3 u a1 )
	.int xt_one_plus              // ( a3 u a1+1 )
	.int xt_swap                  // ( a3 a1+1 u )
	.int xt_cmove                 // ( )
	.int xt_r_from                // ( u R: )         R>
	.int xt_here, xt_c_store      // ( )
	.int xt_here                  // ( a1 )
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

free: 

