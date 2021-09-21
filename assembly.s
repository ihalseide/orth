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

