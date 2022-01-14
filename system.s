	// TODO: consider the stack getting filled up by calls to `:` and `;`

	.arm

	// Constants:
	.equ F_IMMEDIATE, 0b10000000 // immediate word flag bit
	.equ F_HIDDEN,    0b01000000 // hidden word flag bit
	.equ F_COMPILE,   0b00100000 // compile-only word flag bit
	.equ F_LENMASK,   0b00011111 // == 31
	.equ TIB_SIZE, 1024          // (bytes) size of terminal input buffer
	.equ TOB_SIZE, 1024          // (bytes) size of terminal output buffer
	.equ RSTACK_SIZE, 512*4      // (bytes) size of the return stack
	.equ PSTACK_SIZE,  64*4      // (bytes) size of the data stack
	.equ PAD_OFFSET, 256         // (byes) offset between H and PAD addresses

	// Register name aliases:
	// * R0-R7 = scratch registers
	// * R8 = current execution token (XT)
	// * R9 = top element of the stack
	// * R10 = virtual instruction pointer (VIP)
	// * R11 = return stack pointer (RP)
	// * R12 = 
	// * R13 = stack pointer (SP)
	tos    .req r9   // Top of stack register
	rp .req r11  // Return stack pointer
	xt     .req r8   // Current execution token address
	vip    .req r10  // (virtual) instruction pointer

	// Macros:

	.set link, 0

	// Push to return stack
	.macro rpush reg
		str \reg, [rp, #-4]!
	.endm

	// Pop from return stack
	.macro rpop reg
		ldr \reg, [rp], #4
	.endm

	// The inner interpreter
	.macro NEXT
		ldr xt, [vip], #4 // vip = the virtual instruction pointer
		ldr r0, [xt]      // r8 = xt of current word
		bx r0             // (r0 = temp)
	.endm

	// Define an assembly word
// --- //
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
// --- //

	// Define a high-level word (indirect threaded)
// --- //
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
// --- //

	// Label for relative branches within "defword" macros
	// I think that a `.` means the current address
	.macro label name
		.int \name - .
	.endm

	// Data:

	.section .data
	.align 2

var_h: .int 0

var_state: .int 0

var_latest: .int 0

var_pad_index: .int 0

	.align 2
	.space PSTACK_SIZE
stack_start:

	.align 2
	.space RSTACK_SIZE
rstack_start:

	.align 2
dictionary:

	// Assembly code:

	.section .text
	.align 2

	.global _start
_start:
	b forth

	// Start up the interpreter
forth:
	ldr sp, =stack_start
	ldr rp, =rstack_start
	ldr vip, =_code_
	NEXT
_code_:
	.int xt_quit

	// The inner interpreter for forth words
	.align 2
	.global enter_colon
enter_colon:
	rpush vip       // Save the return address to the return stack
	add vip, xt, #4 // Get the next instruction
	NEXT

	.global enter_var
enter_var:    // A word whose parameter list is a 1-cell value
	push {tos}
	add tos, xt, #4 // Push the address of the value
	NEXT

	.global enter_const
enter_const:      // A word whose parameter list is a 1-cell value
	push {tos}
	ldr tos, [xt, #4] // Push the value
	NEXT

	// Subroutine for integer division and modulo
	// This algorithm for unsigned DIVMOD is extracted from
	// 'ARM Software Development Toolkit User Guide v2.50' published by ARM in 1997-1998
	// args: r0=numerator, r1=denominator
	// returns: r0=remainder, r1 = denominator, r2=quotient
	// There is no need to save any registers because this subroutine just uses R0-R3
fn_divmod:
	// +++
	// custom sanity check: if denominator is zero, then return
	tst r1, #0           
	eoreq r2, r2
	bxeq lr
	// +++
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

	defcode "here", 4, here
	push {tos}
	ldr tos, =var_h
	NEXT

	// Compilation / interpretation state
	defcode "state", 5, state
	push {tos}
	ldr tos, =var_state
	NEXT

	// Latest defined word
	defcode "latest", 6, latest
	push {tos}
	ldr tos, =var_latest
	NEXT

	// Compilation "here" address
	// (variable that holds the current compilation address)
	defcode "h", 1, h
	push {tos}
	ldr tos, =var_h
	NEXT

	defcode "exit", 4, exit
	rpop vip
	NEXT

	// ( -- x )
	defcode "[']", 3, lit
	push {tos}               // Push the next instruction value to the stack.
	ldr tos, [vip], #4
	NEXT

	// Compile a machine-word
	// ( x -- )
	defcode ",", 1, comma
	ldr r0, =var_h
	cpy r1, r0
	ldr r0, [r0]        // r0 = here
	str tos, [r0], #4    // *here = TOS
	str r0, [r1]        // H += 4
	pop {tos}
	NEXT

	// Compile char/byte
	// ( c -- )
	defcode "c,", 2, c_comma
	ldr r0, =var_h
	cpy r1, r0
	ldr r0, [r0]
	strb tos, [r0], #1     // *H = TOS
	str r0, [r1]          // H += 1
	pop {tos}
	NEXT

	// clear data stack
	defcode "clear", 5, clear
	ldr r13, =stack_start
	NEXT

	// clear return stack
	defcode "rclear", 6, rclear
	ldr rp, =rstack_start
	NEXT

	// ( -- x R: x -- )
	defcode "->R", 3, to_r
	rpush tos
	pop {tos}
	NEXT

	// ( x -- R: -- x )
	defcode "R->", 3, r_from
	push {tos}
	rpop tos
	NEXT

	// ( x1 -- x1 x1 )
	defcode "dup", 3, dup
	push {tos}
	NEXT

	// ( x -- )
	defcode "drop", 4, drop
	pop {tos}
	NEXT

	// ( x1 x2 -- x2 )
	defcode "nip", 3, nip
	pop {r0}
	NEXT

	// ( x1 x2 -- x2 x1 )
	defcode "swap", 4, swap
	pop {r0}
	push {tos}
	mov tos, r0
	NEXT

	// ( x1 x2 -- x1 x2 x1 )
	defcode "over", 4, over
	ldr r0, [sp]          // get a copy of the second item on stack
	push {tos}             // push TOS to the rest of the stack
	mov tos, r0            // TOS = copy of the second item from earlier
	NEXT

	// ( x1 x2 -- x2 x1 x2 )
	defcode "tuck", 4, tuck
	pop {r0}
	push {tos}
	push {r0}
	NEXT

	// ( x1 x2 x3 -- x2 x3 x1 )
	defcode "rot", 3, rot
	pop {r0}              // r0 = x2
	pop {r1}              // r1 = x1
	push {r0}
	push {tos}
	mov tos, r1            // TOS = x1
	NEXT

	// ( x1 x2 x3 -- x3 x1 x2 )
	defcode "-rot", 4, minus_rot
	pop {r0}                   // r0 = x2
	pop {r1}                   // r1 = x1
	push {tos}
	push {r1}
	mov tos, r0                 // TOS = x2
	NEXT

	// increment
	defcode "1+", 2, one_plus
	add tos, #1
	NEXT

	// decrement
	defcode "1-", 2, one_minus
	sub tos, #1
	NEXT

	// ( x1 x2 -- x3 )
	defcode "+", 1, plus
	pop {r1}         // r1 = x1
	add tos, r1
	NEXT

	// ( x1 x2 -- x3 )
	defcode "-", 1, minus
	pop {r1}          // r1 = x1
	sub tos, r1, tos    // x3 = x1 - x2
	NEXT

	// ( x1 x2 -- x3 )
	defcode "*", 1, star
	pop {r1}          // r1 = x1
	mov r2, tos        // r2 = x2
	mul tos, r1, r2    // x3 = x1 * x2
	NEXT

	// ( x1 x2 -- x3 ) where x3 = (x1 << x2)
	defcode "lsl", 3, lsl
	pop {r0}
	lsl r0, tos
	mov tos, r0
	NEXT

	// ( x1 x2 -- x3 ) where x3 = (x1 >> x2)
	defcode "lsr", 3, lsr
	pop {r0}
	lsr r0, tos
	mov tos, r0
	NEXT

	// ( x1 x2 -- f )
	defcode "=", 1, equals
	pop {r0}
	cmp tos, r0
	eor tos, tos         // 0 for false
	mvneq tos, tos       // invert for true
	NEXT

	// ( x1 x2 -- f )
	defcode "<>", 2, not_equals
	pop {r0}
	cmp tos, r0
	eor tos, tos    // 0 for false
	mvnne tos, tos  // invert for true
	NEXT

	// Flag if TOS is less than 2nd
	defcode "<", 1, less
	pop {r0}
	cmp r0, tos      // tos < r0
	eor tos, tos
	mvnlt tos, tos
	NEXT

	// Flag if TOS is greater than 2nd
	defcode ">", 1, more
	pop {r0}
	cmp r0, tos      // tos > r0
	eor tos, tos
	mvngt tos, tos
	NEXT

	defcode "and", 3, and
	pop {r0}
	and tos, tos, r0
	NEXT

	defcode "or", 2, or
	pop {r0}
	orr tos, tos, r0
	NEXT

	defcode "xor", 3, xor
	pop {r0}
	eor tos, tos, r0
	NEXT

	defcode "not", 3, not
	mvn tos, tos
	NEXT

	defcode "negate", 6, negate
	neg tos, tos
	NEXT

	// ( x a -- )
	defcode "!", 1, store
	pop {r0}
	str r0, [tos]
	pop {tos}
	NEXT

	// Add X to the value at address A
	// ( x a -- )
	defcode "+!", 2, plus_store
	pop {r0}
	ldr r1, [tos]
	add r0, r1
	str r0, [tos]
	pop {tos}
	NEXT

	// Write byte to memory
	// ( c a -- )
	defcode "c!", 2, c_store
	pop {r0}
	strb r0, [tos]
	pop {tos}
	NEXT

	// Fetch/read from memory
	// ( a -- x )
	defcode "@", 1, fetch
	ldr tos, [tos]
	NEXT

	// ( a -- c )
	defcode "c@", 2, c_fetch 
	ldrb tos, [tos]
	NEXT
	
	// relative branch
	// ( -- )
	defcode "branch", 6, branch
	ldr r0, [vip]
	add vip, r0
	NEXT

	// Branch if zero
	// ( x -- )
	defcode "0branch", 7, zero_branch
	cmp tos, #0
	ldreq r0, [vip]              // Set the IP to the next codeword if 0,
	addeq vip, r0
	addne vip, #4                // but increment IP otherwise.
	pop {tos}                     // discard TOS
	NEXT

	// ( xt -- )
	defcode "execute", 7, execute
	mov xt, tos
	ldr r0, [xt]  // (indirect threaded)
	pop {tos}     // pop the stack
	bx r0
	// Unreachable. No NEXT

	// Move u chars from a1 to (lower) a2
	// ( a1 a2 u -- )
	defcode "cmove", 5, cmove
	eor r0, r0 // r0 = index
	pop {r2}   // r2 = a2
	pop {r1}   // r1 = a1
	b cmove_check
cmove_body:
	ldrb r3, [r1, r0]
	strb r3, [r2, r0]
	add r0, #1
cmove_check:
	cmp r0, tos
	blt cmove_body
	pop {tos}
	NEXT

	// Move chars to higher memory
	// ( a1 a2 u -- )
	defcode "cmove>", 6, cmove_from 
	mov r2, tos // r2 = index
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
	pop {tos}
	NEXT

	// ( n m -- r q ) division remainder and quotient
	defcode "/mod", 4, slash_mod 
	mov r1, tos
	pop {r0}
	bl fn_divmod
	push {r0}
	mov tos, r2
	NEXT

	// ( n m -- q ) division remainder and quotient
	defcode "/", 1, slash 
	mov r1, tos
	pop {r0}
	bl fn_divmod
	mov tos, r2
	NEXT

	// ( n m -- r ) division remainder and quotient
	defcode "mod", 3, mod 
	mov r1, tos
	pop {r0}
	bl fn_divmod
	mov tos, r0
	NEXT

	// Convert to boolean
	//   0 -> 0
	//   n -> -1
	// ( x -- f )
	defword "bool", 4, bool
	tst tos, #0
	mvnne tos, #0
	NEXT

	// Convert string to natural number (0 or more)
	// Returns the number and then how many chars were left unconverted
	// ( string-addr:a len:u -- result:n remaining-chars:u )
	// n = 0;
	// while(rem > 0)
	// {
	// 	 d = read a;
	// 	 if (a < '0') break;
	// 	 if (a > '9') break;
	// 	 n = n * 10 + d;
	// 	 rem--;
	// 	 a++;
	// }
	// ( n rem )
	n    .req r0
	addr .req r1
	d    .req r2
	base .req r3
	defcode "str->nat", 8, str_to_nat
	mov r3, #10
	pop {addr}
str_to_nat$begin:
	cmp tos, #0
	ble str_to_nat$loop_end
	ldr d, [addr]
	cmp d, #'0'
	ble str_to_nat$loop_end
	cmp d, #'9'
	bgt str_to_nat$loop_end
	mov r4, n                // r4 = copy of n,
	mul n, r4, base          // because multiple src and dst need to be different
	add n, d
	sub tos, #1
	add addr, #1
	b str_to_nat$begin
str_to_nat$loop_end:
	push {n}
	NEXT
	.unreq n
	.unreq addr
	.unreq d
	.unreq base

	// Forth code:

	// ( x -- )
	defword "literal", 7, literal, F_COMPILE+F_IMMEDIATE 
	.int xt_lit, xt_lit, xt_comma
	.int xt_comma
	.int xt_exit

	// Get character from input
	// ( -- c )
	defword "getchar", 7, getchar
	//	TODO: not implemented yet
	.int xt_exit

	// Get string from input
	// ( n -- a n )
	defword "input", 5, input
	//	TODO: not implemented yet
	.int xt_exit

	// Emit character to output
	// ( c -- )
	defword "emit", 4, emit
	//	TODO: not implemented yet
	.int xt_exit

	// Display string to output
	// ( a n -- )
	defword "display", 7, display
	//	TODO: not implemented yet
	.int xt_exit

	// create link field
	defword "link", 4, link
	.int xt_here, xt_align, xt_h, xt_store
	.int xt_here                        // here = this new link address
	.int xt_latest, xt_fetch, xt_comma  // link field points to previous word
	.int xt_latest, xt_store            // make this link field address the latest word
	.int xt_exit

	// Pad words
	// ( -- a )
	defword "pad", 3, pad
	.int xt_here
	.int xt_lit, PAD_OFFSET
	.int xt_plus
	.int xt_exit

	// Get pad contents as string
	// ( -- a u )
	defword "pad-get", 7, pad_get
	.int xt_pad
	.int xt_dup, xt_pad_index, xt_plus
	.int xt_dup, xt_minus
	.int xt_exit

	// ( -- a )
	defword "pad-index", 11, pad_index
	.int xt_lit, var_pad_index
	.int xt_exit

	// Record a char to the pad
	// ( char -- )
	defword "->pad", 5, to_pad
	.int xt_pad
	.int xt_lit, var_pad_index
	.int xt_plus
	.int xt_store
	.int xt_exit

	defword "pad-clear", 9, pad_clear
	.int xt_lit, 0
	.int xt_lit, var_pad_index, xt_store
	.int xt_exit
	// End of pad words

	// Get space-delimited word from input
	// ( -- a u )
	defword "word", 4, word
word$begin1:
	.int xt_getchar, xt_dup            // ( c c )
	.int xt_lit, ' ', xt_equals, xt_not // ( c f )
	.int xt_zero_branch                // ( c )
	label word$begin1
word$begin2:                           // ( c )
	.int xt_dup, xt_to_pad             // ( c )
	.int xt_getchar, xt_dup            // ( c c )
	.int xt_lit, ' ', xt_equals         // ( c f )
	.int xt_zero_branch                // ( c )
	label word$begin2
	.int xt_drop                       // ( )
	.int xt_pad_get                    // ( a u ) 
	.int xt_exit

	// create link and name field in dictionary
	// ( -- )
	defword "header:", 7, header
	.int xt_link
	.int xt_word               // ( a u )
	.int xt_dup, xt_minus_rot  // ( u a u )
	.int xt_here               // ( u a u a )
	.int xt_swap               // ( u a a u )
	.int xt_cmove              // ( u )
	.int xt_here               // ( u a )
	.int xt_plus               // ( U )
	.int xt_h, xt_store        // ( )
	.int xt_exit

	// ( a1 -- a2 )
	defword "align", 5, align
	.int xt_lit, 3, xt_plus
	.int xt_lit, 3, xt_not, xt_and // a2 = (a1+(4-1)) & ~(4-1);
	.int xt_exit

	// End a colon definition
	defword ";", 1, semicolon, F_COMPILE+F_IMMEDIATE
	.int xt_lit, xt_exit, xt_comma      // compile exit code
	.int xt_latest, xt_fetch, xt_hide   // toggle the hide flag to show the word
	.int xt_bracket                     // enter the immediate interpreter
	// no xt_exit

	defword ":", 1, colon
	.int xt_header
	.int xt_lit, enter_colon, xt_comma        // make the word run docol
	.int xt_latest, xt_fetch, xt_hide   // hide the word
	.int xt_rbracket                    // enter the compiler
	// no exit

	// interpret mode
	// ( -- )
	defword "[", 1, bracket, F_COMPILE+F_IMMEDIATE
	.int xt_lit, 0, xt_state, xt_store   // interpret mode
	.int xt_quit

	// compiler
	// ( -- )
	defword "]", 1, rbracket
	.int xt_lit, -1, xt_state, xt_store  // compile mode
compile:
	.int xt_lit, ' '
	.int xt_word
	.int xt_count                       // ( a u )
	.int xt_over, xt_over
	.int xt_find, xt_dup
	.int xt_zero_branch                 // ( a u link|0 )
	label compile_no_find
	.int xt_nip, xt_nip                 // ( link )
	.int xt_dup, xt_question_immediate
	.int xt_zero_branch
	label compile_normal
	.int xt_to_xt
	.int xt_execute      // execute immediate word
	.int xt_branch
	label compile
compile_normal:
	.int xt_to_xt, xt_comma
	.int xt_branch
	label compile
compile_no_find:
	.int xt_drop
	.int xt_dup                    // ( a u a u )
	.int xt_str_to_nat             // ( a u n rem )
	.int xt_zero_branch
	label compile_number
	.int xt_drop, xt_drop, xt_drop
	.int xt_branch
	label compile
compile_number:
	.int xt_lit, xt_lit, xt_comma  // compiles "lit #"
	.int xt_comma
	.int xt_drop, xt_drop
	.int xt_branch
	label compile

	// ( link -- a )
	defword "def>name", 8, to_name
	.int xt_lit, 4, xt_plus
	.int xt_exit

	// ( xt -- link )
	defword "def>link", 8, to_link
	.int xt_lit, 4+1+F_LENMASK, xt_minus
	.int xt_exit

	// ( link -- xt )
	defword "def>xt", 6, to_xt
	.int xt_lit, 4+1+F_LENMASK
	.int xt_plus
	.int xt_exit

	// ( link -- a2 )
	defword "def>params", 10, to_params
	.int xt_lit, 4+1+F_LENMASK+4, xt_plus
	.int xt_exit

	// ( link -- f )
	defword "hidden?", 7, question_hidden
	.int xt_to_name, xt_c_fetch
	.int xt_lit, F_HIDDEN, xt_and, xt_bool
	.int xt_exit

	// Toggle a word's `hidden` flag
	// ( link -- )
	defword "hide", 4, hide
	// TODO: not implemented yet
	.int xt_exit

	// ( link -- f )
	defword "immediate?", 10, question_immediate
	.int xt_to_name, xt_c_fetch
	.int xt_lit, F_IMMEDIATE, xt_and, xt_bool
	.int xt_exit

	// Toggle a word's `immediate` flag
	defword "immediate", 9, immediate
	// TODO: not implemented yet
	.int xt_exit

	// Used in `find`
	// ( a -- a c )
	defword "count", 5, count
	.int xt_dup               // ( a1 a1 )
	.int xt_one_plus, xt_swap // ( a2 a1 )
	.int xt_c_fetch           // ( a2 c )
	.int xt_exit

	// Find words
	// ( a u -- link )
	defword "find", 4, find                
	.int xt_latest, xt_fetch
find$begin:
	// TODO: not implemented
	.int xt_exit

	// Report unknown word/number
	// ( a u -- )
	defword "report", 6, report
	.int xt_display
	.int xt_lit, '?', xt_emit
	.int xt_exit

	// Reset back to interpreter
	// (also clears return stack)
	defword "quit", 4, quit 
	.int xt_rclear
	.int xt_bracket
quit$begin:
	.int xt_word, xt_over, xt_over  // ( a u a u )
	.int xt_find, xt_dup            // ( a u X X )
	.int xt_zero_branch             // ( a u X )
	label quit$not_found
	.int xt_nip, xt_nip, xt_to_xt   // ( xt )
	.int xt_execute
	.int xt_branch
	label quit$begin
quit$not_found:
	.int xt_drop
	.int xt_over, xt_over           // ( a u a u )
	.int xt_str_to_nat              // ( a u N rem )
	.int xt_zero_branch             // ( a u N )
	label quit$number               // ( a u )
	.int xt_report                  // ( )
quit$number:
	.int xt_nip, xt_nip             // ( N )
	.int xt_branch
	label quit$begin

