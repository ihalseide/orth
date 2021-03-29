/* Linux file stream descriptors */
	.set stdin, 0
	.set stdout, 1
	.set stderr, 2

/* System call numbers */
	.set sys_exit, 1
	.set sys_read, 3
	.set sys_write, 4

/* Word bitmask flags */
	.set F_IMMEDIATE, 0b10000000
	.set F_HIDDEN,    0b01000000
	.set F_LENMASK,   0b00111111

/* Previous word link pointer for while it's assembling word defs */
	.set link,0

/* Macro for defining a word header in the data section */
	.macro define name, namelen, flags=0, label, codelabel
	.data
	.align 2
	.global def_\label
def_\label:
	.word link               // link to previous word in the dictionary data
	.set link,def_\label
	.byte \namelen+\flags    // The name field, including the length byte
	.ascii "\name"           // is 32 bytes long
	.space 31-\namelen
	.data
	.align 2
	.global xt_\label
xt_\label:                   // The next 4 byte word/cell will be the code field
	.word \codelabel
	.endm

/* Begin normal program data, which needs to be before the dictionary
 * because the dictionary will grow upwards in memory.
 */

	// DEBUG
	.data
	.align 2
docol_word_data:
	.word 0
	.align 2
docol_return_data:
	.word 0

	.data
	.align 2
emit_char_buf:
	.space 1

	// 256 cells for the return stack, which grows up
	.data
	.align 2
rstack_end:
	.space 1024
rstack_start:

	// 64 cells for the parameter stack, which grows up
	.data
	.align 2
pstack_end:
	.space 256
pstack_start:

	/* Terminal Input Buffer */
	.data
	.align 2
tib_start:
	.space 128
tib_end:

/* Begin word header definitions */

	.data
	.align 2

	define "!", 1, , store, store
	define "&", 1, , and, do_and
	define "(;code)", 7, , do_semi_code, do_semi_code
	define "*", 1, , multiply, multiply
	define "+", 1, , add, add
	define ",", 1, , comma, comma
	define "-", 1, , sub, sub
	define "/", 1, , divide, divide
	define "/mod", 4, , divmod, divmod
	define "0branch", 7, , zero_branch, zero_branch
	define "<", 1, , lt, lt
	define "=", 1, , equal, equal
	define ">", 1, , gt, gt
	define ">CFA", 4, , to_cfa, to_cfa
	define ">R", 2, , to_r, to_r
	define ">number", 7, , to_number, to_number
	define "@", 1, , fetch, fetch
	define "R>", 2, , r_from, r_from
	define "[", 1, F_IMMEDIATE, enter_immediate, enter_immediate
	define "^", 1, , xor, xor
	define "accept", 6, , accept, accept
	define "branch", 6, , branch, branch
	define "bye", 3, , bye, bye
	define "c!", 2, , cstore, cstore
	define "c@", 2, , cfetch, cfetch
	define "count", 5, , count, count
	define "drop", 4, , drop, drop
	define "dup", 3, , dup, dup
	define "emit", 4, , emit, emit
	define "execute", 4, , exec, exec
	define "exit", 4, , exit, exit
	define "find", 4, , find, find
	define "invert", 6, , invert, invert
	define "lit", 3, , lit, lit
	define "mod", 3, , mod, mod
	define "negate", 6, , negate, negate
	define "nip", 3, nip, nip
	define "no_rstack", 9, , no_rstack, no_rstack
	define "over", 4, , over, over
	define "rot", 3, , rot, rot
	define "swap", 4, , swap, swap
	define "tell", 4, , tell, tell
	define "word", 4, , word, word
	define "|", 1, , or, do_or

	define "state", 5, , state, dovar      // 0 variable state
val_state:
	.word 0

	define ">in", 3, , to_in, dovar        // 0 variable >in
val_to_in:
	.word 0

	define "#tib", 4, , num_tib, dovar     // 0 variable #tib
val_num_tib:
	.word 0

	define "tib", 3, , tib, doconst        // <tib address> const tib
val_tib:
	.word tib_start

	define "h", 2, , h, dovar              // <dictionary end> variable h
val_h:
	.word dictionary_space

	define "base", 4, , base, dovar        // 10 variable base
val_base:
	.word 10

	define "last", 4, , last, dovar        // <the final word> variable last
val_last:
	.word the_final_word

	// ( addr -- addr2 ) word address to length field address
	define ">LFA", 4, , to_lfa, docol
	.word xt_lit, 4, xt_add
	.word xt_exit

	// ( -- )
	define "immediate", 9, F_IMMEDIATE, immediate, docol
	.word xt_latest, xt_fetch, xt_to_lfa
	.word xt_dup, xt_cfetch
	.word xt_lit, F_IMMEDIATE, xt_and
	.word xt_swap, xt_cstore
	.word xt_exit

	define ":", 1, F_IMMEDIATE, colon, docol      // : ( -- )
	.word xt_create                               // Create a new header for the next word.
	.word xt_enter_compile                        // Enter into compile mode
	.word xt_lit, docol, xt_do_semi_code          // Make "docolon" be the runtime code for the new header.

	define "::", 1, , colon_colon, docol
	.word xt_colon, xt_immediate
	.word xt_exit

	define ";", 1, F_IMMEDIATE, semicolon, docol
	.word xt_lit, xt_exit
	.word xt_comma
	.word xt_enter_immediate
	.word xt_exit

	define "create", 6, , create, docol
	.word xt_h, xt_fetch
	.word xt_last, xt_fetch
	.word xt_comma
	.word xt_last, xt_store
	.word xt_lit, 32
	.word xt_word
	.word xt_count
	.word xt_add
	.word xt_h, xt_store
	.word xt_lit, 0, xt_comma
	.word xt_lit, dovar, xt_do_semi_code

	// ( x -- )
	define "constant", 5, , const, docol
	.word xt_create
	.word xt_comma
	.word xt_lit, doconst, xt_do_semi_code

	define "(compile)", , do_compile, docol // ( addr -- )
	.word xt_to_cfa
	.word xt_comma
	.word xt_exit

	define "]", 1, , enter_compile, docol
1:	.word xt_find
	
3:	.word branch, 1b

	define "cr", 2, , docol
	.word xt_lit, '\n', xt_emit
	.word xt_exit

	define "refill", 3, , refill, docol
	.word xt_num_tib, xt_fetch
	.word xt_to_in, xt_fetch
	.word xt_equal, xt_zero_branch, 1f
	.word xt_tib
	.word xt_lit, 50
	.word xt_accept
	.word xt_num_tib, xt_store
	.word xt_lit, 0
	.word xt_to_in, xt_store
1:	.word xt_exit

	define "interpret", 9, , interpret, docol
1:	
	.word xt_exit

the_final_word:

	define "quit", 4, , quit, docol
1:	.word xt_no_rstack
	.word xt_refill
	.word xt_interpret
	.word xt_dot_quote
	.byte 4
	.ascii "ok "
	.word xt_cr
	.word branch, 1b

dictionary_space:
	.space 2048

/* Addresses of variables in the data section */

	.text
	.align 2

var_state:
	.word val_state

var_to_in:
	.word val_to_in

const_num_tib:
	.word val_num_tib

var_tib:
	.word val_tib

var_h:
	.word val_h

var_base:
	.word val_base

var_last:
	.word val_last

/* Begin the main assembly code. */


	/* Main starting point. */
	.global _start
_start:
	mov r0, #42
	push {r0}

	ldr r11, =rstack_start      // Init the return stack.
	ldr sp, =pstack_start       // Init the parameter stack.

	ldr r1, =var_state          // Set state to 0 (interpreting)
	ldr r1, [r1]
	eor r0, r0
	str r0, [r1]

	ldr r0, =const_num_tib      // Copy value of "#tib" to ">in".
	ldr r0, [r0]
	ldr r0, [r0]
	ldr r1, =var_to_in
	ldr r1, [r1]
	str r0, [r1]

	ldr r10, =init_xt
	b next
init_xt:
	.word xt_interpret

docol_word:
	.word docol_word_data

docol_return:
	.word docol_return_data

docol:
	// DEBUG purposes
	ldr r0, =docol_word
	ldr r0, [r0]
	str r8, [r0]
	ldr r0, =docol_return
	ldr r0, [r0]
	str r10, [r0]
docol2:
	str r10, [r11, #-4]!    // Save the return address to the return stack
	add r10, r8, #4         // Get the next instruction

next:                       // The inner interpreter
	ldr r8, [r10], #4       // r10 = the virtual instruction pointer
	ldr r0, [r8]            // r8 = xt of current word
	bx r0


exit:                       // End a forth word.
	ldr r10, [r11], #4      // ip = pop return stack
	b next


dovar:                     // A word whose parameter list is a 1-cell value
	push {r9}              // Prepare a push for r9.
	add r9, r8, #4         // Push the address of the value
	b next


doconst:                   // A word whose parameter list is a 1-cell value
	push {r9}              // Prepare a push for r9.
	ldr r9, [r8, #4]       // Push the value
	b next


do_semi_code:             // (;code) - ( addr -- ) replace the xt of the word being defined with addr
	ldr r0, =var_last     // Get the latest word.
	ldr r0, [r0]
	add r0, #36           // Offset to Code Field Address.
	str r9, [r0]          // Store the code address into the Code Field.
	pop {r9}
	b next


bye:
exit_program:
	mov r0, #0
	mov r7, #sys_exit
	swi #0


lit:
	push {r9}            // Push to the stack.
	ldr r9, [r10], #4    // Get the next cell value and skip the IP over it.
	b next


comma:
	ldr r0, =var_h
	ldr r0, [r0]
	cpy r1, r0         // r1 = *h
	ldr r0, [r0]       // r0 = h

	str r9, [r0, #4]!  // *h = TOS
	str r0, [r1]       // h += 4b

	pop {r9}
	b next


find:                       // find - ( addr -- addr2 flag )
	ldr r0, =var_last       // r0 = current word link field address
	ldr r0, [r0]            // (r0 will be correctly dereferenced again in the 1st iteration of loop #1)

	ldrb r1, [r9]           // r1 = input str len
1:                          // Loops through the dictionary linked list.
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq 3f

	ldrb r2, [r0, #4]       // get word length+flags byte

	tst r2, #F_HIDDEN       // skip hidden words
	bne 1b

	and r2, #F_LENMASK
	// DEBUG
//	push {r0-r9}            // print out dictionary word temporarily
//	add r1, r0, #5
//	mov r0, #stdout
//	mov r7, #sys_write
//	swi #0
//	pop {r0-r9}
	cmp r2, r1              // compare the lengths
	bne 1b

	add r2, r0, #4          // r2 = start address of word name string buffer
	eor r3, r3              // r3 = 0 index
2:                 // Loops through both strings to test for equality.
	add r3, #1              // increment index (starts at index 1)
	ldrb r4, [r9, r3]       // compare input string char to word char
	ldrb r5, [r2, r3]
	cmp r4, r5
	bne 1b                  // if they are ever not equal, the strings aren't equal

	cmp r3, r1              // keep looping until the whole strings have been compared
	bne 2b

	// DEBUG
	push {r0-r11}
	mov r7, #sys_write
	mov r0, #stdout
	ldr r1, =yes_found_msg
	mov r2, #yes_found_msg_end-yes_found_msg
	swi #0
	pop {r0-r11}

	mov r9, #1              // At this point, the word's name matches the input string
	ldr r1, [r0, #4]        // get the word's length byte again
	tst r1, #F_IMMEDIATE    // return -1 if it's not immediate
	negne r9, r9

	add r0, #36             // push the word's CFA to the stack
	push {r0}
	b next
3:                          // A word with a matching name was not found.
	// DEBUG
	push {r0-r11}
	mov r7, #sys_write
	mov r0, #stdout
	ldr r1, =not_found_msg
	mov r2, #not_found_msg_end-not_found_msg
	swi #0
	pop {r0-r11}
	
	push {r9}               // push string address
	eor r9, r9              // return 0 for no find
	b next
	.align 2
not_found_msg: .ascii " word not found\n"
not_found_msg_end:
	.align 2
yes_found_msg: .ascii " found the word\n"
yes_found_msg_end:


	.align 2
drop:
	pop {r9}
	b next


swap:
	pop {r0}
	push {r9}
	mov r9, r0
	b next


dup:
	push {r9}
	b next

over:
	ldr r0, [r13]       // r0 = get the second item on stack
	push {r9}           // push TOS to the rest of the stack
	mov r9, r0          // TOS = r0
	b next

rot:
	pop {r0}            // pop y
	pop {r1}            // pop x
	push {r0}           // push y
	push {r9}           // push z
	mov r9, r1          // push x
	b next

to_r:
	str r9, [r11, #-4]!
	pop {r9}
	b next

r_from:
	push {r9}
	ldr r9, [r11], #4
	b next

add:
	pop {r0}
	add r9, r0
	b next

sub:
	pop {r0}
	sub r9, r9, r1
	b next

multiply:
	pop {r0}
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	b next

equal:
	pop {r0}
	cmp r9, r0
	moveq r9, #-1      // -1 = true
	movne r9, #0       //  0 = false
	b next

lt:
	pop {r0}
	cmp r9, r0
	movlt r9, #-1
	movge r9, #0
	b next

gt:
	pop {r0}
	cmp r9, r0
	movge r9, #-1
	movlt r9, #0
	b next

do_and:
	pop {r0}
	and r9, r9, r0
	b next

do_or:
	pop {r0}
	orr r9, r9, r0
	b next

xor:
	pop {r0}
	eor r9, r9, r0
	b next

invert:
	mvn r9, r9
	b next

negate:
	neg r9, r9
	b next

store:
	pop {r0}
	str r0, [r9]
	pop {r9}
	b next

fetch:
	ldr r9, [r9]
	b next


cstore:
	pop {r0}
	strb r0, [r9]
	pop {r9}
	b next


cfetch:
	ldrb r9, [r9]
	b next


branch:
	ldr r10, [r10]        // add 4 first or after or at all??
	b next


zero_branch:
	cmp r9, #0
	ldreq r10, [r10]
	addne r10, #4
	pop {r9}
	b next


exec:
	mov r8, r9        // r8 = the xt
	pop {r9}          // pop the stack
	ldr r0, [r8]      // r1 = code address
	bx r0


count:
	mov r0, r9          // push addr + 1
	add r0, #1
	push {r0}
	ldrb r9, [r9]        // push length, which is addr[0]
	and r9, #F_LENMASK
	b next


tell:
	mov r5, r9          // push addr + 1
	add r5, #1
	ldrb r9, [r9]        // push length, which is addr[0]
	and r9, #F_LENMASK
tell_char:
	cmp r9, #0
	beq tell_done

	mov r0, #stdout
	mov r1, r5
	mov r2, #1
	mov r7, #sys_write
	swi #0

	cmp r0, #-1
	beq exit_program

	add r5, #1
	sub r9, #1
	b tell_char
tell_done:
	pop {r9}
	b next


to_number:
	pop {r0}             // r0 = addr
	pop {r1}             // r1 = d.hi
	pop {r2}             // r2 = d.lo
	ldr r4, =var_base    // get the current number base
	ldr r4, [r4]
	ldr r4, [r4]
to_num1:
	cmp r9, #0           // if length=0 then done converting
	beq to_num4
	ldrb r3, [r0], #1    // get next char in the string
	cmp r3, #'a'          // if it's less than 'a', it's not lower case
	blt to_num2
	sub r3, #32          // convert the 'a'-'z' from lower case to upper case
to_num2:
	cmp r3, #'9'+1        // if char is less than '9' its probably a decimal digit
	blt to_num3
	cmp r3, #'A'          // its a character between '9' and 'A', which is an error
	blt to_num5
	sub r3, #7           // a valid char for a base>10, so convert it so that 'A' signifies 10
to_num3:
	sub r3, #48          // convert char digit to value
	cmp r3, r4           // if digit >= base then it's an error
	bge to_num5
	mul r5, r1, r4       // multiply the high-word by the base
	mov r1, r5
	mul r5, r2, r4       // multiply the low-word by the base
	mov r2, r5
	add r2, r2, r3       // add the digit value to the low word (no need to carry)
	sub r9, #1           // length--
	add r0, #1           // addr++
	b to_num1
to_num4:
	push {r2}            // push the low word
to_num5:
	push {r1}            // push the high word
	push {r0}            // push the string address
	b next

accept:                   // accept - ( addr len -- len2 )
	pop {r1}              // r1 = buffer address.

	mov r0, #stdin
	mov r2, r9            // r2 = count
	mov r7, #sys_read
	swi #0

	cmp r0, #-1           // read(...) returns -1 upon an error.
	beq exit_program

	mov r9, r0
	b next

word:                     // word - ( char -- addr )
	ldr r1, =var_tib      // r1 = r2 = tib
	ldr r1, [r1]
	mov r2, r1

	ldr r3, =var_to_in    // r1 += >in, so r1 = pointer into the buffer
	ldr r3, [r3]
	ldr r3, [r3]
	add r1, r3

	ldr r3, =const_num_tib  // r2 += #tib, so r2 = last char address in buffer
	ldr r3, [r3]
	ldr r3, [r3]
	add r2, r3

	mov r0, r9            // r0 = char

	ldr r9, =var_h        // push the dictionary pointer, which is used as a buffer area, "pad"
	ldr r9, [r9]          // r4 = r9 = h
	ldr r9, [r9]
	mov r4, r9
word_skip:                // skip leading whitespace
	cmp r1, r2            // check for if it reached the end of the buffer
	beq word_done

	ldrb r3, [r1], #1     // get next char
	cmp r0, r3
	beq word_skip
word_copy:
	strb r3, [r4, #1]!

	cmp r1, r2
	beq word_done

	ldrb r3, [r1], #1     // get next char
	cmp r0, r3
	bne word_copy
word_done:
	mov r3, #' '          // write a space to the end of the pad
	str r3, [r4]

	sub r4, r9            // get the length of the word written to the pad
	strb r4, [r9]         // store the length byte into the first char of the pad

	ldr r0, =var_tib      // get length inside the input buffer (includes the skipped whitespace)
	ldr r0, [r0]
	sub r1, r0

	ldr r0, =var_to_in    // store back to the variable ">in"
	ldr r0, [r0]
	str r1, [r0]

	b next                // TOS (r9) has been pointing to the pad addr the whole time

	// emit ( char -- )
emit:
	pop {r3}
	ldr r1, =emit_char_buf
	str r3, [r1]
	mov r0, #stdout
	mov r2, #1
	mov r7, #sys_write
	swi #0
	b next

	// ] ( -- )
enter_compile:               // Exit immediate mode and enter compile mode.
	ldr r0, =var_state
	mov r1, #-1              // true = -1 = compiling
	str r1, [r0]
	b next

	// [ ( -- )
enter_immediate:             // Exit compile mode and enter immediate mode.
	ldr r0, =var_state
	eor r1, r1               // false = 0 = not compiling
	str r1, [r0]
	b next

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


	// / ( n m -- q ) division quotient
divide:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r2
	b next


	// /mod ( n m -- r q ) division remainder and quotient
divmod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	b next


	// mod ( n m -- r ) division remainder
mod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r0
	b next


	// nip ( x y -- y )
	// equivalent to "swap drop"
nip:
	pop {r0}
	b next

no_rstack:
	ldr r11, =rstack_start      // Init or reset the return stack.
	b next
	
to_cfa:
	add r9, #36
	b next
	
