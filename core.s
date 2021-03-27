/* Word bitmask flags */
	.set F_LENMASK, 0b00111111
	.set F_IMMEDIATE, 0b10000000

/* Macro for defining a word header */
	.set link, 0
	.macro define name, len, flags=0, label
	.text
	.align 2
_def_\label:
	.word link
	.set link, _def_\label
	.byte \len+\flags
	.ascii "\name"
	.space 31-\len
	.align 2
	.global xt_\label
	.text
xt_\label: // The next 4 bytes should be the code field
	.endm

	.global _start
_start:                 // Main starting point.
	b quit

next:                   // The inner interpreter, next.
	ldr r8, [r10], #4   // r0 = ip, and ip = ip + 4. (SEGFAULT here)
	bx r8

/* : ( -- )
 * Colon will define a new word by adding it to the dictionary and by setting
 * the "last" word to be the new word
 */
	define ":", 1, F_IMMEDIATE, colon
	.word docol
	.word xt_lit, -1
	.word xt_state, xt_store       // Enter compile mode.
	.word xt_create                // Create a new header for the next word.
	.word xt_do_semi_code, docol   // Make "docolon" be the runtime code for the new header.
docol:
	str r10, [r11, #-4]!
	add r10, r0, #4
	b next

/* quit ( -- ) */
	define "quit", 4, , quit
	.word quit
quit:
	ldr r11, =stack_base    // Init the return stack.
	ldr sp, =stack_base     // Init the data stack.

	ldr r1, =val_state      // Set state to 0.
	eor r0, r0
	str r0, [r1]

	ldr r0, =var_num_tib      // Copy value of "#tib" to ">in".
	ldr r0, [r0]
	ldr r0, [r0]
	ldr r1, =var_to_in
	ldr r1, [r1]
	str r0, [r1]

	ldr r10, =xt_interpret   // Set the virtual instruction pointer to "interpret"
	b next

/* state ( -- addr )
 * Compiling or interpreting state.
 */
	define "state", 5, , state
	.word dovar
var_state:
	.word val_state
	.data
val_state:
	.word 0

/* >in ( -- addr )
 * Next character in input buffer.
 */
	define ">in", 3, , to_in
	.word dovar
var_to_in:
	.word val_to_in
	.data
val_to_in:
	.word 0

// #tib ( --  addr )
// Number of characters in the input buffer.
	define "#tib", 4, , num_tib
	.word dovar
var_num_tib:
	.word val_num_tib
	.data
val_num_tib:
	.word 0

// dp ( -- addr )
// First free cell in the dictionary (dictionary pointer).
	define "dp", 2, , dp
	.word dovar
var_dp:
	.word dictionary

// base ( -- addr )
// Address of the number read and write base.
	define "base", 4, , base
	.word dovar
var_base:
	.word val_base
	.data
val_base:
	.word 10
	
// last ( -- addr )
// Address of the last word defined.
	define "last", 4, , last
	.word dovar
var_last:
	.word val_last
	.data
val_last:
	.word the_final_word

// tib ( -- addr )
// Address of the input buffer.
// no "code" because its a constant and can be stored in section rodata
	define "tib", 3, , tib
	.word doconst
const_tib:
	.word val_tib
	.data
val_tib:
	.word addr_tib

/* ; ( -- )
 * Semicolon: complete the current forth word being compiled.
 */
	define ";", 1, F_IMMEDIATE, semicolon
	.word docol
	.word xt_lit, xt_exit                // Compile an exit code.
	.word xt_comma
	.word xt_lit, 0, xt_state, xt_store  // Change back to immediate mode.
	.word xt_exit                        // Actually exit this word.

/* create ( -- )
 *
 */
	define "create", 6, , create
	.word docol
	.word xt_dp, xt_fetch
	.word xt_last, xt_fetch
	.word xt_comma
	.word xt_last, xt_store
	.word xt_lit, 32
	.word xt_word
	.word xt_count
	.word xt_add
	.word xt_dp, xt_store
	.word xt_lit, 0
	.word xt_comma
	.word xt_do_semi_code
dovar:
	str r9, [r13, #-4]!    // Prepare a push for r9.
	mov r9, r8             // r9 = [XT + 4].
	add r9, #4             // (r9 should be an address).
	b next

// (;code) ( -- )
	define "(;code)", 7, , do_semi_code
	.word do_semi_code
do_semi_code:
	ldr r8, =var_last
	add r8, #36           // Offset to Code Field Address.
	str r10, [r8]         // Store Instruction Pointer into the Code Field.
	// TODO

/* const ( x -- )
 * Create a new constant word that pushes x, where the name of the constant is
 * taken from the input buffer.
 */
	define "const", 5, , const
	.word docol
	.word xt_create
	.word xt_comma
	.word xt_do_semi_code
doconst:                   // Runtime code for words that push a constant.
	str r9, [r13, #-4]!    // Push the stack.
	ldr r9, [r8, #4]       // Fetch the data, which is bytes 4 after the CFA.
	b next                 

// lit ( -- )
// Pushes the next value in the cell right after itself
	define "lit", 3, F_IMMEDIATE, lit
	.word lit
lit:
	str r9, [r13, #-4]!     // Push to the stack.
	ldr r9, [r10], #4       // Get the next cell value and put it in r9 while
	b next                  // also incrementing r10 by 4 bytes.

// , ( x -- )
// Comma compiles the value x to the dictionary
	define ",", 1, , comma
	.word comma
comma:
	ldr r8, =var_dp         // Set r8 to the dictionary pointer.
	mov r7, r8              // r7 = copy of dp.
	str r9, [r8], #4        // Store TOS to the dictionary ptr and increment ptr.
	str r8, [r7]            // Update the val_dp with the new dictionary pointer.
	ldr r9, [r13], #4       // Pop the stack.
	b next

/* drop ( a -- )
 * drops the top element of the stack 
 */
	define "drop", 4, , drop
	.word drop
drop:
	ldr r9, [r13], #4
	b next

/* swap ( a b -- b a )
 * swaps the two top items on the stack
 */
	define "swap", 4, , swap
	.word swap
swap:
	ldr r0, [r13], #4
	str r9, [r13, #-4]!
	mov r9, r0
	b next

/* dup ( a -- a a )
 * duplicates the top item on the stack 
 */
	define "dup", 3, , dup
	.word dup
dup:
	str r9, [r13, #-4]!
	b next

/* over ( a b -- a b a )
 * duplicates the second item on the stack
 */
	define "over", 4, , over
	.word over
over:
	ldr r0, [r13]       // r0 = get the second item on stack
	str r9, [r13, #-4]! // push TOS to the rest of the stack
	mov r9, r0          // TOS = r0
	b next

/* rot ( x y z -- y z x)
 * rotate the third item on the stack to the top
 */
	define "rot", 3, , rot
	.word rot
rot:
	ldr r0, [r13], #4   // pop y
	ldr r1, [r13], #4   // pop x
	str r0, [r13, #-4]! // push y
	str r9, [r13, #-4]! // push z
	mov r9, r1          // push x
	b next

/* >R ( a -- )
 * move the top element from the data stack to the return stack 
 */
	define ">R", 2, , to_r
	.word to_r
to_r:
	str r9, [r11, #-4]!
	ldr r9, [r13], #4
	b next

/* R> ( -- a )
 * move the top element from the return stack to the data stack 
 */
	define "R>", 2, , r_from
	.word r_from
r_from:
	str r9, [r13, #-4]!
	ldr r9, [r11], #4
	b next

/* + ( a b -- a+b) 
 * addition
 */
	define "+", 1, , add
	.word add
add:
	ldr r0, [r13], #4
	add r9, r0, r9
	b next

// - ( a b -- a-b) 
// subtraction
	define "-", 1, , sub
	.word sub
sub:
	ldr r0, [r13], #4
	sub r9, r9, r1
	b next

// * ( x y -- x*y) 
// multiplication
	define "*", 1, , multiply
	.word multiply
multiply:
	ldr r0, [r13], #4
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	b next

// = ( a b -- p ) 
// test for equality, -1=True, 0=False
	define "=", 1, , equal
	.word equal
equal:
	ldr r0, [r13], #4
	cmp r9, r0
	moveq r9, #-1
	movne r9, #0
	b next

// < ( x y -- y<x )
// less-than, see "=" for truth values
	define "<", 1, , lt
	.word lt
lt:
	ldr r0, [r13], #4
	cmp r9, r0
	movlt r9, #-1
	movge r9, #0
	b next

// > ( x y -- y>x )
// greater-than, see "=" for truth values
	define ">", 1, , gt
	.word gt
gt:
	ldr r0, [r13], #4
	cmp r9, r0
	movge r9, #-1
	movlt r9, #0
	b next

// & AND ( a b -- a&b)
// bitwise and 
	define "&", 1, , and
	.word do_and
do_and:
	ldr r0, [r13], #4
	and r9, r9, r0
	b next

// | ( a b -- a|b )
// bitwise or 
	define "|", 1, , or
	.word do_or
do_or:
	ldr r0, [r13], #4
	orr r9, r9, r0
	b next

// ^ ( a b -- a^b )
// bitwise xor 
	define "^", 1, , xor
	.word xor
xor:
	ldr r0, [r13], #4
	eor r9, r9, r0
	b next

// invert ( a -- ~a )
// bitwise not/invert
	define "invert", 6, , invert
	.word invert
invert:
	mvn r9, r9
	b next

/* ! ( val addr -- )
 * store value to address 
 */
	define "!", 1, , store
	.word store
store:
	ldr r0, [r13], #4
	str r0, [r9]
	ldr r9, [r13], #4
	b next

/* @ ( addr -- val )
 * fetch value from address 
 */
	define "@", 1, , fetch
	.word fetch
fetch:
	ldr r9, [r9]
	b next

// c! ( val addr -- )
// store byte, does what "!" does, but for a single byte
	define "c!", 2, , cstore
	.word cstore
cstore:
	ldr r0, [r13], #4
	strb r0, [r9]
	ldr r9, [r13], #4
	b next 

// c@ ( addr -- val )
// fetch byte, does what "@" does for a single byte
	define "c@", 2, , cfetch
	.word cfetch
cfetch:
	mov r0, #0
	ldrb r0, [r9]
	ldr r9, [r13], #4
	b next 

// exit ( -- )
// exit/return from current word
	define "exit", 4, , exit
	.word exit
exit:
	ldr r10, [r11], #4   // ip = pop return stack
	b next

// branch ( -- )
// changes the forth IP to the next codeword
	define "branch", 6, , branch
	.word branch
branch:
	ldr r1, [r10]
	mov r10, r1    // absolute jump
	b next

// 0branch ( p -- )
// branch if the top of the stack is zero 
	define "0branch", 7, , zero_branch
	.word zero_branch
zero_branch:
	ldr r0, [r13], #4
	cmp r0, #0          // if the top of the stack is zero:
	ldreq r1, [r10]     // branch
	moveq r10, r1       // ...
	addne r10, r10, #4 // else: do not branch
	b next

// exec ( xt -- )
// execute the XT on the stack
	define "exec", 4, , exec
	.word exec
exec:
	mov r0, r9        // save TOS to r0
	ldr r9, [r13], #4 // pop the stack
	ldr r0, [r0]      // dereference r0
	bx r0             // goto r0

// count ( addr1 -- addr2 len )
// Convert a counted string address to the first char address and the length
	define "count", 5, , count
	.word count
count:
	mov r0, r9
	add r0, #1
	push {r0}
	ldr r9, [r9]
	and r9, #F_LENMASK
	b next

// >number ( d addr len -- d2  addr2 zero     ) if successful
//         ( d addr len -- int addr2 non-zero ) if error
	define ">number", 7, , to_number
	.word to_number
to_number:
    //                    // r9 = length (already set)
	ldr r0, [r13], #4    // r0 = addr
	ldr r1, [r13], #4    // r1 = d.hi
	ldr r2, [r13], #4    // r2 = d.lo
	ldr r4, =var_base    // get the current number base
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
	add r9, #1           // length--
	sub r0, #1           // addr++
	b to_num1
to_num4:
	str r2, [r13, #-4]!  // push the low word
to_num5:               
	str r1, [r13, #-4]!  // push the high word
	str r0, [r13, #-4]!  // push the string address
	b next

// accept ( addr len1 -- len2 )
// read a string from input up to len1 chars long, len2 = actual number of chars
// read.
	define "accept", 6, , accept
	.word accept
accept:
	// TODO
	b next

// word ( char -- addr )
// scan the input buffer for a character
	define "word", 4, , word
	.word word
word:
	ldr r0, =var_dp          // load dp to use it as a scratchpad
	ldr r0, [r0]
	mov r4, r0               // save the dp to r4 for end of routine
	ldr r1, =const_tib       // load address of the input buffer
	ldr r1, [r1]
	mov r2, r1               // copy address to r2
	ldr r3, =var_to_in       // set r1 to tib + >in
	ldr r3, [r3]
	add r1, r3               // r1 holds the current pointer into the input buf
	ldr r3, =var_num_tib  // set r2 to tib + #tib
	ldr r3, [r3]
	add r2, r3               // r2 holds the addr of the end of the input buf
word1:
	cmp r2, r1               // branch if we reached the end of the buffer
	beq word3
	ldrb r3, [r1]            // get the next char from the buffer
	add r1, #1
	cmp r3, r9               // get more chars if the char is the separator
	beq word1
word2:
	add r0, #1               // increment pad pointer
	strb r3, [r0]            // write the char to the pad
	cmp r2, r1               // branch if we reached the end of the buffer
	beq word3
	ldrb r3, [r1]            // get next char from the buffer
	add r1, #1
	cmp r3, r9               // get more characters if it's not the separator
	bne word2
word3:
	mov r3, #' '              // terminate the word in pad with a space
	strb r3, [r1, #1]        
	sub r0, r1               // r0 = pad_ptr - dp
	strb r0, [r4]             // save the length byte into the first byte of pad
	ldr r0, =const_tib       // ">in" = "tib" - pad_ptr
	ldr r0, [r0]
	sub r1, r0              
	ldr r0, =var_to_in
	str r1, [r0]
	mov r9, r4               // The starting dp is the return value.
	b next

// emit ( char -- )
// display a character
	define "emit", 4, , emit
	.word word
emit:
	mov r0, r9
	bl outchar
	ldr r9, [r13], #4   // Pop the stack.
	b next

// Headerless routine to get a character into r0 from the terminal.
getchar:
	mov r7, #3      // linux system call for read(...)
	mov r0, #0      // fd = stdin
	ldr r1, =char   // buf = &char
	mov r2, #1      // count = 1 
	swi #0          // read(...)
	ldr r0, [r0]    // ch = *char
	bx lr           // return ch

// Headerless routine to send out a character in r0 to the terminal.
outchar:
	and r0, #255    // Make sure the char passed is in range.
	ldr r1, =char   // Store the char into the char buffer.
	str r0, [r1]    
	mov r7, #4      // Linux system call for write.
	mov r0, #1      // fd = stdout
	ldr r1, =char   // buf = &char
	mov r2, #1      // count = 1
	swi #0          // return write(...)
	bx lr

// A 1 char buffer for the getchar and outchar routines.
// Is only needed for interfacing with the Linux OS through system calls.
	.data
char:
	.ascii " "

// find ( addr1 -- addr2 flag )
// Look for a word in the dictionary. There are 3 possibilities:
// * flag =  0, and addr2 = addr1, which means the word was not found
// * flag =  1, and addr2 =    xt, which means the word is immediate
// * flag = -1, and addr2 =    xt, which means the word is not immediate
	define "find", 4, , find
	.word find
find:
	// TODO: see paper
	// USE THE STRING= WORD CODE
	// r9 --> r0
	// pop(r13) --> r1
	// call string= runtime code
	// result --> r9

the_final_word:

// interpret ( -- )
// The outer interpreter (loop):
// get a word from input and interpret it as either a number
// or as a word
	define "interpret", 9, , interpret
	.word docol
	.word xt_num_tib
	.word xt_fetch
	.word xt_to_in
	.word xt_fetch
	.word xt_equal
	.word xt_zero_branch, intpar
	.word xt_tib
	.word xt_lit, 50
	.word xt_accept
	.word xt_num_tib
	.word xt_store
	.word xt_lit, 0
	.word xt_to_in
	.word xt_store
intpar:
	.word xt_lit, 32
	.word xt_word
	.word xt_find
	.word xt_dup
	.word xt_zero_branch, intnf
	.word xt_state
	.word xt_fetch
	.word xt_equal
	.word xt_zero_branch, intexc
	.word xt_comma
	.word xt_branch, intdone
intexc:
	.word xt_exec
	.word xt_branch, intdone
intnf:
	.word xt_dup
	.word xt_rot
	.word xt_count
	.word xt_to_number
	.word xt_zero_branch, intskip
	.word xt_state, xt_fetch
	.word xt_zero_branch, intnc
	.word xt_last, xt_fetch
	.word xt_dup, xt_fetch
	.word xt_last, xt_store
	.word xt_dp, xt_store
intnc:                                       // Exit infinite loop and reset
	.word xt_quit                            // because of error.
intskip:
	.word xt_drop, xt_drop
	.word xt_state, xt_fetch
	.word xt_zero_branch, intdone
	.word xt_lit, xt_lit, xt_comma, xt_comma
intdone:
	.word xt_branch, xt_interpret            // Infinite loop.

	.data

	.space 256
stack_base:

addr_tib:
	.space 128

dictionary:
	.space 2048


