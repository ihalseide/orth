// ----- Constants -----

.set F_LENMASK,   0b00011111
.set F_IMMEDIATE, 0b10000000
.set F_HIDDEN,    0b01000000
.set NAME_LEN, 31
.set TIB_SIZE, 1024
.set TOB_SIZE, 1024
.set TRUE, -1
.set FALSE, 0

// ----- Macros -----

// The inner interpreter
.macro NEXT
	ldr r8, [r10], #4       // r10 = the virtual instruction pointer
	ldr r0, [r8]            // r8 = xt of current word
	bx r0                   // (r0 = temp)
.endm

// Define a code word (primitive)
.set link, 0
.macro defcode name, len, label
	.data
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len               // name field
	.ascii "\name"
	.space NAME_LEN-\len
	.align 2
	.global xt_\label
xt_\label:                   // code field
	.int code_\label
	.text                    // start defining the code after the macro
	.align 2
	.global code_\label
code_\label:
.endm

// Define an indirect threaded word
.macro defword name, len, label
	.data
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len               // name field
	.ascii "\name"
	.space NAME_LEN-\len
	.align 2
	.global xt_\label
xt_\label:                   // do colon
	.int enter_colon
params_\label:               // parameter field
.endm

// Label for relative branches within "defword" macros
.macro label name
	.int \name - .
.endm

// ----- Data -----

.data

.align 2
var_to_in: .int 0
var_num_tib: .int 0
var_to_out: .int 0
var_num_tob: .int 0
var_state: .int 0
var_base: .int 10
var_latest: .int def_quit      // This should actually be the last word!
var_h: .int __data_end         // This symbol is assigned by the linker script

input_buffer: .space NUM_TIB

.align 2
output_buffer: .space NUM_TOB

// ----- Core assembly code -----

.text

.global _start
_start:
	ldr sp, =0x4000             // init parameter stack
	ldr r11, =0x8000            // init return stack

	mov r9, #0                  // zero the TOS register

	ldr r10, =init_code         // set the IP to point to the first forth word to execute
	NEXT

init_code:
	.int xt_quit

next:                           // Inner interpreter
	NEXT

enter_colon:
	str r10, [r11, #-4]!        // Save the return address to the return stack
	add r10, r8, #4             // Get the next instruction
	NEXT

enter_variable:                 // A word whose parameter list is a 1-cell value
	push {r9}
	add r9, r8, #4              // Push the address of the value
	NEXT

enter_constant:                 // A word whose parameter list is a 1-cell value
	push {r9}
	ldr r9, [r8, #4]            // Push the value
	NEXT

enter_does:
	str r10, [r11, #-4]!        // save the IP return address
	ldr r10, [r8, #4]!          // load the behavior pointer into the IP
	push {r9}                   // put the parameter on the stack for the behavior when it runs
	add r9, r8, #4
	NEXT

// Function for integer division and modulo
// copy from: https://github.com/organix/pijFORTHos, jonesforth.s
// args: r0=numerator, r1=denominator
// returns: r0=remainder, r1 = denominator, r2=quotient
fn_divmod:
	// No need to push anything because this just uses r0-r3
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

// ----- Primitive words -----

defcode "exit", 4, exit
	ldr r10, [r11], #4          // ip = pop return stack
	NEXT

defcode "halt", 4, halt         // infinite loop
	b code_halt

defcode "lit", 3, lit
	push {r9}                   // Push the next instruction value to the stack.
	ldr r9, [r10], #4
	NEXT

defcode ",", 1, comma
	ldr r0, =var_h
	cpy r1, r0
	
	ldr r0, [r0]
	str r9, [r0, #4]!    // *H = TOS

	str r0, [r1]         // H += 4

	pop {r9}
	NEXT

defcode "c,", 1, c_comma
	ldr r0, =var_h
	cpy r1, r0

	ldr r0, [r0]
	strb r9, [r0, #1]!   // *H = TOS

	str r0, [r1]         // H += 1

	pop {r9}
	NEXT

defcode "PSP@", 4, psp_fetch
	push {r9}
	mov r9, sp
	NEXT

defcode "PSP!", 4, psp_store 
	mov sp, r9
	NEXT

defcode "RSP@", 4, rsp_fetch
	push {r9}
	mov r9, r11
	NEXT

defcode "RSP!", 4, rsp_store
	mov r11, r9
	pop {r9}
	NEXT

defcode "dup", 3, dup
	push {r9}
	NEXT

defcode "drop", 4, drop
	pop {r9}
	NEXT

defcode "nip", 3, nip
	pop {r0}
	NEXT

defcode "swap", 4, swap
	pop {r0}
	push {r9}
	mov r9, r0
	NEXT

defcode "over", 4, over
	ldr r0, [r13]       // get a copy of the second item on stack
	push {r9}           // push TOS to the rest of the stack
	mov r9, r0          // TOS = copy of the second item from earlier
	NEXT

defcode "rot", 3, rot       // ( x1 x2 x3 -- x2 x3 x1 )
	pop {r0}                // r0 = x2
	pop {r1}                // r1 = x1
	push {r0}
	push {r9}
	mov r9, r1              // TOS = x1
	NEXT

defcode "-rot", 4, minus_rot       // ( x1 x2 x3 -- x3 x1 x2 )
	pop {r0}                       // r0 = x2
	pop {r1}                       // r1 = x1
	push {r9}
	push {r1}
	mov r9, r0                     // TOS = x2
	NEXT

defcode "2dup", 4, two_dup  // ( x1 x2 -- x1 x2 x1 x2 )
	ldr r0, [r13]
	push {r9}
	mov r9, r0
	ldr r0, [r13]
	push {r9}
	mov r9, r0
	NEXT	

defcode "2drop", 5, two_drop // ( x1 x2 -- )
	pop {r9}
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
	push {r9}
	ldr r0, [sp, #16]             // r0 = x1
	ldr r9, [sp, #12]             // TOS = x2
	push {r0}                     // push x1
	NEXT

defcode ">R", 2, to_r
	str r9, [r11, #-4]!
	pop {r9}
	NEXT

defcode "R>", 2, r_from
	push {r9}
	ldr r9, [r11], #4
	NEXT

defcode "+", 1, plus
	pop {r0}
	add r9, r0
	NEXT

defcode "-", 1, minus
	pop {r0}
	sub r9, r0, r9    // r9 = r0 - r9
	NEXT

defcode "*", 1, star
	pop {r0}
	mov r1, r9        // note that a register can't be a src and a dest in mul op on ARM
	mul r9, r0, r1
	NEXT

defcode "=", 1, equals           // ( x1 x2 -- f )
	pop {r0}
	cmp r9, r0
	eor r9, r9                   // 0 for false
	mvneq r9, r9                 // invert for true
	NEXT

defcode "<", 1, less
	pop {r0}
	cmp r0, r9      // r9 < r0
	eor r9, r9
	mvnlt r9, r9
	NEXT

defcode ">", 1, more:
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

defcode "not", 3, not        // invert bits
	mvn r9, r9
	NEXT

defcode "negate", 6, negate
	neg r9, r9
	NEXT

defcode "!", 1, store         // ( x a -- )
	pop {r0}
	str r0, [r9]
	pop {r9}
	NEXT

defcode "c!", 2, c_store          // ( c a -- )
	pop {r0}
	strb r0, [r9]
	pop {r9}
	NEXT

defcode "@", 1, fetch             // ( a -- x )
	ldr r9, [r9]
	NEXT

defcode "c@", 2, c_fetch          // ( a -- c )
	mov r0, r0
	ldrb r9, [r9]
	NEXT

defcode "branch", 6, branch          // branch ( -- ) relative branch
	ldr r0, [r10]
	add r10, r0
	NEXT

defcode "0branch", 7, zero_branch    // 0branch ( x -- )
	cmp r9, #0
	ldreq r0, [r10]                  // Set the IP to the next codeword if 0,
	addeq r10, r0
	addne r10, #4                    // but increment IP otherwise.
	pop {r9}                         // discard TOS
	NEXT

defcode "execute", 7, execute        // ( xt -- )
	mov r8, r9                       // r8 = the xt
	pop {r9}                         // pop the stack
	ldr r0, [r8]                     // r0 = code address
	bx r0                            // dangerous branch

defcode "emit", 4, emit              // ( c -- )
	ldr r3, =num_tob                 // Write a char to the output buffer, increment
	ldr r3, [r3]                     // >out, and reset >out if it goes out of range
	ldr r0, =output_buffer           // for the output buffer.
	ldr r0, [r0]
	ldr r1, =to_tob
	cpy r2, r1
	ldr r1, [r1]
	cmp r1, r3
	movge r1, #0
	strb r9, [r0, r1]
	add r1, #1
	str r1, [r2]
	pop {r9}
	NEXT

defcode "/mod", 4, slash_mod // ( n m -- r q ) division remainder and quotient
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	NEXT

defcode "tib", 3, tib          // constant
	push {r9}
	ldr r9, =input_buffer
	NEXT

defcode "#tib", 4, num_tib     // constant
	push {r9}
	ldr r9, =var_num_tib
	NEXT

defcode ">in", 3, to_in        // variable
	push {r9}
	ldr r9, =var_to_in
	NEXT

defcode "tob", 3, tob          // constant
	push {r9}
	ldr r9, =output_buffer
	NEXT

defcode "#tob", 4, num_tob     // constant
	push {r9}
	ldr r9, =var_num_tob
	NEXT

defcode ">out", 4, to_out      // variable
	push {r9}
	ldr r9, =var_to_out
	NEXT

defcode "state", 5, state      // variable
	push {r9}
	ldr r9, =var_state
	NEXT

defcode "latest", 6, latest    // variable
	push {r9}
	ldr r9, =var_latest
	NEXT

defcode "h", 1, h              // variable
	push {r9}
	ldr r9, =var_h
	NEXT

defcode "str>d", 5, str_to_d  // ( a u1 -- d u2 )
	pop {r0}                  // r0 = addr
	eor r1, r1                // r1 = d.hi
	eor r2, r2                // r2 = d.lo
	ldr r4, =var_base         // get the current number base
	ldr r4, [r4]
to_num1:
	cmp r9, #0                // if length=0 then it's done converting
	beq to_num_done
	ldrb r3, [r0], #1         // get next char in the string
	cmp r3, #'a'              // if it's less than 'a', it's not lower case
	blt to_num2
	sub r3, #32               // convert the 'a'-'z' from lower case to upper case
to_num2:
	cmp r3, #'9'+1            // if char is less than '9' its probably a decimal digit
	blt to_num3
	cmp r3, #'A'              // if it's a character between '9' and 'A', it's an error
	blt to_num_done
	cmp r3, #'0'              // if it's a character below '0', it's an error
	blt to_num_done
	sub r3, #7                // a valid char for a base>10, so convert it so that 'A' signifies 10
to_num3:
	sub r3, #48               // convert char digit to value
	cmp r3, r4                // if digit >= base then it's an error
	bge to_num_done
	mul r5, r1, r4            // multiply the high-word by the base
	mov r1, r5
	/* UMULL{S}{cond} RdLo, RdHi, Rn, Rm */
	umull r5, r6, r2, r4      // multiply the low-word by the base and carry into high word
	add r1, r6
	add r2, r5, r3            // add the digit value to the low word (no need to carry)
	sub r9, #1                // decrement length remaining
	add r0, #1                // a(ddr)++
	b to_num1
to_num_done:                  // number conversion done
	push {r2}                 // push the low word
	push {r1}                 // push the high word
	NEXT

defcode "u>str", 5, u_to_str  // ( u1 -- addr u2 )
	/* Get the pad address and make an index into it */
	mov r4, #0                // r4 = index
	ldr r5, =var_h          
	ldr r5, [r5]              // r5 = pad
	add r5, #30               // add some arbitrary padding
	/* Get the number base */
	ldr r6, =var_base         // r6 = number base
	ldr	r6, [r6]
	/* Only proceed if the number base is valid */
	cmp	r6, #1
	bgt	good_base
	mov r9, 0                 // ( 0 0 )
	push {r9}
	NEXT
good_base:
	cmp	r9, #0
	bne	u_not_zero
	/* Write a 0 to the pad if u is 0 */
	add r4, #1
	eor r0, r0
	str r0, [r5]
u_not_zero:
	/* Switch on the number base */
	tst r6, #1     // the base can't be a power of 2 if it's odd
	b base_other
	cmp r6, #2
	beq base2
	cmp r6, #4
	beq base4
	cmp r6, #8
	beq base8
	cmp r6, #16
	beq base16
	cmp r6, #32
	beq base32     // default case
	b base_other
base2_body:
	and r0, r9, #1
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #1
	cmp r9, #0
base2:
	bne base2_body
	b base_done
base4_body:
	and r0, r9, #3
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #2
	cmp r9, #0
base4:
	bne base4_body
	b base_done
base8_body:
	and r0, r9, #7
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #3
	cmp r9, #0
base8:
	bne base8_body
	b base_done
base16_body:
	and r0, r9, #15
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #4
base16:
	cmp r9, #0
	bne base16_body
	b base_done
base32_body:
	and r0, r9, #31
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #5
base32:
	cmp r9, #0
	bne base32_body
	b base_done
base_other_body:
	mov r0, r9         // numerator = u (TOS)
	mov r1, r6         // denominator = base
	bl fn_divmod
	mov r3, r0         // u % base -> rem
	mov r9, r2         // u / base -> u
	strb r0, [r5, r4]  // rem -> pad[i]
	add r4, #1
base_other:
	cmp r9, #0
	bne base_body
base_done:
	/* Reverse the pad array */
	mov r9, r4          // TOS = pad length
	eor r0, r0          // r0 = pad index #1
	mov r1, r1          // r1 = pad index #2
	b reverse
reverse_body:
	/* Get the characters on the opposite sides of the array */
	ldrb r2, [r5, r0]
	ldrb r3, [r5, r1]
	/* Convert values to digits */
	cmp r2, #9
	addgt r2, #7
	cmp r3, #9
	addgt r3, #7
	add r2, #'0'
	add r3, #'0'
	/* Swap characters */
	str r2, [r5, r1]
	str r3, [r5, r0]
	/* Move indices towards each other */
	add r0, #1
	sub r1, #1
reverse:
	cmp r1, r2
	bls reverse_body
	/* done, return */
	push {r5}       // second item on stack is the pad start address
	NEXT

defcode "R0", 2, r_zero
	push {r9}
	mov r9, 0x8000
	NEXT

defcode "S0", 2, s_zero
	push {r9}
	mov r9, 0x4000
	NEXT

// ----- High-level words ----- 

defword ":", 1, colon
	.int xt_word, xt_header                        // create the empty word header
	.int xt_lit, enter_colon, xt_comma             // make the word run docol
	.int xt_hidden                                 // hide the word
	.int xt_rbracket                               // enter the compiler
	// unreachable
	.int xt_exit

defword ";", 1+F_IMMEDIATE, semicolon
	.int xt_shown                                  // make the word shown
	.int xt_lit, xt_exit, xt_comma                 // compile exit code
	.int xt_bracket                                // enter the immediate interpreter
	// unreachable
	.int xt_exit                                   

defword "header", 6, header                        // ( a u -- )
	.int xt_align                                  // align compilation pointer
	.int xt_here                                   // here = link field address
	.int xt_latest, xt_fetch, xt_comma             // link field points to previous word
	.int xt_latest, xt_store                       // make this link field address the latest word
	.int xt_name_comma                             // copy the word's name
	.int xt_exit

defword "create:", 7, create_colon                 // ( -- ) name ( -- a )
	.int xt_word, xt_header                        // ( a u ) get word name input
	.int xt_lit, enter_variable, xt_comma          // make this word push it's parameter field
	.int xt_exit

defword "does>", 5, does
	.int xt_r_from, xt_latest, xt_to_params, xt_store
	.int xt_exit

defword "variable", 8, variable
	.int xt_create, xt_lit, 0, xt_comma
	.int xt_exit

defword "constant", 8, constant
	.int xt_create, xt_comma
	.int xt_lit, enter_constant, xt_latest, xt_to_xt, xt_store
	.int xt_exit

defword "name,", 5, name_comma                     // ( a c -- ) compile name field
	.int xt_dup, xt_c_comma
	.int xt_swap, xt_over                          // ( c a c1 )
copy_loop:
	.int xt_dup, xt_zero_branch
	label copy_done
	.int xt_swap, xt_dup, xt_fetch, xt_c_comma     // copy one char from a and increment a
	.int xt_one_plus
	.int xt_swap, xt_one_minus                     // decrement c1
	.int xt_branch
	label copy_loop
copy_done:
	.int xt_drop, xt_drop                          // ( c )
	.int xt_lit, NAME_LEN, xt_minus                      // number of remaining spaces in the name field
blank_loop:                                        // compile <c> blank spaces after the name
	.int xt_dup, xt_zero_branch
	label blank_done
	.int xt_lit, ' ', xt_c_comma
	.int xt_one_minus
	.int xt_branch
	label blank_loop
blank_done:
	.int xt_exit

defword "aligned", 7, aligned                      // ( a1 -- a2 )
	.int xt_lit, 3, xt_add, xt_lit, -4, xt_and     // a2 = (a1 + (4 - 1)) & -4;
	.int xt_exit

defword "align", 5, align                          // ( -- ) align here
	.int xt_here, xt_aligned, xt_h, xt_store
	.int xt_exit

defword "here", 4, here                     // value
	.int xt_h, xt_fetch
	.int xt_exit

defword "[", 1+F_IMMEDIATE, bracket         // ( -- ) interpreter
	.int xt_lit, FALSE, xt_state, xt_store
interpret_loop:
	.int xt_word, xt_two_dup                // ( a u a u )
	.int xt_find                            // ( a u xt|0 )
	.int xt_dup, xt_zero_branch
	label interpret_not_found
	.int xt_nip, xt_nip                     // ( xt )
	.int xt_execute
	.int xt_branch
	label interpret_loop
interpret_not_found:                        // convert to number
	.int xt_drop                            // ( a u 0 -- a u )
	.int xt_str_to_n                        // ( a u -- n u2|0 )
	.int xt_drop                            // ( n ) ignore errors
	.int xt_branch
	label interpret_loop
	// no exit

defword "]", 1, rbracket                    // ( -- ) compiler
	.int xt_lit, TRUE, xt_state, xt_store
compile_loop:
	.int xt_word, xt_two_dup                // ( a u a u )
	.int xt_find                            // ( a u xt|0 )
	.int xt_dup, xt_zero_branch             // ( a u xt|0 )
	label compile_not_found
	.int xt_nip, xt_nip                     // ( xt )
	.int xt_dup, xt_to_link, xt_question_immediate
	.int xt_zero_branch
	label compile_not_immediate
	.int xt_execute
	.int xt_branch
	label compile_loop
compile_not_immediate:
	.int xt_comma
	.int xt_branch
	label compile_loop
compile_not_found:                          // convert to number
	.int xt_drop                            // ( a u 0 -- a u )
	.int xt_str_to_n                        // ( a u -- n u2|0 )
	.int xt_drop                            // ( n ) ignore errors
	.int xt_lit, xt_lit, xt_comma           // compile "lit"
	.int xt_comma                           // compile n
	.int xt_branch
	label compile_loop
	// no exit

defword "[']", 1+F_IMMEDIATE, bracket_tick  // ( -- xt )
	.int xt_word, xt_find, xt_to_xt
	.int xt_exit

defword "'", 1, tick                        // ( -- xt )
	.int xt_bracket_tick
	.int xt_exit

defword "postpone", 8+F_IMMEDIATE, postpone // ( -- )
	.int xt_bracket_tick, xt_comma
	.int xt_exit

defword "allot", 5, allot                   // ( u -- a )
	.int xt_here, xt_dup
	.int xt_plus, xt_h, xt_store
	.int xt_exit

defword ">link", 5, to_link           // ( xt -- link )
	.int xt_lit, 36, xt_minus
	.int xt_exit

defword ">name", 5, to_name            // ( link -- a )
	.int xt_lit, 4, xt_plus
	.int xt_exit

defword ">xt", 3, to_xt               // ( a -- xt )
	.int xt_lit, 1+4+NAME_LEN, xt_plus
	.int xt_exit

defword ">params", 7, to_params       // ( a -- a2 )
	.int xt_lit, 40, xt_plus
	.int xt_exit

defword "?hidden", 7, question_hidden  // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_lit, F_HIDDEN, xt_and, xt_bool
	.int xt_exit

defword "?immediate", 10, question_immediate  // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_lit, F_IMMEDIATE, xt_and, xt_bool
	.int xt_exit

defword "count", 5, count              // ( a -- a u )
	.int xt_dup
	.int xt_one_plus, xt_swap
	.int xt_c_fetch, xt_lit, F_LENMASK, xt_and
	.int xt_exit

defword "mod", 3, mod                 // ( n m -- r ) division remainder
	.int xt_slash_mod, xt_drop
	.int xt_exit

defword "/", 1, slash                 // ( n m -- q ) division quotient
	.int xt_slash_mod, xt_nip
	.int xt_exit

defword "1+", 2, one_plus
	.int xt_lit, 1, xt_plus
	.int xt_exit

defword "1-", 2, one_minus
	.int xt_lit, 1, xt_minus
	.int xt_exit

defword "str>n", 5, str_to_n          // ( a u1 -- n u2 ), assume u1 > 0
	.int xt_over, xt_fetch
	.int xt_lit, '-', xt_equals
	.int xt_zero_branch
	label n_unsigned
	.int xt_one_minus 
	.int xt_swap
	.int xt_one_plus
	.int xt_swap                      // ( a+1 u1-1 )
	.int xt_str_to_d                  // ( d u2 )
	.int xt_nip
	.int xt_swap                      // ( u2 u3 )
	.int xt_negate                    // ( u2 n )
	.int xt_swap                      // ( n u2 )
	.int xt_exit
n_unsigned:
	.int xt_str_to_d                  // ( d u2 )
	.int xt_nip                       // ( n u2 )
	.int xt_exit

defword "n>str", 5, n_to_str
	.int xt_lit, 0, xt_less, xt_zero_branch
	label n_positive                  // n < 0
	.int xt_negate, xt_u_to_str       // ( a u )
	.int xt_swap, xt_one_minus        // prepend minus sign to a
	.int xt_lit, '-', xt_over, xt_store
	.int xt_swap, xt_one_plus         // increment length u
	.int xt_exit
n_positive:                           // n >= 0
	.int xt_u_to_str
	.int xt_exit

defword "u.", 2, u_dot                // ( u -- )
	.int xt_u_to_str, xt_tell
	.int xt_exit

defword ".", 1, dot                   // ( n -- )
	.int xt_n_to_str, xt_tell
	.int xt_exit

defword "?", 1, question              // ( a -- )
	.int xt_fetch, xt_u_dot
	.int xt_exit

defword "c?", 2, c_question           // ( a -- )
	.int xt_c_fetch, xt_dot
	.int xt_exit
	
defword "tell", 4, tell               // ( a u -- )
tell_loop:
	.int xt_dup, xt_zero_branch
	label tell_done
	.int xt_one_minus
	.int xt_swap, xt_dup
	.int xt_c_fetch, xt_emit, xt_one_plus
	.int xt_swap, xt_branch
	label tell_loop
tell_done:
	.int xt_exit

defword "hidden", 6+IMMEDIATE, hidden              // ( -- )
	.int xt_latest, xt_fetch, xt_hide
	.int xt_exit

defword "hide", 4, hide                            // ( a -- )
	.int xt_to_name, xt_dup, xt_c_fetch
	.int xt_lit, F_HIDDEN, xt_and
	.int xt_swap, xt_c_store
	.int xt_exit

defword "shown", 5+IMMEDIATE, shown                // ( -- )
	.int xt_latest, xt_fetch, xt_show
	.int xt_exit

defword "show", 4, show                            // ( a -- )
	.int xt_to_name, xt_dup, xt_c_fetch
	.int xt_lit, F_HIDDEN, xt_not, xt_and
	.int xt_swap, xt_c_store
	.int xt_exit

defword "id.", 3, id_dot                           // ( link -- )
	.int xt_to_name, xt_count, xt_tell
	.int xt_exit

defword "BL", 2, bl
	.int xt_lit, ' '
	.int xt_exit

defword "bool", 4, bool                // ( x -- f )
	.int xt_zero_branch
	label bool_done
	.int xt_true
	.int xt_exit
bool_done:
	.int xt_false
	.int xt_exit

defword "compare", 7, compare          // ( a1 u1 a2 u2 -- f ) compare counted strings
	.int xt_rot, xt_swap
	.int xt_two_dup, xt_equal, xt_zero_branch
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
	.int xt_lit, TRUE
	.int xt_exit
compare_neq:
	.int xt_drop, xt_drop, xt_drop
	.int xt_lit, FALSE
	.int xt_exit
compare_len_neq:
	.int xt_two_drop, xt_two_drop
	.int xt_lit, FALSE
	.int xt_exit

defword "find", 4, find                // ( a u -- link | 0 )
	.int xt_latest                     // ( a u link )
find_link:
	.int xt_dup, xt_zero_branch
	label find_no_find
	.int xt_dup, xt_question_hidden
	.int xt_not, xt_zero_branch
	label find_next
	.int xt_two_dup                    // ( a u link u link )
	.int xt_to_name, xt_count, xt_nip, xt_equals
	.int xt_zero_branch
	label find_link_loop               // ( a u link )
	.int xt_dup, xt_two_swap           // ( link link a u )
	.int xt_rot                        // ( link a u link )
	.int xt_count                      // ( link a u a2 u2 )
	.int xt_two_over                   // ( link a u a2 u2 a u )
	.int xt_compare                    // ( link a u f )
	.int xt_invert, xt_zero_branch
	label find_found
	.int xt_rot                        // ( a u link )
find_next:
	.int xt_fetch                      // ( a u *link )
	.int xt_branch
	label find_link
find_found:
	.int xt_drop, xt_drop
	.int xt_exit
find_no_find:
	.int xt_nip, xt_nip                // ( a u 0 -- 0)
	.int xt_exit

defword "scan-in", 7, scan_in          // ( c -- a ) scan chars in input buffer
	.int xt_to_in, xt_fetch
	.int xt_tib, xt_plus               // ( c a )
scan_char:
	.int xt_buffer_in
	.int xt_two_dup                    // ( c a c a )
	.int xt_fetch                      // ( c a c c2 )
	.int xt_equals, xt_not
	.int xt_zero_branch                // ( c a )
	label scan_complete
	.int xt_one_plus                   // ( c a+1 )
	.int xt_branch
	label scan_char
scan_complete:
	.int xt_nip                        // ( c a -- a )
	.int xt_exit

defword "skip-in", 7, skip_in          // ( c -- a ) skip chars in input buffer
	.int xt_to_in, xt_fetch
	.int xt_tib, xt_plus               // ( c a )
skip_char:
	.int xt_buffer_in
	.int xt_two_dup                    // ( c a c a )
	.int xt_fetch                      // ( c a c c2 )
	.int xt_equals, xt_zero_branch     // ( c a )
	label skip_complete
	.int xt_one_plus                   // ( c a+1 )
	.int xt_branch
	label skip_char
skip_complete:
	.int xt_nip                        // ( c a -- a )
	.int xt_exit

defword "key", 3, key                  // ( -- c )
	// TODO get char
	.int xt_lit, 0
	.int xt_dup, xt_emit               // echo
	.int xt_exit

defword "newline?", 8, newline_question // ( c -- f )
	.int xt_dup
	.int xt_lit, 10, xt_equals
	.int xt_swap
	.int xt_lit, 13, xt_equals
	.int xt_or
	.int xt_exit

defword "accept", 6, accept            // ( a u1 -- u2 )
	.int xt_dup, xt_to_r               // ( a u1 ) R: ( u1 )
accept_loop:
	.int xt_dup, xt_zero_branch
	label accept_done
	.int xt_swap                       // ( u a )
	.int xt_key                        // ( u a c )
	.int xt_newline_question           
	.int xt_equals, xt_zero_branch
	label accept_char                  // [enter] causes end of input
	.int xt_drop                       // ( u a )
	.int xt_swap                       // ( a u )
	.int xt_branch                     
	label accept_done
accept_char
	.int xt_over                       // ( u a c a )
	.int xt_c_store                    // ( u a )
	.int xt_one_plus                   // ( u a+1 )
	.int xt_swap
	.int xt_one_minus                  // ( a+1 u-1 )
	.int xt_branch
	label accept_loop
accept_done:
	.int xt_r_from                     // ( a u -- a u u1 ) R: ( u1 -- )
	.int xt_swap, xt_minus             // ( a u2 )
	.int xt_nip                        // ( u2 )
	.int xt_exit

defword "refill", 6, refill            // ( -- ) refill tib
	.int xt_tib
	.int xt_lit, TIB_SIZE
	.int xt_accept   // ( u )
	.int xt_num_tib, xt_store
	.int xt_lit, 0, xt_to_in, xt_store

defword "buffer-in", 9, buffer_in      // ( -- ) make sure the input buffer is not exhausted
	.int xt_to_in, xt_fetch
	.int xt_num_tib
	.int xt_more, xt_zero_branch
	label buffer_in_full
	.int xt_refill
buffer_in_full:
	.int xt_exit

defword "word", 4, word                // ( -- a u )
	.int xt_bl, xt_skip                // ( a )
	.int xt_bl, xt_scan                // ( a a2 )
	.int xt_over, xt_swap              // ( a a a2 )
	.int xt_minus                      // ( a u ) u is word len
	.int xt_exit

defword "quit", 4, quit
	.int xt_r_zero, xt_rsp_store       // clear return stack
	.int xt_bracket                    // interpret
	// no exit

