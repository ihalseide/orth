// ----- Constants -----

.set F_IMMEDIATE, 0b10000000
.set F_HIDDEN,    0b01000000
.set F_LENMASK,   0b00011111

.set NAME_LEN, 31
.set TIB_SIZE, 1024

.set RSTACK_SIZE, 2048

// ----- Macros -----

// The inner interpreter
.macro NEXT
	ldr r8, [r10], #4       // r10 = the virtual instruction pointer
	ldr r0, [r8]            // r8 = xt of current word
	bx r0                   // (r0 = temp)
.endm

// Define a code word (primitive)
.set link, 0
.macro defcode name, len, label, flags=0
	.data
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags         // name field
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
.macro defword name, len, label, flags=0
	.data
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags        // name field
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
var_base:    .int 10

var_h:       .int data_end
var_state:   .int 0
var_latest:  .int the_last_word

var_s_zero:  .int 0 // initialized later
var_r_zero:  .int 0 // initialized later

var_to_in:   .int 0
var_num_tib: .int 0

// Errors vectored execution
var_eundefc: .int xt_undefined_comp
var_eundef: .int xt_undefined
var_edivzero: .int xt_div_zero

.align 2
input_buffer: .space TIB_SIZE

.space RSTACK_SIZE
.align 2
rstack_start:

.align 2
dictionary:

// ----- Core assembly code -----

.text

.align 2

.global _start
_start:
	/* Save parameter stack base */
	ldr r0, =var_s_zero
	str sp, [r0]
	/* Init return stack */
	ldr r11, =rstack_start
	ldr r1, =var_r_zero
	str r11, [r1]
	/* Start up Forth */
	ldr r10, =init_code
	NEXT
init_code:
	.int xt_quit

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

defcode "bye", 3, bye
	eor r0, r0
	mov r7, #1
	swi #0
	// unreachable

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
	mov r9, r11
	NEXT

defcode "RP!", 3, rp_store
	mov r11, r9
	pop {r9}
	NEXT

defcode ">R", 2, to_r     // ( -- x R: x -- )
	str r9, [r11, #-4]!
	pop {r9}
	NEXT

defcode "R>", 2, r_from   // ( x -- R: -- x )
	push {r9}
	ldr r9, [r11], #4
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

defcode "+", 1, plus     // ( x1 x2 -- x3 )
	pop {r1}             // r1 = x1
	add r9, r1
	NEXT

defcode "-", 1, minus    // ( x1 x2 -- x3 )
	pop {r1}             // r1 = x1
	sub r9, r1, r9       // x3 = x1 - x2
	NEXT

defcode "*", 1, star     // ( x1 x2 -- x3 )
	pop {r1}             // r1 = x1
	mov r2, r9           // r2 = x2
	mul r9, r1, r2       // x3 = x1 * x2
	NEXT

defcode "lsl", 3, lsl
	pop {r0}
	lsl r9, r0
	NEXT

defcode "lsr", 3, lsr
	pop {r0}
	lsr r9, r0
	NEXT

defcode "=", 1, equals   // ( x1 x2 -- f )
	pop {r0}
	cmp r9, r0
	eor r9, r9           // 0 for false
	mvneq r9, r9         // invert for true
	NEXT

defcode "<>", 2, not_equals   // ( x1 x2 -- f )
	pop {r0}
	cmp r9, r0
	eor r9, r9           // 0 for false
	mvnne r9, r9         // invert for true
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
	ldrb r9, [r9]
	NEXT

defcode "branch", 6, branch // branch ( -- ) relative branch
	ldr r0, [r10]
	add r10, r0
	NEXT

defcode "0branch", 7, zero_branch // 0branch ( x -- )
	cmp r9, #0
	ldreq r0, [r10]                  // Set the IP to the next codeword if 0,
	addeq r10, r0
	addne r10, #4                    // but increment IP otherwise.
	pop {r9}                         // discard TOS
	NEXT

defcode "execute", 7, execute        // ( xt -- )
	mov r8, r9                       // r8 = the xt
	ldr r0, [r8]                     // (indirect threaded)
	pop {r9}                         // pop the stack
	bx r0
	// no next

defcode "key", 3, key   // ( -- c )
	push {r9}           // push down TOS
	mov r7, #3          // read(fd, buf, len)
	eor r0, r0          // stdin
	push {r0}           // make buffer room
	mov r1, sp
	mov r2, #1          // 1 char
	swi #0
	pop {r9}            // move it to the TOS
	NEXT

defcode "emit", 4, emit              // ( c -- )
	mov r7, #4                       // write(fd, buf, len)
	mov r0, #1                       // stdout
	strb r9, [sp, #-1]               // use stack as the write buffer
	sub r1, sp, #1                  // buf = sp-1
	cpy r2, r0
	swi #0
	pop {r9}
	NEXT

defcode "cmove", 5, cmove            // ( a1 a2 u -- ) move u chars from a1 to a2
	eor r0, r0                       // r0 = index
	pop {r2}                         // r2 = a2
	pop {r1}                         // r1 = a1
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

defcode "cmove>", 6, cmove_from      // ( a1 a2 u -- )
	mov r2, r9                       // r2 = index
	pop {r1}                         // r1 = a2
	pop {r0}                         // r0 = a1
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

defcode "(/mod)", 6, paren_slash_mod // ( n m -- r q ) division remainder and quotient
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	NEXT

defcode "tib-size", 8, tib_size // constant
	push {r9}
	mov r9, #TIB_SIZE
	NEXT

defcode "tib", 3, tib          // constant
	push {r9}
	ldr r9, =input_buffer
	NEXT

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

defcode "str>ud", 5, str_to_ud // ( a u1 -- ud u2 )
	pop {r0}                  // r0 = addr
	eor r1, r1                // r1 = d.high
	eor r2, r2                // r2 = d.low
	ldr r4, =var_base         // get the current number base
	ldr r4, [r4]
	b to_num_test
to_num1:
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
	sub r3, #'0'              // convert char digit to value
	cmp r3, r4                // if digit >= base then it's an error
	bge to_num_done
	cmp r3, #0
	blt to_num_done
	mul r5, r1, r4            // multiply the high-word by the base
	mov r1, r5
	/* UMULL{S}{cond} RdLo, RdHi, Rn, Rm */
	umull r5, r6, r2, r4      // multiply the low-word by the base and carry into high word
	add r1, r6
	add r2, r5, r3            // add the digit value to the low word (no need to carry)
	sub r9, #1                // decrement length remaining
to_num_test:
	cmp r9, #0                // if length=0 then it's done converting
	bgt to_num1
to_num_done:                  // number conversion done
	push {r2}                 // push the low word
	push {r1}                 // push the high word
	NEXT

defcode "u>str", 5, u_to_str  // ( u1 -- a u2 )
	/* Get the pad address and make an index into it */
	mov r4, #0                // r4 = index
	ldr r5, =var_h
	ldr r5, [r5]              // r5 = here (temporary space to write the digits)
	add r5, #NAME_LEN+1       // leave a space for prefix minus sign
	/* Get the number base */
	ldr r6, =var_base         // r6 = number base
	ldr r6, [r6]
	/* Only proceed if the number base is valid */
	cmp r6, #1
	bgt good_base
	push {r6}
	eor r9, r9                // ( a 0 )
	NEXT
good_base:
	cmp r9, #0
	bne u_not_zero
	/* Write a 0 to the pad if u is 0 */
	mov r0, #'0'
	str r0, [r5]
	push {r5}
	mov r9, #1
	NEXT
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
base2:
	cmp r9, #0
	bne base2_body
	b base_done
base4_body:
	and r0, r9, #3
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #2
base4:
	cmp r9, #0
	bne base4_body
	b base_done
base8_body:
	and r0, r9, #7
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #3
base8:
	cmp r9, #0
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
	bne base_other_body
base_done:
	/* Reverse the pad array */
	mov r9, r4          // TOS = pad length
	eor r0, r0          // r0 = pad index #1
	sub r1, r4, #1      // r1 = pad index #2
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
	strb r2, [r5, r1]
	strb r3, [r5, r0]
	/* Move indices towards each other */
	add r0, #1
	sub r1, #1
reverse:
	cmp r0, r1
	ble reverse_body
	/* done, return */
	push {r5}       // second item on stack is the pad start address
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

defcode "max", 3, max                              // ( x1 x2 -- x1|x2 )
	pop {r0}
	cmp r9, r0
	movlt r9, r0
	NEXT

defcode "min", 3, min                              // ( x1 x2 -- x1|x2 )
	pop {r0}
	cmp r9, r0
	movgt r9, r0
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

defcode "true", 4, true
	push {r9}
	eor r9, r9
	mvn r9, r9
	NEXT

defcode "false", 5, false
	push {r9}
	eor r9, r9
	NEXT

defcode "#name", 5, num_name
	push {r9}
	mov r9, #NAME_LEN
	NEXT

defcode "eundef", 6, eundef
	push {r9}
	ldr r9, =var_eundef
	NEXT

defcode "eundefc", 7, eundefc
	push {r9}
	ldr r9, =var_eundefc
	NEXT

defcode "ediv0", 5, edivzero
	push {r9}
	ldr r9, =var_edivzero
	NEXT

// ----- High-level words -----

defword "literal", 7, literal, F_IMMEDIATE
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

defword "enterdoes", 9, enterdoes
	.int xt_lit, enter_does
	.int xt_exit

defword "accept", 6, accept          // ( a u1 -- u2 )
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

defword "type", 4, type              // ( a u -- )
type_char:
	.int xt_dup, xt_zero_branch
	label type_done
	.int xt_swap
	.int xt_dup, xt_c_fetch, xt_emit
	.int xt_one_plus
	.int xt_swap
	.int xt_one_minus
	.int xt_branch
	label type_char
type_done:
	.int xt_drop, xt_drop
	.int xt_exit

defword ";", 1, semicolon, F_IMMEDIATE
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

defword "link", 4, link                 // ( -- ) create link field
	.int xt_here, xt_align, xt_h, xt_store
	.int xt_here                        // here = this new link address
	.int xt_latest, xt_fetch, xt_comma  // link field points to previous word
	.int xt_latest, xt_store            // make this link field address the latest word
	.int xt_exit

defword "header:", 7, header      // ( -- ) create link and name field in dictionary
	.int xt_link
	.int xt_lit, xt_question_separator
	.int xt_word                  // ( a )
	.int xt_dup, xt_dup
	.int xt_c_fetch               // ( a a len )
	.int xt_num_name, xt_min
	.int xt_swap, xt_c_store      // ( a )
	.int xt_num_name, xt_one_plus, xt_plus
	.int xt_h, xt_store
	.int xt_exit

defword "pass", 4, pass                            // ( -- ) "no-op"
	.int xt_exit

defword "create:", 7, create_colon                 // ( -- ) name ( -- )
	.int xt_header
	.int xt_enterdoes, xt_comma
	.int xt_lit, xt_pass, xt_cell, xt_plus
	.int xt_comma
	.int xt_exit

defword "does>", 5, does
	.int xt_r_from                                 // get the calling word's next code
	.int xt_latest
	.int xt_to_params, xt_store                    // make the created word use that code
	.int xt_exit

defword "->variable:", 11, to_variable_colon       // ( x -- ) variable initialized to x
	.int xt_header                                 // get word name input
	.int xt_entervariable, xt_comma                // make this word push it's parameter field
	.int xt_comma
	.int xt_exit

defword "variable:", 9, variable_colon   // ( -- )
	.int xt_lit, 0
	.int xt_to_variable_colon
	.int xt_exit

defword "constant:", 9, constant_colon   // ( x -- ) constant with value x
	.int xt_header                       // get word name input
	.int xt_enterconstant, xt_comma      // make this word push it's parameter field
	.int xt_comma
	.int xt_exit

defword "align", 5, align                          // ( -- )
	.int xt_lit, 3, xt_plus
	.int xt_lit, 3, xt_not, xt_and                 // a2 = (a1+(4-1)) & ~(4-1);
	.int xt_exit

defword "here", 4, here // current compilation address
	.int xt_h, xt_fetch
	.int xt_exit

defword "[", 1, bracket, F_IMMEDIATE        // ( -- ) interpret mode
	.int xt_state, xt_fetch
	.int xt_zero_branch
	label already_interpret
	.int xt_false, xt_state, xt_store
	.int xt_quit
already_interpret:
	.int xt_exit

defword "]", 1, rbracket                    // ( -- ) compiler
	.int xt_true, xt_state, xt_store
compile:
	.int xt_lit, xt_question_separator
	.int xt_word
	.int xt_ccount                      // ( a u )
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

defword ">link", 5, to_link           // ( xt -- link )
	.int xt_lit, 4+1+NAME_LEN, xt_minus
	.int xt_exit

defword ">name", 5, to_name            // ( link -- a )
	.int xt_lit, 4, xt_plus
	.int xt_exit

defword ">xt", 3, to_xt               // ( link -- xt )
	.int xt_lit, 4+1+NAME_LEN
	.int xt_plus
	.int xt_exit

defword ">params", 7, to_params       // ( link -- a2 )
	.int xt_lit, 4+1+NAME_LEN+4, xt_plus
	.int xt_exit

defword "?hidden", 7, question_hidden  // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_fhidden, xt_and, xt_bool
	.int xt_exit

defword "?immediate", 10, question_immediate  // ( link -- f )
	.int xt_to_name, xt_c_fetch
	.int xt_fimmediate, xt_and, xt_bool
	.int xt_exit

defword "count", 5, count       // ( a1 -- a2 u )
	.int xt_dup                 // ( a1 a1 )
	.int xt_lit, 4
	.int xt_plus, xt_swap       // ( a2 a1 )
	.int xt_fetch               // ( a2 c )
	.int xt_exit

defword "ccount", 6, ccount     // ( a1 -- a2 c )
	.int xt_dup                 // ( a1 a1 )
	.int xt_one_plus, xt_swap   // ( a2 a1 )
	.int xt_c_fetch             // ( a2 c )
	.int xt_exit

// compile-only
defword "[cstr]", 6, cstr_lit // ( R: a2 -- a1 c1 R: a3 ) load a short embedded string
	.int xt_r_from              // ( a2 R: )
	.int xt_ccount              // ( a1 c1 )
	.int xt_two_dup, xt_plus    // ( a1 c1 a3 )
	.int xt_align               // round up to the next cell
	.int xt_to_r                // ( a1 c1 R: a3 )
	.int xt_exit

defword "/mod", 4, slash_mod          // ( n m -- r q )
	.int xt_dup, xt_zero_branch
	label div0
	.int xt_paren_slash_mod
	.int xt_exit
div0:
	.int xt_edivzero, xt_fetch, xt_execute
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

defword "str>d", 5, str_to_d          // ( a u1 -- d u2 ), assume u1 > 0
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

defword "d>n", 3, d_to_n              // ( d -- n )
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label d_to_n_positive
	.int xt_negate
d_to_n_positive:
	.int xt_exit

defword "n>str", 5, n_to_str          // ( n -- a u )
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

defword "hide", 4, hide               // ( link -- )
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

defword "bool", 4, bool                // ( x -- f )
	.int xt_zero_branch
	label bool_done
	.int xt_true
	.int xt_exit
bool_done:
	.int xt_false
	.int xt_exit

defword "compare", 7, compare          // ( a1 u1 a2 u2 -- f ) compare counted strings
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

defword "find", 4, find                // ( a u -- link | 0 )
	.int xt_latest, xt_fetch           // ( a u link )
find_link:
	.int xt_dup
	.int xt_zero_branch
	label find_no_find                 // ( a u link )
	.int xt_dup, xt_question_hidden
	.int xt_not, xt_zero_branch
	label find_skip_hidden
	.int xt_dup, xt_two_swap, xt_rot   // ( link a1 len1 link )
	.int xt_to_name, xt_ccount         // ( link a1 len1 a2 len2 )
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

defword "immediate", 9, immediate, F_IMMEDIATE
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fimmediate, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

// TODO: other input sources
defword "refill", 6, refill       // ( -- f )
	.int xt_tib                   // ( a )
	.int xt_tib_size              // ( a u1 )
	.int xt_accept                // ( u2 )
	.int xt_num_tib, xt_store     // ( )
	.int xt_lit, 0
	.int xt_to_in, xt_store
	.int xt_true
	.int xt_exit

// TODO: other input sources
defword "source-id", 9, source_id // ( -- 0|-1|id )
	.int xt_lit, 0
	.int xt_exit

// TODO: other input sources
defword "source", 6, source       // ( -- a u )
	.int xt_to_in, xt_fetch
	.int xt_tib, xt_plus
	.int xt_num_tib, xt_fetch
	.int xt_to_in, xt_fetch
	.int xt_minus
	.int xt_exit

// TODO: other input sources
defword "source!", 7, source_store  // ( a1 -- )
	.int xt_dup
	.int xt_source
	.int xt_minus_rot               // ( a1 u a1 a )
	.int xt_minus
	.int xt_less
	.int xt_zero_branch             // ( a1 )
	label source_fine
	.int xt_refill                  // ( a1 f )
	.int xt_two_drop
	.int xt_exit
source_fine:
	.int xt_tib, xt_minus           // ( u )
	.int xt_to_in, xt_store
	.int xt_exit

defword "?separator", 10, question_separator    // ( c -- f ) whitespace predicate
	.int xt_dup, xt_lit, 0, xt_equals, xt_swap  // ( f c )
	.int xt_dup, xt_lit, 9, xt_equals, xt_swap  // ( f f c )
	.int xt_dup, xt_lit, 10, xt_equals, xt_swap // ( f f f c )
	.int xt_dup, xt_lit, 13, xt_equals, xt_swap // ( f f f c )
	.int xt_lit, 32, xt_equals                  // ( f f f f )
	.int xt_or, xt_or, xt_or, xt_or             // ( f )
	.int xt_exit

// Warning: unbounded
defword "skip", 4, skip       // ( a1 p -- a2 ) from char address a1, find 1st char that doesn't match p
skip_loop:
	.int xt_over, xt_c_fetch  // ( a p -- a p c )
	.int xt_over              // ( a p c p )
	.int xt_execute           // ( a p f )
	.int xt_zero_branch       // ( a p )
	label skip_done
	.int xt_swap              // a+1 -> a
	.int xt_one_plus
	.int xt_swap              // ( a p )
	.int xt_branch
	label skip_loop
skip_done:
	.int xt_drop              // ( a2 p -- a2 )
	.int xt_exit

// Warning: unbounded
defword "scan", 4, scan       // ( a1 p -- a2 ) start at char address a1, find 1st char that matches p
scan_loop:
	.int xt_over, xt_c_fetch  // ( a p -- a p c )
	.int xt_over              // ( a p c p )
	.int xt_execute           // ( a p f )
	.int xt_zero_equals       
	.int xt_zero_branch       // ( a p )
	label scan_done
	.int xt_swap              // a+1 -> a
	.int xt_one_plus
	.int xt_swap              // ( a c1 )
	.int xt_branch
	label scan_loop
scan_done:
	.int xt_drop              // ( a2 p -- a2 )
	.int xt_exit

defword "nskip", 5, nskip     // ( a1 u p -- a2 ) starting at address a1, skip at most u chars until char  matches p
nskip_loop:
	.int xt_over, xt_zero_branch
	label nskip_done1
	.int xt_rot
	.int xt_two_dup           // ( u p a p a )
	.int xt_c_fetch
	.int xt_swap              // ( u p a c p )
	.int xt_execute           // ( u p a f )
	.int xt_zero_branch
	label nskip_done2
	.int xt_one_plus          // ( u p a )
	.int xt_minus_rot         // ( a u p )
	.int xt_swap, xt_one_minus
	.int xt_swap
	.int xt_branch
	label nskip_loop
nskip_done2:                  // ( u p a )
	.int xt_nip, xt_nip
	.int xt_exit
nskip_done1:
	.int xt_two_drop          // ( a2 p -- a2 )
	.int xt_exit


defword "nscan", 5, nscan     // ( a1 u p -- a2 ) starting at address a1, scan at most u chars for a char that matches p
nscan_loop:
	.int xt_over, xt_zero_branch
	label nscan_done1
	.int xt_rot
	.int xt_two_dup           // ( u p a p a )
	.int xt_c_fetch
	.int xt_swap              // ( u p a c p )
	.int xt_execute           // ( u p a f )
	.int xt_not, xt_zero_branch
	label nscan_done2
	.int xt_one_plus          // ( u p a )
	.int xt_minus_rot         // ( a u p )
	.int xt_swap, xt_one_minus
	.int xt_swap
	.int xt_branch
	label nscan_loop
nscan_done2:                  // ( u p a )
	.int xt_nip, xt_nip
	.int xt_exit
nscan_done1:
	.int xt_two_drop          // ( a2 p -- a2 )
	.int xt_exit

defword "3dup", 4, three_dup  // ( x1 x2 x3 -- x1 x2 x3 x1 x2 x3 )
	.int xt_dup
	.int xt_two_over
	.int xt_rot
	.int xt_exit

defword "word", 4, word           // ( p -- a1 )
word_input:
	.int xt_source                // ( p a u )
	.int xt_dup, xt_zero_equals
	.int xt_zero_branch           // ( p a u )
	label word_copy
	.int xt_two_drop              // ( p )
	.int xt_refill, xt_drop       // ( p )
	.int xt_branch
	label word_input
word_copy:                        // ( p a u )
	.int xt_rot                   // use nskip and nscan to extract the word
	.int xt_three_dup
	.int xt_nskip                 // ( a u p a2 )
	.int xt_swap, xt_to_r         // ( a u a2 R: p )
	.int xt_rot, xt_two_dup       // ( u a2 a a2 a R: p )
	.int xt_minus, xt_nip         // ( u a2 u R: p )
	.int xt_rot
	.int xt_swap, xt_minus        // ( a2 u R: p )
	.int xt_over, xt_swap         // ( a2 a2 u R: p )
	.int xt_r_from
	.int xt_nscan                 // ( a2 a3 )
	.int xt_dup, xt_source_store
	.int xt_over, xt_minus        // ( a2 u )
	.int xt_tuck
	.int xt_here, xt_one_plus
	.int xt_swap
	.int xt_cmove                 // ( u )
	.int xt_here, xt_c_store      // ( )
	.int xt_here                  // ( a1 )
	.int xt_exit

defword "type?", 5, type_question
	.int xt_type
	.int xt_lit, '?', xt_emit
	.int xt_space
	.int xt_exit

defword "undefined-comp", 14, undefined_comp // ( a u -- )
	.int xt_latest, xt_fetch, xt_forget
	.int xt_type_question
	.int xt_refill, xt_drop         // discard the rest of input
	.int xt_quit

defword "undefined", 9, undefined   // ( a u -- )
	.int xt_type_question           // prompt
	.int xt_refill, xt_drop         // discard the rest of input
	.int xt_quit

defword "div0", 4, div_zero         // ( x 0 -- )
	.int xt_two_drop
	.int xt_cstr_lit
	.byte 8
	.ascii "#DIV/0! "
	.align 2
	.int xt_type
	.int xt_quit

defword "forget", 6, forget           // ( link -- )
	.int xt_dup
	.int xt_fetch, xt_latest, xt_store
	.int xt_h, xt_store
	.int xt_exit	

the_last_word:

defword "quit", 4, quit                 // ( -- R: i*x -- )
	.int xt_r_zero, xt_rp_store         // clear return stack
	.int xt_bracket
quit_interpret:
	.int xt_lit, xt_question_separator
	.int xt_word
	.int xt_ccount                      // ( a u )
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

.align 2

data_end:

	.space 4096

