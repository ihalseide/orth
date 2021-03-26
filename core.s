	.global _start

// Define the word flag values:
	.set F_IMMEDIATE, 0b10000000   // Immediate word
	.set F_HIDDEN,    0b01000000   // Hidden word
	.set F_LENMASK,   0x00111111   // Length mask

// Is used to chain together words in the dictionary as they are defined in asm.
	.set link, 0    

//-------------------------------------------------------------------------------
// System Variables
//-------------------------------------------------------------------------------

// state ( -- addr )
// Compiling or interpreting state.
name_state:
	.word link
	.set link, name_state
	.byte 4
	.ascii "state"
	.balign 4
xt_state:
	.word dovar
val_state:
	.word 0

// >in ( -- addr )
// Next character in input buffer.
name_to_in:
	.word link
	.set link, name_to_in
	.byte 3
	.ascii ">in"
	.balign 4
xt_to_in:
	.word dovar
val_to_in:
	.word 0

// #tib ( --  addr )
// Number of characters in the input buffer.
name_num_tib:
	.word link
	.set link, name_num_tib
	.byte 3
	.ascii ">in"
	.balign 4
xt_num_tib:
	.word dovar
val_num_tib:
	.word 0

// dp ( -- addr )
// First free cell in the dictionary (dictionary pointer).
name_dp:
	.word link
	.set link, name_dp
	.byte 2
	.ascii "dp"
	.balign 4
xt_dp:
	.word dovar
val_dp:
	.word freemem

// base ( -- addr )
// Address of the number read and write base.
name_base:
	.word link
	.set link, name_base
	.byte 4
	.ascii "base"
	.balign 4
xt_base:
	.word dovar
val_base:
	.word 10
	
// last ( -- addr )
// Address of the last word defined.
name_last:
	.word link
	.set link, name_last
	.byte 4
	.ascii "last"
	.balign 4
xt_last:
	.word do_var
val_last:
	.word final_word

// tib ( -- addr )
// Address of the input buffer.
name_tib:
	.word link
	.set link, name_tib
	.byte 3
	.ascii "tib"
	.balign 4
xt_tib:
	.word dovar
val_tib:
	.space 128    // TODO: better layout of memory

//-------------------------------------------------------------------------------
// Initialization
//-------------------------------------------------------------------------------

// Main program starting point.
_start:
	b quit            // Run quit (which doesn't quit this program).

// quit ( -- )
name_quit:
	.word link
	.set link, name_quit
	.byte 4
	.ascii "quit"
	.balign 4
xt_quit:
	.word quit
quit:
	ldr r0, =val_number_tib // copy value of "#tib" to ">in"
	ldr r0, [r0]
	ldr r1, =val_to_in
	str r0, [r1]
	eor r11, r11            // Clear the return stack pointer.
	ldr r1, =val_state      // Set state to 0.
	str r11, [r1]
	ldr r13, =stack_0       // Set the stack pointer.
	ldr r10, =interpret     // Set the virtual instruction pointer to the interpreter.
	b next                  // Jump to the inner interpreter.

//-------------------------------------------------------------------------------
// Inner interpreter
//-------------------------------------------------------------------------------

// Next will move on to the next forth word.
next:
	ldr r8, [r10], #4   // r0 = ip, and ip = ip + 4.
	ldr r8, [r8]        // Dereference, since this forth is indirect threaded code.
	bx r8

//-------------------------------------------------------------------------------
// Colon definitions
//-------------------------------------------------------------------------------

// : ( -- )
// Colon will define a new word by adding it to the dictionary and by setting
// the "last" word to be the new word
name_colon:
	.word link
	.set link, name_colon
	.byte 1 + F_IMMEDIATE
	.ascii ":"
	.balign 4
xt_colon:
	.word docolon
colon:
	.word xt_lit, -1
	.word xt_state, xt_store   // Enter compile mode.
	.word xt_create            // Create a new header for the next word.
	.word xt_do_semi_code      // Make "docolon" be the runtime code for the new header.

// Runtime code for colon-defined words.
docolon:
	str r10, [r11, #-4]!
	add r10, r0, #4
	b next

// ; ( -- )
// Semicolon: complete the current forth word being compiled.
name_semicolon:
	.word link
	.set link, name_semicolon
	.byte 1 + F_IMMEDIATE                // Semicolon must be immediate because 
	.ascii ";"                           // it ends compilation while still in 
	.balign 4                            // compile mode.
xt_semicolon:
	.word docolon
semicolon:
	.word xt_lit, xt_exit                // Compile an exit code.
	.word xt_comma
	.word xt_lit, 0, xt_state, xt_store  // Change back to immediate mode.
	.word xt_exit                        // Actually exit this word.

//-------------------------------------------------------------------------------
// Headers
//-------------------------------------------------------------------------------

// create ( -- )
//
name_create:
	.word link
	.set link, name_create
	.byte 6
	.ascii "create"
xt_create:
	.word docol
create:
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

// (//code) ( -- )
name_do_semi_code:
	.word link
	.set link, name_do_semi_code
	.byte 7
	.ascii "(//code)"
	.balign 4
xt_do_semi_code:
	.word do_semi_code
do_semi_code:
	ldr r8, =val_last       // Set r8 to the link field address of the last dictionary word.
	ldr r8, [r8]
	// last edit <HERE>


//-------------------------------------------------------------------------------
// Constants
//-------------------------------------------------------------------------------

// const ( x -- )
// Create a new constant word that pushes x, where the name of the constant is
// taken from the input buffer.
name_const:
	.word link
	.set link, name_const
	.byte 5
	.ascii "const"
	.balign 4
xt_const:
	.word docolon
	.word xt_create
	.word xt_comma
	.word xt_do_semi_code

doconst:                   // Runtime code for words that push a constant.
	str r9, [r13, #-4]!    // Push the stack.
	ldr r9, [r8, #4]       // Fetch the data, which is bytes 4 after the CFA.
	b next                 

//-------------------------------------------------------------------------------
// Compiling
//-------------------------------------------------------------------------------

// lit ( -- )
// Pushes the next value in the cell right after itself
name_lit:
	.word link
	.set link, name_lit
	.byte 3
	.ascii "lit"
	.balign 4
xt_lit:
	.word lit
lit:
	str r9, [r13, #-4]!     // Push to the stack.
	ldr r9, [r10], #4       // Get the next cell value and put it in r9 while
	b next                  // also incrementing r10 by 4 bytes.

// , ( x -- )
// Comma compiles the value x to the dictionary
name_comma:
	.word link
	.set link, name_comma
	.byte 1
	.ascii ","
	.balign 4
xt_comma:
	.word comma
comma:
	ldr r8, =val_dp         // Set r8 to the dictionary pointer.
	mov r7, r8              // r7 = copy of dp.
	str r9, [r8], #4        // Store TOS to the dictionary ptr and increment ptr.
	str r8, [r7]            // Update the val_dp with the new dictionary pointer.
	ldr r9, [r13], #4       // Pop the stack.
	b next

//-------------------------------------------------------------------------------
// Stack manipulation
//-------------------------------------------------------------------------------

// drop ( a -- )
// drops the top element of the stack 
name_drop:
	.word link
	.set link, name_drop
	.byte 4
	.ascii "drop"
	.balign 4
xt_drop:
	.word drop
drop:
	ldr r9, [r13], #4
	b next

// swap ( a b -- b a )
// swaps the two top items on the stack
name_swap:
	.word link
	.set link, name_swap
	.byte 4
	.ascii "swap"
	.balign 4
xt_swap:
	.word swap
swap:
	ldr r0, [r13], #4
	str r9, [r13, #-4]!
	mov r9, r0
	b next

// dup ( a -- a a )
// duplicates the top item on the stack 
name_dup:
	.word link
	.set link, name_dup
	.byte 3
	.ascii "dup"
	.balign 4
xt_dup:
	.word dup
dup:
	str r9, [r13, #-4]!
	b next

// over ( a b -- a b a )
// duplicates the second item on the stack
name_over:
	.word link
	.set link, name_over
	.byte 4
	.ascii "over"
	.balign 4
xt_over:
	.word over
over:
	ldr r0, [r13]       // r0 = get the second item on stack
	str r9, [r13, #-4]! // push TOS to the rest of the stack
	mov r9, r0          // TOS = r0
	b next

// rot ( x y z -- y z x)
// rotate the third item on the stack to the top
name_rot:
	.word link
	.set link, name_rot
	.byte 3
	.ascii "rot"
	.balign 4
xt_rot:
	.word rot
rot:
	ldr r0, [r13], #4   // pop y
	ldr r1, [r13], #4   // pop x
	str r0, [r13, #-4]! // push y
	str r9, [r13, #-4]! // push z
	mov r9, r1          // push x
	b next

// >R ( a -- )
// move the top element from the data stack to the return stack 
name_to_r:
	.word link
	.set link, name_to_r
	.byte 2
	.ascii ">R"
	.balign 4
xt_to_r:
	.word to_r
to_r:
	str r9, [r11, #-4]!
	ldr r9, [r13], #4
	b next

// R> ( -- a )
// move the top element from the return stack to the data stack 
name_r_from:
	.word link
	.set link, name_r_from
	.byte 2
	.ascii "R>"
	.balign 4
xt_r_from:
	.word r_from
r_from:
	str r9, [r13, #-4]!
	ldr r9, [r11], #4
	b next

//-------------------------------------------------------------------------------
// Math
//-------------------------------------------------------------------------------

// + ( a b -- a+b) 
// addition
name_add:
	.word link
	.set link, name_add
	.byte 1
	.ascii "+"
	.balign 4
xt_add:
	.word add
add:
	ldr r0, [r13], #4
	add r9, r0, r9
	b next

// - ( a b -- a-b) 
// subtraction
name_sub:
	.word link
	.set link, name_sub
	.byte 1
	.ascii "-"
	.balign 4
xt_sub:
	.word sub
sub:
	ldr r0, [r13], #4
	sub r9, r9, r1
	b next

// * ( x y -- x*y) 
// multiplication
name_multiply:
	.word link
	.set link, name_multiply
	.byte 1
	.ascii "*"
	.balign 4
xt_multiply:
	.word multiply
multiply:
	ldr r0, [r13], #4
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	b next

// = ( a b -- p ) 
// test for equality, -1=True, 0=False
name_equal:
	.word link
	.set link, name_equal
	.byte 1
	.ascii "="
	.balign 4
xt_equal:
	.word equal
equal:
	ldr r0, [r13], #4
	cmp r9, r0
	moveq r9, #-1
	movne r9, #0
	b next

// < ( x y -- y<x )
// less-than, see "=" for truth values
name_lt:
	.word link
	.set link, name_lt
	.byte 1
	.ascii "<"
	.balign 4
xt_lt:
	.word lt
lt:
	ldr r0, [r13], #4
	cmp r9, r0
	movlt r9, #-1
	movge r9, #0
	b next

// > ( x y -- y>x )
// greater-than, see "=" for truth values
name_gt:
	.word link
	.set link, name_gt
	.byte 1
	.ascii ">"
	.balign 4
xt_gt:
	.word gt
gt:
	ldr r0, [r13], #4
	cmp r9, r0
	movge r9, #-1
	movlt r9, #0
	b next

// & AND ( a b -- a&b)
// bitwise and 
name_and:
	.word link
	.set link, name_and
	.byte 1
	.ascii "&"
	.balign 4
xt_and:
	.word and
and:
	ldr r0, [r13], #4
	and r9, r9, r0
	b next

// | ( a b -- a|b )
// bitwise or 
name_or:
	.word link
	.set link, name_or
	.byte 1
	.ascii "|"
	.balign 4
xt_or:
	.word or
or:
	ldr r0, [r13], #4
	orr r9, r9, r0
	b next

// ^ ( a b -- a^b )
// bitwise xor 
name_xor:
	.word link
	.set link, name_xor
	.byte 1
	.ascii "^"
	.balign 4
xt_xor:
	.word xor
xor:
	ldr r0, [r13], #4
	eor r9, r9, r0
	b next

// ~ ( a -- ~a )
// bitwise not/invert
name_invert:
	.word link
	.set link, name_invert
	.byte 1
	.ascii "~"
	.balign 4
xt_invert:
	.word invert
invert:
	mvn r9, r9
	b next

//-------------------------------------------------------------------------------
// Memory fetch and store
//-------------------------------------------------------------------------------

// ! ( val addr -- )
// store value to address 
name_store:
	.word link
	.set link, name_store
	.byte 1
	.ascii "!"
	.balign 4
xt_store:
	.word store
store:
	ldr r0, [r13], #4
	str r0, [r9]
	ldr r9, [r13], #4
	b next

// @ ( addr -- val )
// fetch value from address 
name_fetch:
	.word link
	.set link, name_fetch
	.byte 1
	.ascii "@"
	.balign 4
xt_fetch:
	.word fetch
fetch:
	ldr r9, [r9]
	b next

// c! ( val addr -- )
// store byte, does what "!" does, but for a single byte
name_cstore:
	.word link
	.set link, name_cstore
	.byte 2
	.ascii "c!"
	.balign 4
xt_cstore:
	.word cstore
cstore:
	ldr r0, [r13], #4
	strb r0, [r9]
	ldr r9, [r13], #4
	b next 

// c@ ( addr -- val )
// fetch byte, does what "@" does for a single byte
name_cfetch:
	.word link
	.set link, name_cfetch
	.byte 2
	.ascii "c@"
	.balign 4
xt_cfetch:
	.word cfetch
cfetch:
	mov r0, #0
	ldrb r0, [r9]
	ldr r9, [r13], #4
	b next 

//-------------------------------------------------------------------------------
// Flow control
//-------------------------------------------------------------------------------

// exit ( -- )
// exit/return from current word
name_exit:
	.word link
	.set link, name_exit
	.byte 4
	.ascii "exit"
	.balign 4
xt_exit: 
	.word exit
exit:
	ldr r10, [r11], #4   // ip = pop return stack
	b next

// branch ( -- )
// changes the forth IP to the next codeword
name_branch:
	.word link
	.set link, name_branch
	.byte 6
	.ascii "branch"
	.balign 4
xt_branch:
	.word branch
branch:
	ldr r1, [r10]
	mov r10, r1    // absolute jump
	b next

// 0branch ( p -- )
// branch if the top of the stack is zero 
name_zero_branch:
	.word link
	.set link, name_zero_branch
	.byte 7
	.ascii "0branch"
	.balign 4
xt_zero_branch:
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
name_exec:
	.word link
	.set link, name_exec
	.byte 4
	.ascii "exec"
	.balign 4
xt_exec:
	.word exec
exec:
	mov r0, r9        // save TOS to r0
	ldr r9, [r13], #4 // pop the stack
	ldr r0, [r0]      // dereference r0
	bx r0             // goto r0

//-------------------------------------------------------------------------------
// Strings
//-------------------------------------------------------------------------------

// count ( addr1 -- addr2 len )
// Convert a counted string address to the first char address and the length
name_count:
	.word link
	.set link, name_count
	.byte 5
	.ascii "count"
	.balign 4
xt_count:
	.word count
count:
	add r9, #1
	str r9, [r13, #-4]!      // push the address of the first char
	ldrb r9, [r9]            // load unsigned byte
	mov r0, #F_LENMASK       // remove the immediate flag from the length value
	and r9, r9, r0          

// string= ( addr1 addr2 -- flag )
// Test if two counted strings are equal
name_string_eq:
	.word link
	.set link, name_string_eq
	.byte 7
	.ascii "string="
	.balign 4
xt_string_eq:
	.word string_eq
string_eq:
	// TODO: FIXME: r0 and r9 are incorrectly used both as addresses and as values
	and r9, #F_LENMASK   // Remove any flags from addr2.
	ldr r0, [r13], #4   // Pop addr1.
	and r0, #F_LENMASK   // Remove any flags from addr1.
	cmp r9, r0
	bne string_eq2      // If the lengths aren't equal, return false.
	mov r1, r0          // Save the length of the strings.
string_eq1:
	add r9, #1          // Increment both char indices.
	add r0, #1
	cmp r9, r0          // Continue only if they are equal.
	bne string_eq2
	sub r1, #1
	cmp r1, #0
	bne string_eq1      // Loop if there are more characters to compare.
	mov r9, #-1         // Otherwise, return true.
	b next
string_eq2:             // Strings are not equal, so return false.
	mov r9, #0
	b next

// >number ( d addr len -- d2  addr2 zero     ) if successful
//         ( d addr len -- int addr2 non-zero ) if error
name_to_number:
	.word link
	.set link, name_to_number
	.byte 7
	.ascii ">number"
	.balign 4
xt_to_number:
	.word to_number
to_number:
    //                    // r9 = length (already set)
	ldr r0, [r13], #4    // r0 = addr
	ldr r1, [r13], #4    // r1 = d.hi
	ldr r2, [r13], #4    // r2 = d.lo
	ldr r4, =val_base    // get the current number base
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

//-------------------------------------------------------------------------------
// Input and output
//-------------------------------------------------------------------------------

// accept ( addr len1 -- len2 )
// read a string from input up to len1 chars long, len2 = actual number of chars
// read.
name_accept:
	.word link
	.set link, name_accept
	.byte 6
	.ascii "accept"
	.balign 4
xt_accept:
	.word accept
accept:
	// TODO
	b next

// word ( char -- addr )
// scan the input buffer for a character
name_word:
	.word link
	.set link, name_word
	.byte 4
	.ascii "word"
	.balign 4
xt_word:
	.word word
word:
	ldr r0, =val_dp          // load dp to use it as a scratchpad
	ldr r0, [r0]
	mov r4, r0               // save the dp to r4 for end of routine
	ldr r1, =val_tib         // load address of the input buffer
	ldr r1, [r1]
	mov r2, r1               // copy address to r2
	ldr r3, =val_to_in       // set r1 to tib + >in
	ldr r3, [r3]
	add r1, r3               // r1 holds the current pointer into the input buf
	ldr r3, =val_number_tib  // set r2 to tib + #tib
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
	ldr r0, =val_tib         // ">in" = "tib" - pad_ptr
	ldr r0, [r0]
	sub r1, r0              
	ldr r0, =val_to_in
	str r1, [r0]
	mov r9, r4               // The starting dp is the return value.
	b next

// emit ( char -- )
// display a character
name_emit:
	.word link
	.set link, name_emit
	.byte 4
	.ascii "emit"
	.balign 4
xt_emit:
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
	.text

//-------------------------------------------------------------------------------
// Dictionary search
//-------------------------------------------------------------------------------

// find ( addr1 -- addr2 flag )
// Look for a word in the dictionary. There are 3 possibilities:
// * flag =  0, and addr2 = addr1, which means the word was not found
// * flag =  1, and addr2 =    xt, which means the word is immediate
// * flag = -1, and addr2 =    xt, which means the word is not immediate
name_find:
	.word link
	.set link, name_find
	.byte 4
	.ascii "find"
	.balign 4
xt_find:
	.word find
find:
	// TODO: see paper
	// USE THE STRING= WORD CODE
	// r9 --> r0
	// pop(r13) --> r1
	// call string= runtime code
	// result --> r9

//-------------------------------------------------------------------------------
// The outer interpreter
//-------------------------------------------------------------------------------

// This label must be right before the FINAL WORD that is defined in this file:

final_word:

// interpret ( -- )
// The outer interpreter (loop):
// get a word from input and interpret it as either a number
// or as a word
name_interpret:
	.word link
	.set link, name_interpret
	.byte 9
	.ascii "interpret"
	.balign 4
xt_interpret:
	.word docolon
interpret:
	.word xt_number_t_i_b
	.word xt_fetch
	.word xt_to_in
	.word xt_fetch
	.word xt_equal
	.word xt_zero_branch, intpar
	.word xt_t_i_b
	.word xt_lit, 50
	.word xt_accept
	.word xt_number_t_i_b
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

//-------------------------------------------------------------------------------
// Dictionary space
//-------------------------------------------------------------------------------

freemem:
