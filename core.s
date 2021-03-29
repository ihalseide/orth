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
	.macro define name, namelen, flags=0, label   
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
	.endm

/* Begin normal program data, which needs to be before the dictionary
 * because the dictionary will grow upwards in memory.
 */

	.data
	.align 2
addr_emit_char:
	.space 1

	.data
	.align 2
rstack_base:          // 256 cells for the return stack, which grows up
	.space 1024    

	/* Terminal Input Buffer */
	.data
	.align 2
addr_tib:
	.space 1024

/* Begin word header definitions */

	.data
	.align 2

	/* : ( -- ) */
	define ":", 1, F_IMMEDIATE, colon
	.word docol
	.word xt_create                        // Create a new header for the next word.
	.word xt_enter_compile                 // Enter into compile mode
	.word xt_lit, docol, xt_do_semi_code   // Make "docolon" be the runtime code for the new header.

	define "]", 1, , enter_compile
	.word enter_compile

	define "[", 1, F_IMMEDIATE, enter_immediate
	.word enter_immediate

	define "quit", 4, , quit
	.word quit

	define "state", 5, , state
	.word dovar
val_state:
	.word 0

	define ">in", 3, , to_in
	.word dovar
val_to_in:
	.word 0

	define "#tib", 4, , num_tib
	.word dovar
val_num_tib:
	.word 0

	define "tib", 3, , tib
	.word dovar
val_tib:
	.word addr_tib

	define "dp", 2, , dp
	.word dovar
val_dp:
	.word dictionary_space

	define "base", 4, , base
	.word dovar
val_base:
	.word 10
	
	define "last", 4, , last
	.word dovar
val_last:
	.word the_final_word

	define ";", 1, F_IMMEDIATE, semicolon
	.word docol
	.word xt_lit, xt_exit                // Compile an exit code.
	.word xt_comma
	.word xt_lit, 0, xt_state, xt_store  // Change back to immediate mode.
	.word xt_exit                        // Actually exit this word.

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
	.word xt_lit, dovar, xt_do_semi_code

	define "(;code)", 7, , do_semi_code
	.word do_semi_code

	define "const", 5, , const
	.word docol
	.word xt_create
	.word xt_comma
	.word xt_lit, doconst, xt_do_semi_code

	define "lit", 3, F_IMMEDIATE, lit
	.word lit

	define ",", 1, , comma
	.word comma

	define "drop", 4, , drop
	.word drop

	define "swap", 4, , swap
	.word swap

	define "over", 4, , over
	.word over

	define "rot", 3, , rot
	.word rot

	define ">R", 2, , to_r
	.word to_r

	define "R>", 2, , r_from
	.word r_from

	define "-", 1, , sub
	.word sub

	define "+", 1, , add
	.word add

	define "dup", 3, , dup
	.word dup

	define "find", 4, , find
	.word find

	define "emit", 4, , emit
	.word emit

	define "=", 1, , equal
	.word equal

	define "*", 1, , multiply
	.word multiply

	define "<", 1, , lt
	.word lt

	define ">", 1, , gt
	.word gt

	define "&", 1, , and
	.word do_and

	define "|", 1, , or
	.word do_or

	define "^", 1, , xor
	.word xor

	define "invert", 6, , invert
	.word invert

	define "negate", 6, , negate
	.word negate

	define "!", 1, , store
	.word store

	define "@", 1, , fetch
	.word fetch

	define "c!", 2, , cstore
	.word cstore

	define "c@", 2, , cfetch
	.word cfetch

	define "exit", 4, , exit
	.word exit

	define "branch", 6, , branch
	.word branch

	define "0branch", 7, , zero_branch
	.word zero_branch

	define "exec", 4, , exec
	.word exec

	// count ( addr -- addr2 len )
	define "count", 5, , count
	.word count

	// tell ( addr -- )
	define "tell", 4, , tell
	.word tell

	define ">number", 7, , to_number
	.word to_number

	define "accept", 6, , accept
	.word accept

	define "word", 4, , word
	.word word

	define "interpret", 9, , interpret
	.word docol
	.word xt_num_tib, xt_fetch
	.word xt_to_in, xt_fetch
	.word xt_equal, xt_zero_branch, intpar
	.word xt_tib
	.word xt_lit, 50
	.word xt_accept
	.word xt_num_tib, xt_store
	.word xt_lit, 0
	.word xt_to_in, xt_store
intpar:
	.word xt_lit, 32
	.word xt_word
	.word xt_find
	.word xt_dup
	.word xt_zero_branch, intnf
	.word xt_state, xt_fetch
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

	/* / ( n m -- q ) division quotient */
	define "/", 1, , divide
	.word divide

	/* /mod ( n m -- r q ) division remainder and quotient */
	define "/mod", 4, , word_divmod
	.word divmod

	/* mod ( n m -- r ) division remainder */
	define "mod", 3, , mod
	.word mod

the_final_word:
	define "bye", 3, , bye
	.word bye

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

var_dp:
	.word val_dp

var_base:
	.word val_base
	
var_last:
	.word val_last

/* Begin the main assembly code. */

	.text
	.align 2

	/* Main starting point. */
	.global _start
_start:
quit:
	mov r0, #42
	push {r0}

	ldr r11, =rstack_base    // Init the return stack.

	ldr r1, =var_state      // Set state to 0 (interpreting)
	ldr r1, [r1]
	eor r0, r0
	str r0, [r1]

	ldr r0, =const_num_tib      // Copy value of "#tib" to ">in".
	ldr r0, [r0]
	ldr r0, [r0]
	ldr r1, =var_to_in
	ldr r1, [r1]
	str r0, [r1]

	ldr r10, =dummy_xt   // Set instruction pointer to interpret
	b next  

dummy_xt:
	.word xt_interpret

docol:
	str r10, [r11], #4      // Save the return address to the return stack
	add r10, r8, #4         // Get the next instruction

	/* fall-into next */

next:                       // The inner interpreter
	ldr r8, [r10], #4       // Get the next virtual instruction
	ldr r0, [r8]
	bx r0

exit:                       // End a forth word.
	ldr r10, [r11, #-4]!    // ip = pop return stack
	b next

dovar:
	str r9, [r13, #-4]!    // Prepare a push for r9.
	mov r9, r8             // r9 = [XT + 4].
	add r9, #4             // (r9 should be an address).
	b next

doconst:                   // Runtime code for words that push a constant.
	str r9, [r13, #-4]!    // Push the stack.
	ldr r9, [r8, #4]       // Fetch the data, which is bytes 4 after the CFA.
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
	str r9, [r13, #-4]!  // Push to the stack.
	ldr r9, [r10], #4    // Push the next cell value and skip the IP over it.
	b next               


comma:
	ldr r8, =var_dp         // Set r8 to the dictionary pointer.
	mov r7, r8              // r7 = copy of dp.
	str r9, [r8], #4        // Store TOS to the dictionary ptr and increment ptr.
	str r8, [r7]            // Update the val_dp with the new dictionary pointer.
	ldr r9, [r13], #4       // Pop the stack.
	b next


find:                       // find - ( addr -- addr2 flag )
	ldr r0, =var_last       // r0 = current word link field address
	ldr r0, [r0]

	ldrb r1, [r9]           // r1 = input str len

find_len:
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq find_no

	ldrb r2, [r0, #4]       // get word length
	and r2, #F_LENMASK

	cmp r2, r1              // compare the lengths
	bne find_len

	add r2, r0, #4          // r2 = start address of word name string buffer
	eor r3, r3              // r3 = 0 index
find_chars:
	add r3, #1              // increment index (starts at index 1)
	ldrb r4, [r9, r3]       // compare input string char to word char
	ldrb r5, [r2, r3]
	cmp r4, r5
	bne find_len            // if they are ever not equal, the strings aren't equal

	cmp r3, r1              // keep looping until the whole strings have been compared
	bne find_chars

find_yes:
	mov r9, #1              // return 1 if it's immediate
	ldr r1, [r0, #4]        // get the word's length byte again
	tst r1, #F_IMMEDIATE    // return -1 if it's not immediate
	negne r9, r9

	add r0, #36             // push the word's CFA to the stack
	push {r0}

	b next

find_no:
	push {r9}               // push string address
	eor r9, r9              // return 0 for no find
	b next


drop:
	ldr r9, [r13], #4
	b next


swap:
	ldr r0, [r13], #4
	str r9, [r13, #-4]!
	mov r9, r0
	b next


dup:
	str r9, [r13, #-4]!
	b next

over:
	ldr r0, [r13]       // r0 = get the second item on stack
	str r9, [r13, #-4]! // push TOS to the rest of the stack
	mov r9, r0          // TOS = r0
	b next

rot:
	ldr r0, [r13], #4   // pop y
	ldr r1, [r13], #4   // pop x
	str r0, [r13, #-4]! // push y
	str r9, [r13, #-4]! // push z
	mov r9, r1          // push x
	b next

to_r:
	str r9, [r11, #-4]!
	ldr r9, [r13], #4
	b next

r_from:
	str r9, [r13, #-4]!
	ldr r9, [r11], #4
	b next

add:
	ldr r0, [r13], #4
	add r9, r0, r9
	b next

sub:
	ldr r0, [r13], #4
	sub r9, r9, r1
	b next

multiply:
	ldr r0, [r13], #4
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	b next

equal:
	ldr r0, [r13], #4
	cmp r9, r0
	moveq r9, #-1
	movne r9, #0
	b next

lt:
	ldr r0, [r13], #4
	cmp r9, r0
	movlt r9, #-1
	movge r9, #0
	b next

gt:
	ldr r0, [r13], #4
	cmp r9, r0
	movge r9, #-1
	movlt r9, #0
	b next

do_and:
	ldr r0, [r13], #4
	and r9, r9, r0
	b next

do_or:
	ldr r0, [r13], #4
	orr r9, r9, r0
	b next

xor:
	ldr r0, [r13], #4
	eor r9, r9, r0
	b next

invert:
	mvn r9, r9
	b next

negate:
	neg r9, r9
	b next

store:
	ldr r0, [r13], #4
	str r0, [r9]
	ldr r9, [r13], #4
	b next

fetch:
	ldr r9, [r9]
	b next

cstore:
	ldr r0, [r13], #4
	strb r0, [r9]
	ldr r9, [r13], #4
	b next 

cfetch:
	mov r0, #0
	ldrb r0, [r9]
	ldr r9, [r13], #4
	b next 

branch:
	ldr r0, [r10], #4
	mov r10, r0
	b next

zero_branch:
	ldr r0, [r10], #4
	cmp r9, #0
	moveq r10, r0
	pop {r9}
	b next

exec:
	mov r8, r9        // r8 = the xt
	pop {r9}          // pop the stack
	ldr r1, [r8]      // r1 = code address
	bx r1

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

	ldr r9, =var_dp       // push the dictionary pointer, which is used as a buffer area, "pad"
	ldr r9, [r9]          // r4 = r9 = dp
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
	str r3, [r4], #1

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
	ldr r1, =addr_emit_char
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

	/* copy from: https://github.com/organix/pijFORTHos, jonesforth.s
	 * args: r0=numerator, r1=denominator
	 */ returns: r0=remainder, r1 = denominator, r2=quotient
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

digits: .ascii "0123456789abcdefghijklmnopqrstuvwxyz?"

