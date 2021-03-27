/* Linux file stream descriptors */
	.set stdin, 0
	.set stdout, 1
	.set stderr, 2

/* System call numbers */
	.set os_exit, 1
	.set os_read, 3
	.set os_write, 4

/* Word bitmask flags */
	.set F_IMMEDIATE, 0b10000000
	.set F_HIDDEN,    0b01000000
	.set F_LENMASK,   0b00111111    

/* Macro for defining a word header in the data section */
	.macro define name, len, flags=0, label   
	.data
	.align 2
_def_\label:
	.int link               // link to previous word in the dictionary data
	.set link, _def_\label
	.byte \len+\flags        // The name field, including the length byte
	.ascii "\name"           // is 32 bytes long
	.space 31-\len
	.global xt_\label
xt_\label:                   // The next 4 byte word/cell will be the code field
	.endm

/* Begin normal program data, which needs to be before the dictionary
 * because the dictionary will grow upwards in memory.
 */

	.data

data_base:

	.space 4*256    /* 256 cells for the return stack, which grows down */
rstack_base:

	/* Terminal Input Buffer */
addr_tib:
	.space 1024

addr_emit_char:
	.space 1

/* Begin word header definitions */

	.set link, 0   // Previous word link pointer for while it's assembling word defs

	.data
dictionary_base:

	/* : ( -- ) */
	define ":", 1, F_IMMEDIATE, colon
	.int docol
	.int xt_create                        // Create a new header for the next word.
	.int xt_enter_compile                 // Enter into compile mode
	.int xt_lit, docol, xt_do_semi_code   // Make "docolon" be the runtime code for the new header.

	define "]", 1, , enter_compile
	.int enter_compile

	define "[", 1, F_IMMEDIATE, enter_immediate
	.int enter_immediate

	define "quit", 4, , quit
	.int quit

	define "state", 5, , state
	.int dovar
var_state:
	.int 0

	define ">in", 3, , to_in
	.int dovar
var_to_in:
	.int 0

	define "#tib", 4, , num_tib
	.int dovar
var_num_tib:
	.int 0

	define "tib", 3, , tib
	.int dovar
var_tib:
	.int addr_tib

	define "dp", 2, , dp
	.int dovar
var_dp:
	.int 0

	define "base", 4, , base
	.int dovar
var_base:
	.int 10
	
	define "last", 4, , last
	.int dovar
var_last:
	.int the_final_word

	define ";", 1, F_IMMEDIATE, semicolon
	.int docol
	.int xt_lit, xt_exit                // Compile an exit code.
	.int xt_comma
	.int xt_lit, 0, xt_state, xt_store  // Change back to immediate mode.
	.int xt_exit                        // Actually exit this word.

	define "create", 6, , create
	.int docol
	.int xt_dp, xt_fetch
	.int xt_last, xt_fetch
	.int xt_comma
	.int xt_last, xt_store
	.int xt_lit, 32
	.int xt_word
	.int xt_count
	.int xt_add
	.int xt_dp, xt_store
	.int xt_lit, 0
	.int xt_comma
	.int xt_lit, dovar, xt_do_semi_code

	define "(;code)", 7, , do_semi_code
	.int do_semi_code

	define "const", 5, , const
	.int docol
	.int xt_create
	.int xt_comma
	.int xt_lit, doconst, xt_do_semi_code

	define "lit", 3, F_IMMEDIATE, lit
	.int lit

	define ",", 1, , comma
	.int comma

	define "drop", 4, , drop
	.int drop

	define "swap", 4, , swap
	.int swap

	define "over", 4, , over
	.int over

	define "rot", 3, , rot
	.int rot

	define ">R", 2, , to_r
	.int to_r

	define "R>", 2, , r_from
	.int r_from

	define "-", 1, , sub
	.int sub

	define "+", 1, , add
	.int add

	define "dup", 3, , dup
	.int dup

	define "find", 4, , find
	.int find

	define "emit", 4, , emit
	.int emit

	define "=", 1, , equal
	.int equal

	define "*", 1, , multiply
	.int multiply

	define "<", 1, , lt
	.int lt

	define ">", 1, , gt
	.int gt

	define "&", 1, , and
	.int do_and

	define "|", 1, , or
	.int do_or

	define "^", 1, , xor
	.int xor

	define "invert", 6, , invert
	.int invert

	define "!", 1, , store
	.int store

	define "@", 1, , fetch
	.int fetch

	define "c!", 2, , cstore
	.int cstore

	define "c@", 2, , cfetch
	.int cfetch

	define "exit", 4, , exit
	.int exit

	define "branch", 6, , branch
	.int branch

	define "0branch", 7, , zero_branch
	.int zero_branch

	define "exec", 4, , exec
	.int exec

	// count ( addr -- addr2 len )
	define "count", 5, , count
	.int count

	// tell ( addr -- )
	define "tell", 4, , tell
	.int tell

	define ">number", 7, , to_number
	.int to_number

	define "accept", 6, , accept
	.int accept

	define "word", 4, , word
	.int word

	define "interpret", 9, , interpret
	.int docol
	.int xt_num_tib
	.int xt_fetch
	.int xt_to_in
	.int xt_fetch
	.int xt_equal
	.int xt_zero_branch, intpar
	.int xt_tib
	.int xt_lit, 50
	.int xt_accept
	.int xt_num_tib
	.int xt_store
	.int xt_lit, 0
	.int xt_to_in
	.int xt_store
intpar:
	.int xt_lit, 32
	.int xt_word
	.int xt_find
	.int xt_dup
	.int xt_zero_branch, intnf
	.int xt_state
	.int xt_fetch
	.int xt_equal
	.int xt_zero_branch, intexc
	.int xt_comma
	.int xt_branch, intdone
intexc:
	.int xt_exec
	.int xt_branch, intdone
intnf:
	.int xt_dup
	.int xt_rot
	.int xt_count
	.int xt_to_number
	.int xt_zero_branch, intskip
	.int xt_state, xt_fetch
	.int xt_zero_branch, intnc
	.int xt_last, xt_fetch
	.int xt_dup, xt_fetch
	.int xt_last, xt_store
	.int xt_dp, xt_store
intnc:                                       // Exit infinite loop and reset
	.int xt_quit                            // because of error.
intskip:
	.int xt_drop, xt_drop
	.int xt_state, xt_fetch
	.int xt_zero_branch, intdone
	.int xt_lit, xt_lit, xt_comma, xt_comma
intdone:
	.int xt_branch, xt_interpret            // Infinite loop.

the_final_word:
	define "bye", 3, , bye
	.int exit_program

/* Begin the main assembly code. */

	.text

	/* Main starting point. */
	.global _start
_start:
quit:
	ldr r11, =rstack_base    // Init the return stack.

	ldr r1, =var_state      // Set state to 0 (interpreting)
	eor r0, r0
	str r0, [r1]

	ldr r0, =var_num_tib      // Copy value of "#tib" to ">in".
	ldr r0, [r0]
	ldr r1, =var_to_in
	str r0, [r1]

	ldr r10, =xt_interpret    // Set instruction pointer to interpret
	b next  

docol:
	str r10, [r11, #-4]!    // Save the return address to the return stack
	add r10, r8, #4         // Get the next instruction
	ldr r10, [r10]

	// fall-into next

next:                    // The inner interpreter
	ldr r8, [r10], #4    // Get the next virtual instruction
	ldr r1, [r8]
	bx r1

exit:                     // End a forth word.
	ldr r10, [r11], #4    // ip = pop return stack
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

exit_program:
	mov r0, #0
	mov r7, #os_exit
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

find:
	// TODO
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
	mov r7, #os_write
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
	mov r7, #os_read
	swi #0

	cmp r0, #-1           // read(...) returns -1 upon an error.
	beq exit_program

	mov r9, r0
	b next

word:                     // word - ( char -- addr )
	mov r0, r9            // r0 = char
	ldr r9, =var_dp       // push the dictionary pointer, which is used as a buffer area, "pad"
	ldr r9, [r9]          // r4 = r9 = dp
	mov r4, r9

	ldr r1, =var_tib      // r1 = r2 = tib
	ldr r1, [r1]
	ldr r1, [r1]
	mov r2, r1

	ldr r3, =var_to_in    // r1 += >in, so r1 = pointer into the buffer
	ldr r3, [r3]
	add r1, r3

	ldr r3, =var_num_tib  // r2 += #tib, so r2 = last char address in buffer
	ldr r3, [r3]
	add r2, r3            
word_skip:
	cmp r1, r2
	beq word_done

	ldrb r3, [r1], #1     // get next char
	cmp r0, r3
	beq word_skip
word_copy:
	add r4, #1
	strb r3, [r4]

	cmp r1, r2
	beq word_done
	
	ldrb r3, [r1], #1     // get next char
	cmp r0, r3
	bne word_copy
word_done:
	mov r3, #' '          // write a space to the end of the pad
	str r3, [r4, #1]
	sub r4, r9            // get the length
	strb r4, [r9]         // store the length byte into the first char of the pad

	ldr r3, =var_tib      // Get new value of >in and save it to its variable
	ldr r3, [r3]
	sub r2, r3
	ldr r3, =var_to_in    
	str r2, [r3]

	b next                // TOS (r9) has been pointing to the pad addr the whole time

emit:
	pop {r3}
	ldr r1, =addr_emit_char
	str r3, [r1]
	mov r0, #stdout
	mov r2, #1
	mov r7, #os_write
	swi #0
	b next

enter_compile:               // Exit immediate mode and enter compile mode.
	ldr r0, =var_state
	mov r1, #-1              // true = -1 = compiling
	str r1, [r0]
	b next

enter_immediate:             // Exit compile mode and enter immediate mode.
	ldr r0, =var_state
	eor r1, r1               // false = 0 = not compiling
	str r1, [r0]
	b next

