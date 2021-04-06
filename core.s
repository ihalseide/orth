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
// * Unfortunately, forth variables have to go through 2 layers of indirection to be accessed directly in assembly code. One layer is the forth variable layer, and the other is the assembler literal pool

// Constants

	// Linux file stream descriptors
	.set stdin, 0
	.set stdout, 1
	.set stderr, 2

	// System call numbers
	.set sys_exit, 1
	.set sys_read, 3
	.set sys_write, 4

	// Word bitmasks
	.set F_IMMEDIATE, 0b10000000
	.set F_HIDDEN,    0b01000000
	.set F_LENMASK,   0b00111111

	// Boolean flags
	.set F_TRUE, -1
	.set F_FALSE, 0

// Static variables

	.set RSTACK_SIZE, 4 * 256

// The macro for defining a word header

	// Previous word link pointer for while it's assembling word defs
	.set link, 0

	.macro define name, namelen, flags=0, xt_label, code_label
	.data
	.align 2
	.global def_\xt_label
def_\xt_label:
	.word link               // link to previous word in the dictionary data
	.set link,def_\xt_label
	.byte \namelen+\flags    // The name field, including the length byte
	.ascii "\name"           // is 32 bytes long
	.space 31-\namelen
	.data
	.align 2
	.global xt_\xt_label
xt_\xt_label:                   // The next 4 byte word/cell will be the code field
	.word \code_label
	.endm

// Data section and word headers

 	.data

	// Static buffer for the input buffer
	.align 2
the_input_buffer:
	.space 256 // chars


	// Static buffer for the return stack, which grows downwards in memory
	.align 2
rstack_end:
	.space RSTACK_SIZE
rstack_start:


	define "true", 4, , true, doconst
	// -1 constant true
	.word -1

	define "false", 5, , false, doconst
	// 0 constant false
	.word 0

	define "S0", 2, , s_zero, doconst
val_s_zero:
	.word 0                                // MUST be initialized later

	define "R0", 2, , r_zero, doconst
	.word rstack_start

	define "state", 5, , state, dovar
	// 0 variable state
val_state:
	.word 0

	define "h", 1, , h, dovar
	// &dictionary_end variable h
val_h:
	.word dictionary_space

	define "base", 4, , base, dovar
	// 10 variable base
val_base:
	.word 10

	define "latest", 6, , latest, dovar
	// &the_final_word variable latest
val_latest:
	.word the_final_word

	define ">in", 3, , to_in, dovar
	// 0 variable >in
val_to_in:
	.word 0

	define "tib", 3, , tib, doconst
	// &the_input_buffer constant tib
val_tib:
	.word the_input_buffer

	define "#tib", 4, , num_tib, dovar
	// 0 variable #tib
val_num_tib:
	.word 0

	define "F_IMMEDIATE", 11, , f_immediate, doconst
	.word F_IMMEDIATE

	define "F_HIDDEN", 8, , f_hidden, doconst
	.word F_HIDDEN

	define "F_LENMASK", 9, , f_lenmask, doconst
	.word F_LENMASK

	define "'", 1, F_IMMEDIATE, tick, docol
	// ( -- xt )
	.word xt_bl
	.word xt_word
	.word xt_find
	.word xt_drop
	.word xt_exit

	define "exit", 4, , exit, exit
	// ( -- ) exit and return from the current forth word

	define "lit", 3, , lit, lit
	// ( -- x )

	define "literal", 7, F_IMMEDIATE, literal, docol
	// ( x -- )
	.word xt_lit, xt_lit
	.word xt_comma, xt_comma
	.word exit

	define ",", 1, , comma, comma
	// ( x -- )

	define "c,", 2, , c_comma, c_comma
	// ( c -- )

	define "immediate", 9, , immediate, docol
	// ( -- )
	.word xt_latest, xt_fetch
	.word xt_lit, 4
	.word xt_plus
	.word xt_dup
	.word xt_c_fetch
	.word xt_lit, F_IMMEDIATE
	.word xt_and
	.word xt_swap
	.word xt_c_store
	.word xt_exit

	define ":", 1, , colon, docol
	// ( -- ) create a colon defined word
	.word xt_create                               // Create a new header for the next word.
	.word xt_lit, docol                           // Make "docolon" be the runtime code for the new header.
	.word xt_here
	.word xt_lit, 4
	.word xt_minus
	.word xt_store
	.word xt_right_bracket                        // Enter into compile mode
	.word xt_exit

	define ";", 1, F_IMMEDIATE, semicolon, docol
	// ( -- ) end a colon definition while still in compile mode
	.word xt_lit, xt_exit     // append "exit" to the word definition
	.word xt_comma
	.word xt_bracket          // Enter into immediate mode
	.word xt_exit

	define "postpone", 8, F_IMMEDIATE, postpone, docol
	// ( -- ) compile the following word
	.word xt_state, xt_fetch          // ( f )
	.word xt_zero_branch, 2f          // Must be in compile mode
	.word xt_bl
	.word xt_word
	.word xt_find
	.word xt_zero_branch, 1f          // ( xt ) must find
	.word xt_comma
	.word xt_exit
1:	.word xt_semicolon_cancel
	.word xt_quit
2:	.word xt_exit

	define ";cancel", 7, , semicolon_cancel, docol
	.word xt_latest, xt_fetch       // forget the partially compiled definition
	.word xt_dup
	.word xt_h, xt_store
	.word xt_fetch
	.word xt_latest, xt_store
	.word xt_bracket                // enter immediate mode
	.word xt_exit

	define "]", 1, , right_bracket, docol
	// ( -- ) enter compile mode
	.word xt_lit, -1, xt_state, xt_store
	.word xt_exit

	define "[", 1, F_IMMEDIATE, bracket, docol
	// ( -- ) enter immediate mode
	.word xt_lit, 0, xt_state, xt_store
	.word xt_exit

	define "create", 6, , create, create
	// ( -- ) create a word header with the next word in the input stream as a name

	define "constant", 8, , constant, docol
	// ( x -- )
	.word xt_create           // create the first part of the header
	.word xt_comma            // compile x to the data field
	.word xt_lit, doconst     // make 'doconst' be the codeword
	.word xt_latest
	.word xt_fetch
	.word xt_lit, 36
	.word xt_plus
	.word xt_store
	.word xt_exit

	define "here", 4, , here, docol
	// ( -- c-addr ) c-addr is the data space pointer
	.word xt_h, xt_fetch
	.word xt_exit

	define "allot", 5, , allot, docol
	// ( n -- )
	// Reserve n chars of data space.
	.word xt_here
	.word xt_plus
	.word xt_h, xt_store
	.word xt_exit

	define "interpret", 9, , interpret, docol
	// ( -- )
	// TODO:
	.word xt_bye

	define "quit", 4, , quit, docol
	// ( -- )
	.word xt_r_zero             // clear the return stack
	.word xt_rsp_store
	.word xt_bracket            // enter immediate mode
	.word xt_num_tib, xt_fetch  // force input to be received later by interpret
	.word xt_to_in, xt_store
1:	.word xt_interpret          // start interpreting
	.word xt_branch, 1b
	// no exit because there is no return stack

	define "if", 2, F_IMMEDIATE, if, docol
	// ( -- addr )
	.word xt_lit, xt_zero_branch
	.word xt_comma
	.word xt_h, xt_fetch
	.word xt_lit, 0
	.word xt_comma
	.word xt_exit

	define "then", 4, F_IMMEDIATE, then, docol
	// ( addr -- )
	.word xt_h, xt_fetch
	.word xt_store
	.word xt_exit

	define "else", 4, F_IMMEDIATE, else, docol
	// ( addr1 -- addr2 ) where: addr1= the previous if branch address, and addr2= the else branch address
	.word xt_lit, xt_branch
	.word xt_comma
	.word xt_h, xt_fetch                         // (prev-if prev-else )
	.word xt_lit, 0
	.word xt_comma
	.word xt_h, xt_fetch                         // (prev-if prev-else h )
	.word xt_rot                                 // ( prev-else h prev-if )
	.word xt_store                               // ( prev-else )
	.word xt_exit

	define "PSP@", 4, , psp_fetch, psp_fetch
	// ( -- addr )

	define "PSP!", 4, , psp_store, psp_store
	// ( addr -- )

	define "RSP@", 4, , rsp_fetch, rsp_fetch
	// ( -- addr )

	define "RSP!", 4, , rsp_store, rsp_store
	// ( addr -- )

	define "id.", 3, , id_dot, docol
	// ( xt -- )
	.word xt_lit, -32
	.word xt_plus
	.word xt_dup
	.word xt_lit, 1
	.word xt_plus
	.word xt_swap
	.word xt_fetch
	.word xt_f_lenmask
	.word xt_and
	.word xt_tell
	.word xt_exit

	define "and", 3, , and, do_and
	// ( n1 n2 -- n1&n2 )

	define "xor", 3, , xor, xor
	// ( n1 n2 -- n1^n2 )

	define "or", 2, , or, do_or
	// ( x y -- x|y ) bitwise or

	define "invert", 6, , invert, invert
	// ( n1 -- n2 )

	define "*", 1, , star, multiply
	// ( n1 n2 -- n1*n2 )

	define "+", 1, , plus, add
	// ( n1 n2 -- n1+n2 )

	define "mod", 3, , mod, mod
	// ( n1 n2 -- n1%n2 )

	define "-", 1, , minus, sub
	// ( n1 n2 -- n1-n2 )

	define "/", 1, , slash, divide
	// ( n1 n2 -- n1/n2 )

	define "/mod", 4, , slash_mod, divmod

	define "<", 1, , less, less
	// ( n1 n2 -- n1<n2 )

	define "=", 1, , equals, equals
	// ( n1 n2 -- n1=n2 )

	define ">", 1, , more, more
	// ( n1 n2 -- n1>n2 )

	define ">number", 7, , to_number, to_number
	// ( d1 addr1 u1 -- d2 addr2 u2 )

	define "!", 1, , store, store
	// ( x addr -- )

	define "@", 1, , fetch, fetch
	// ( addr -- x )

	define "c!", 2, , c_store, c_store
	// ( c addr -- )

	define "c@", 2, , c_fetch, c_fetch
	// ( addr -- c )

	define "accept", 6, , accept, accept
	// ( addr u1 -- u2 )
	// addr: the address to store characters into
	// u1: the number of characters to accept from input
	// u2: the number of characters actually received (will not be greater than len)

	define "count", 5, , count, count
	// ( addr1 -- addr2 u )

	define "drop", 4, , drop, drop
	// ( x -- )

	define "dup", 3, , dup, dup
	// ( x -- x x )

	define "over", 4, , over, over
	// ( x y -- x y x )

	define "rot", 3, , rot, rot
	// ( x y z -- y z x )

	define "swap", 4, , swap, swap
	// ( x y -- y x )

	define ">R", 2, , to_r, to_r
	// ( x -- R: -- x )

	define "R>", 2, , r_from, r_from
	// ( -- x R: x -- )

	define "execute", 7, , execute, execute
	// ( xt -- )

	define "branch", 6, , branch, branch

	define "0branch", 7, , zero_branch, zero_branch

	define "find", 4, , find, find
	// ( addr -- addr 0 | xt -1 | xt 1 )

	define "emit", 4, , emit, emit
	// ( c -- )

	define "BL", 2, , bl, docol
	// ( -- c )
	.word xt_lit, ' '
	.word xt_exit

	define "CR", 2, , cr, docol
	// ( -- )
	.word xt_lit, '\n', xt_emit
	.word xt_exit

	define "tell", 4, , tell, tell
	// ( addr u -- )

	define "word", 4, , word, word
	// ( c -- addr )

	define "aligned", 7, , aligned, docol
	// ( c-addr -- addr ) align an address to a cell
	.word xt_lit, 3
	.word xt_plus
	.word xt_lit, 3
	.word xt_invert
	.word xt_and
	.word xt_exit

	define "break", 5, , break, break
	// ( -- )

the_final_word:

	define "bye", 3, , bye, bye
	// ( -- )

dictionary_space:
	.space 2048

// Variable literal pool for assembly code to reference.

	.text
	.align 2
var_s_zero:
	.word val_s_zero
var_state:
	.word val_state
var_h:
	.word val_h
var_base:
	.word val_base
var_latest:
	.word val_latest
var_to_in:
	.word val_to_in
var_num_tib:
	.word val_num_tib
const_tib:
	.word val_tib

// Begin the main assembly code.

	.global _start
_start:
	ldr r11, =rstack_start   // init return stack
	ldr r0, =var_s_zero      // init parameter stack
	ldr r0, [r0]
	str sp, [r0]
	ldr r10, =start_code     // init the system
	b next
start_code:
	.word xt_quit


docol:
	str r10, [r11, #-4]!    // Save the return address to the return stack
	add r10, r8, #4         // Get the next instruction
	// fall-into 'next'


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


bye:
	mov r0, #0           // successful exit code
exit_program:
	mov r7, #sys_exit
	swi #0


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


rot:                        // rot ( x y z -- y z x )
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
	sub r9, r0, r9    // r9 = r0 - r9
	b next


multiply:
	pop {r0}
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	b next


equals:
	pop {r0}
	cmp r9, r0
	moveq r9, #F_TRUE
	movne r9, #F_FALSE
	b next


less:
	pop {r0}
	cmp r0, r9      // r9 < r0
	movlt r9, #F_TRUE
	movge r9, #F_FALSE
	b next


more:
	pop {r0}
	cmp r0, r9      // r9 > r0
	movgt r9, #F_TRUE
	movle r9, #F_FALSE
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


store:
	pop {r0}
	str r0, [r9]
	pop {r9}
	b next


fetch:
	ldr r9, [r9]
	b next


c_store:
	pop {r0}
	strb r0, [r9]
	pop {r9}
	b next


c_fetch:
	mov r0, r0
	ldrb r9, [r9]
	b next


branch:                       // note: not a relative branch!
	ldr r10, [r10]
	b next


zero_branch:                  // note: not a relative branch
	cmp r9, #0
	ldreq r10, [r10]          // Set the IP to the next codeword if 0,
	addne r10, #4             // or increment IP otherwise
	pop {r9}                  // DO pop the stack
	b next


execute:
	mov r8, r9        // r8 = the xt
	pop {r9}          // pop the stack
	ldr r0, [r8]      // r0 = code address
	bx r0


count:
	mov r0, r9           // push addr + 1
	add r0, #1
	push {r0}
	ldrb r9, [r9]        // push length, which is addr[0]
	b next


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


c_comma:
	ldr r0, =var_h
	ldr r0, [r0]
	cpy r1, r0
	ldr r0, [r0]

	strb r9, [r0, #1]!      // This line is the only difference with "comma" (see above)
	str r0, [r1]

	pop {r9}
	b next


tell:                       // tell ( c-addr u -- ) u: string length. Emit a counted string
	mov r2, r9          // len = u
	pop {r1}            // buf = [pop]

	mov r7, #sys_write
	mov r0, #stdout
	swi #0

	pop {r9}
	b next


emit:                       // emit ( char -- )
	ldr r1, =var_h          // store the char temporarily in pad
	ldr r1, [r1]
	ldr r1, [r1]
	strb r9, [r1]

	mov r7, #sys_write      // call write(...) with the pad address
	mov r0, #stdout
	mov r2, #1
	swi #0

	pop {r9}
	b next


divide:           // / ( n m -- q ) division quotient
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r2
	b next


divmod:          // /mod ( n m -- r q ) division remainder and quotient
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	b next


mod:              // mod ( n m -- r ) division remainder
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r0
	b next


psp_fetch:
	push {r9}
	mov r9, sp
	b next


psp_store:
	mov sp, r9
	b next


rsp_fetch:
	push {r9}
	mov r9, r11
	b next


rsp_store:
	mov r11, r9
	pop {r9}
	b next


break:
	mov r0, r0
	b next


find:                           // ( addr -- addr2 0 | xt 1 | xt -1 ) 1=immediate, -1=not immediate
	ldr r0, =var_latest     // r0 = current word link field address
	ldr r0, [r0]            // (r0 will be correctly dereferenced again in the 1st iteration of loop #1)

	ldrb r1, [r9]           // r1 = input str len
1:                              // Loops through the dictionary linked list.
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq 3f

	ldrb r2, [r0, #4]       // get word length+flags byte

	tst r2, #F_HIDDEN       // skip hidden words
	bne 1b

	and r2, #F_LENMASK
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

	mov r9, #1              // At this point, the word's name matches the input string
	ldr r1, [r0, #4]        // get the word's length byte again
	tst r1, #F_IMMEDIATE    // return -1 if it's not immediate
	negne r9, r9

	add r0, #36             // push the word's CFA to the stack
	push {r0}
	b next
3:                          // A word with a matching name was not found.
	push {r9}               // push string address
	eor r9, r9              // return 0 for no find
	b next


create:
	// TODO:
	b next


to_number:                 // ( d1 addr1 u1 -- d2 addr2 u2 )
	pop {r0}               // r0 = character pointer / address
	pop {r1}               // r1 = high part of the double
	pop {r2}               // r2 = low part of the double
	ldr r3, =var_base      // r3 = base
	ldr r3, [r3]
	ldr r3, [r3]
_loop:
	cmp r9, #0             // Check if there are no more chars left to convert
	beq _loop_done
	ldrb r4, [r0], #1      // r4 = *char_ptr++
	sub r4, #48            // make '0' --> 0

	cmp r4, #9             // checks for letter digits...
	ble _digit
	cmp r4, #49            // make letters be upper case
	subge r4, #32
	sub r4, #7
	cmp r4, #10            // char must not be between '9' and 'A'...
	blt _dig_err
	cmp r4, #35
	blt _dig_err
_digit:
	cmp r4, #0             // digit must not be negative
	blt _dig_err    
	cmp r4, r3             // digit must be less than the base
	bge _dig_err
	mul r1, r3             // high *= base
	umull r5, r6, r2, r3   // low *= base, r6 = overflow
	add r1, r6             // high += overflow
	add r2, r4, r5         // low += base
	sub r9, #1
	b _loop
_dig_err:
_loop_done:
	push {r2}              // push the results
	push {r1}
	push {r0}
	b next


accept:                   // ( c-addr u -- u2 )
	mov r7, #sys_read     // make a read system call
	mov r0, #stdin
	pop {r1}              // buf = {pop}
	mov r2, r9            // count = TOS
	swi #0

	cmp r0, #0            // the call returns a negative number upon an error,
	movlt r0, #0          // so zero chars were received

	mov r9, r0            // push number of chars received
	b next


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
word_skip:                  // skip leading whitespace
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

	ldr r0, =const_tib      // get length inside the input buffer (includes the skipped whitespace)
	ldr r0, [r0]
	sub r1, r0

	ldr r0, =var_to_in      // store back to the variable ">in"
	ldr r0, [r0]
	str r1, [r0]

	b next                  // TOS (r9) has been pointing to the pad addr the whole time


	// Function for integer division modulo
	// Copied from the project https://github.com/organix/pijFORTHos (which itself is a copy)
	// Arguments: r0 = numerator, r1 = denominator
	// Returns: r0 = remainder, r1 = denominator, r2 = quotient
fn_divmod:
	mov r3, r1
	cmp r3, r0, LSR #1
1:	movls r3, r3, LSL #1
	cmp r3, r0, LSR #1
	bls 1b
	mov r2, #0
2:	cmp r0, r3
	subcs r0, r0, r3
	adc r2, r2, r2
	mov r3, r3, LSR #1
	cmp r3, r1
	bhs 2b
	bx lr
