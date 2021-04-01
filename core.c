#include <stdio.h>
#include <inttypes.h>

#define F_IMMEDIATE 0b10000000
#define F_HIDDEN    0b01000000
#define F_LENMASK   0b00111111

typedef int32_t cell

struct word {
	word * prev;
	char name[32];
	void * code;
	cell params[];
};

cell link = 0;

word * latest;

cell * ip;

void define (char * name, char flags, void * code) {
	
}

the_input_buffer:
	.space 64

	// 256 cells for the return stack, which grows downwards in memory
	.space 4*256
rstack_start:

	// 64 cells for the parameter stack, which grows downwards in memory
pstack_end:
	.space 4*64

void init_words () {
	define("state", 0, *dovar);
}

	define "state", 5, , state, dovar      // 0 variable state
val_state:
	.word 0

	define "h", 2, , h, dovar              // &dictionary_end variable h
val_h:
	.word dictionary_space

	define "base", 4, , base, dovar        // 10 variable base
val_base:
	.word 10

	define "latest", 4, , latest, dovar    // &the_final_word variable latest
val_latest:
	.word the_final_word

	define ">in", 3, , to_in, dovar        // 0 variable >in
val_to_in:
	.word 0

	define "tib", 3, , tib, doconst        // &the_input_buffer constant tib
val_tib:
	.word the_input_buffer

	define "#tib", 4, , num_tib, dovar     // 0 variable #tib
val_num_tib:
	.word 0

	define "F_IMMEDIATE", 11, , const_f_immediate, doconst
	.word F_IMMEDIATE

	define "F_HIDDEN", 8, , const_f_hidden, doconst
	.word F_HIDDEN

	define "F_LENMASK", 9, , const_f_lenmask, doconst
	.word F_LENMASK

	define ">LFA", 4, , to_lfa, docol      // word address to length field address
	.word xt_lit, 4, xt_add
	.word xt_exit

	define ">CFA", 4, , to_cfa, docol
	.word xt_lit, 36, xt_add
	.word xt_exit

	define "'", 1, F_IMMEDIATE, tick, docol       // ( -- xt )
	.word xt_bl, xt_word
	.word xt_find, xt_drop
	.word xt_exit

	define "literal", 7, F_IMMEDIATE, literal, docol    // ( x -- )
	.word xt_lit, xt_lit
	.word xt_comma, xt_comma
	.word exit

	define "recurse", 7, F_IMMEDIATE, recurse, docol
	.word xt_latest, xt_fetch
	.word xt_to_cfa, xt_comma
	.word xt_exit

	define "immediate", 9, , immediate, docol     // ( -- )
	.word xt_latest, xt_fetch, xt_to_lfa
	.word xt_dup, xt_cfetch
	.word xt_lit, F_IMMEDIATE, xt_and
	.word xt_swap, xt_cstore
	.word xt_exit

	define ":", 1, , colon, docol                 // : ( -- )
	.word xt_create                               // Create a new header for the next word.
	.word xt_lit, -1, xt_state, xt_store          // Enter into compile mode
	.word xt_lit, docol, xt_paren_semi_code          // Make "docolon" be the runtime code for the new header.
	.word xt_exit

	define ";", 1, F_IMMEDIATE, semicolon, docol
	.word xt_lit, xt_exit
	.word xt_comma
	.word xt_lit, 0, xt_state, xt_store          // Enter into immediate mode
	.word xt_exit

	define "create", 6, , create, docol
	.word xt_h, xt_fetch
	.word xt_latest, xt_fetch
	.word xt_comma
	.word xt_latest, xt_store
	.word xt_lit, 32
	.word xt_word
	.word xt_count
	.word xt_add
	.word xt_h, xt_store
	.word xt_lit, 0, xt_comma
	.word xt_lit, dovar, xt_paren_semi_code

	// ( x -- )
	define "constant", 5, , constant, docol
	.word xt_create
	.word xt_comma
	.word xt_lit, doconst, xt_paren_semi_code

	define "postpone", 8, F_IMMEDIATE, postpone, docol
	.word xt_state, xt_fetch, xt_zero_branch, 1f   // Must be in compile mode
	.word xt_lit, ' ', xt_word, xt_find
	.word xt_zero_branch, 1f                       // Must find the word
	.word xt_drop, xt_comma
	.word xt_exit
1:	.word xt_paren_semicolon_cancel
	.word xt_quit

	define "]", 1, , right_bracket, docol          // enter compile mode
	.word xt_lit, -1, xt_state, xt_store
	.word xt_exit

	define "[", 1, F_IMMEDIATE, bracket, docol     // enter immediate mode
	.word xt_lit, 0, xt_state, xt_store
	.word xt_exit

	define "BL", 2, , bl, docol                    // ( -- " " )
	.word xt_lit, ' '
	.word xt_exit

	define "CR", 2, , cr, docol                    // ( -- "\n" )
	.word xt_lit, '\n', xt_emit
	.word xt_exit

	define "space", 2, , space, docol              // ( -- )
	.word xt_lit, ' ', xt_emit
	.word xt_exit

	define ">body", 5, , to_body, docol            // ( xt -- addr )
	.word xt_lit, 4, xt_add
	.word xt_exit

	define "interpret-word", 14, , interpret_word, docol  // ( xt 1|-1 -- )
	.word xt_state, xt_fetch, xt_equals
	.word xt_zero_branch, 1f                // =0 means an immediate word or immediate mode
	.word xt_comma
	.word xt_exit
1:	.word xt_execute
	.word xt_exit

	define "interpret-number", 16, , interpret_number, docol    // ( addr 0 -- [<x if interpreting> -1] | [nonzero 0] )
	.word xt_dup                                                // ( -- addr 0 0 )
	.word xt_rot                                                // ( -- 0 0 addr )
	.word xt_count                                              // ( -- 0 0 addr+1 len )
	.word xt_to_number
	.word xt_zero_branch, 1f                      
	.word xt_nip, xt_nip                                        // ( ... -- nonzero ) err parsing number 
	.word xt_lit, 0                                             // ( -- nonzero 0 )
	.word xt_exit
1:	.word xt_drop, xt_drop                                      // parsed a number successfully
	.word xt_state, xt_fetch
	.word xt_zero_branch, 2f
	.word xt_literal                                            // compile "lit <number>"
2:	.word xt_lit, -1                                            // ( i*j -- i*j -1 )
	.word xt_exit

	define "interpret", 9, , interpret, docol      // ( -- -1 | 0 )
	.word xt_bl, xt_word, xt_dup         // ( addr1 addr1 )
	.word xt_find                        // ( addr1 addr2 flag )
	.word xt_zero_branch, 1f       
	.word xt_interpret_word              // try a word
	.word xt_drop                        // ( addr -- )
	.word xt_lit, -1                     // return -1 for success
	.word xt_exit
1:	.word xt_interpret_number            // try a number
	.word xt_zero_branch, 2f
	.word xt_drop, xt_drop               // ( addr flag -- )
	.word xt_lit, -1                     // return -1 for success
	.word xt_exit
2:	.word xt_drop                        // unknown word! ( addr flag -- addr )
	.word xt_cr, xt_tell                 // ( addr -- )
	.word xt_lit, '?', xt_emit           // ask "<name>?"
	.word xt_paren_semicolon_cancel
	.word xt_lit, 0                      // return 0 for error
	.word xt_exit

	define ";cancel", 7, F_IMMEDIATE, semicolon_cancel, docol   
	.word xt_paren_semicolon_cancel
	.word xt_exit

	define "(;cancel)", 9, , paren_semicolon_cancel, docol    // cancel the compilation of the current word
	.word xt_state, xt_fetch
	.word xt_zero_branch, 1f
	.word xt_latest, xt_fetch, xt_dup    
	.word xt_fetch                       
	.word xt_latest, xt_store
	.word xt_h, xt_store
	.word xt_bracket
1:	.word xt_exit

	define "refill", 6, , refill, docol            // ( -- flag )
	.word xt_tib, xt_fetch, xt_num_tib, xt_fetch
	.word xt_accept
	.word xt_lit, 0, xt_to_in, xt_store
	.word xt_lit, -1
	.word xt_exit
	
	define "quit", 4, , quit, docol                // ( -- )
1:	.word xt_no_rstack, xt_bracket 
	.word xt_refill
	.word xt_zero_branch, 5f
	.word xt_drop
2:	.word xt_interpret
	.word xt_lit, -1, xt_equals, xt_zero_branch, 4f
	.word xt_drop
	.word xt_state, xt_fetch, xt_lit, 0, xt_equals, xt_zero_branch, 3f
	.word xt_ok
3:	.word xt_cr, xt_branch, 1b
4:	.word xt_drop                  // error in interpreting
	.word xt_bracket
	.word xt_branch, 3b
5:	.word xt_bye

	define "if", 2, F_IMMEDIATE, if, docol    // ( -- addr )
	.word xt_lit, xt_zero_branch, xt_comma
	.word xt_h, xt_fetch
	.word xt_lit, 0, xt_comma
	.word xt_exit

	define "then", 4, F_IMMEDIATE, then, docol   // ( addr -- )
	.word xt_h, xt_fetch
	.word xt_store
	.word xt_exit

	define "else", 4, F_IMMEDIATE, else, docol   // ( prev-if -- prev-else )
	.word xt_lit, xt_branch, xt_comma
	.word xt_h, xt_fetch                         // (prev-if prev-else )
	.word xt_lit, 0, xt_comma
	.word xt_h, xt_fetch                         // (prev-if prev-else h )
	.word xt_rot                                 // ( prev-else h prev-if )
	.word xt_store                               // ( prev-else )
	.word xt_exit

/* All of these following words are implemented in assembly */

	define "!", 1, , store, store
	define "ok", 0, , ok, ok
	define "&", 1, , and, do_and
	define "(;code)", 7, , paren_semi_code, paren_semi_code
	define "*", 1, , multiply, multiply
	define "+", 1, , add, add
	define ",", 1, , comma, comma
	define "-", 1, , sub, sub
	define "/", 1, , divide, divide
	define "/mod", 4, , divmod, divmod
	define "0branch", 7, , zero_branch, zero_branch
	define "<", 1, , lt, lt
	define "=", 1, , equals, equals
	define ">", 1, , gt, gt
	define ">R", 2, , to_r, to_r
	define ">number", 7, , to_number, to_number // ( double addr len -- [double addr2 0] | [int addr2 nonzero] )
	define "@", 1, , fetch, fetch
	define "R>", 2, , r_from, r_from
	define "^", 1, , xor, xor
	define "abs", 3, , abs, abs
	define "accept", 6, , accept, accept
	define "branch", 6, , branch, branch
	define "c!", 2, , cstore, cstore
	define "c@", 2, , cfetch, cfetch
	define "count", 5, , count, count
	define "drop", 4, , drop, drop
	define "dup", 3, , dup, dup
	define "emit", 4, , emit, emit
	define "execute", 4, , execute, execute
	define "exit", 4, , exit, exit
	define "find", 4, , find, find
	define "invert", 6, , invert, invert
	define "lit", 3, , lit, lit
	define "mod", 3, , mod, mod
	define "negate", 6, , negate, negate
	define "nip", 3, , nip, nip
	define "no_rstack", 9, , no_rstack, no_rstack
	define "over", 4, , over, over
	define "rot", 3, , rot, rot
	define "swap", 4, , swap, swap
	define "tell", 4, , tell, tell
	define "word", 4, , word, word
	define "words", 5, , words, words
	define "|", 1, , or, do_or
the_final_word:
	define "bye", 3, , bye, bye

dictionary_space:
	.space 2048

/* Addresses of variables in the data section */

	.text
	.align 2

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

/*
 * Begin the main assembly code.
 */

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

	ldr r0, =var_num_tib      // Copy value of "#tib" to ">in".
	ldr r0, [r0]
	ldr r0, [r0]
	ldr r1, =var_to_in
	ldr r1, [r1]
	str r0, [r1]

	ldr r10, =init_xt
	b next

init_xt:
	.word xt_quit

// DEBUG purposes
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


paren_semi_code:             // (;code) - ( addr -- ) replace the xt of the word being defined with addr
	ldr r0, =var_latest
	ldr r0, [r0]
	add r0, #36           // Offset to Code Field Address.
	str r9, [r0]          // Store the code address into the Code Field.
	pop {r9}
	b next


bye_msg: .ascii " bye"
bye_msg_end:
	.align 2
bye:
	mov r4, r0
	mov r7, #sys_write
	mov r0, #stdout
	ldr r1, =bye_msg
	mov r2, #bye_msg_end - bye_msg
	mov r0, r4
exit_program:
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


find:                       // find - ( addr -- addr2 0 | xt 1 | xt -1 ) 1=immediate, -1=not immediate
	ldr r0, =var_latest     // r0 = current word link field address
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


equals:
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


branch:                   // note: not a relative branch!
	ldr r10, [r10]        // add 4 first or after or at all??
	b next


zero_branch:              // note: not a relative branch!
	cmp r9, #0
	ldreq r10, [r10]
	addne r10, #4
	pop {r9}
	b next


execute:
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


to_number:               // ( double addr len -- [double addr2 0] | [int addr2 nonzero] )
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

	mov r7, #sys_read     // read(fd=r0, buf=r1, count=r2)
	mov r0, #stdin
	mov r2, r9            
	swi #0

	cmp r0, #-1           // the call returns a -1 upon an error.
	beq exit_program

	mov r9, r0
	b next


word:                     // word - ( char -- addr )
	ldr r1, =const_tib      // r1 = r2 = tib
	ldr r1, [r1]
	mov r2, r1

	ldr r3, =var_to_in    // r1 += >in, so r1 = pointer into the buffer
	ldr r3, [r3]
	ldr r3, [r3]
	add r1, r3

	ldr r3, =var_num_tib  // r2 += #tib, so r2 = last char address in buffer
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

	ldr r0, =const_tib      // get length inside the input buffer (includes the skipped whitespace)
	ldr r0, [r0]
	sub r1, r0

	ldr r0, =var_to_in    // store back to the variable ">in"
	ldr r0, [r0]
	str r1, [r0]

	b next                // TOS (r9) has been pointing to the pad addr the whole time

	
words:                      // list all words
	ldr r0, =var_latest     // r0 = current word link field address
	ldr r0, [r0]            // (r0 will be correctly dereferenced again in the 1st iteration of loop #1)

1:                          // Loops through the dictionary linked list.
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq exit_program // DEBUG TODO REMOVE
	beq next

	ldrb r2, [r0, #4]       // get word length+flags byte

	tst r2, #F_HIDDEN       // skip hidden words
	bne 1b

	and r2, #F_LENMASK      // get actual length

	push {r0-r2}            // write out the string
	mov r7, #sys_write
	mov r0, #stdout
	add r1, r9, #5
	swi #0
	pop {r0-r2}

	mov r0, #' '            // write a trailing space
	bl do_emit

	b 1b

	
emit:                       // emit ( char -- )
	mov r0, r9
	bl do_emit
	pop {r9}
	b next


do_emit:                    // void do_emit(char);
	push {r4-r11, lr}
	ldr r1, =var_h          // store the char temporarily in pad
	ldr r1, [r1]
	ldr r1, [r1]
	strb r0, [r1]

	mov r7, #sys_write      // call write(...) with the pad address
	mov r0, #stdout
	mov r2, #1
	swi #0

	pop {r4-r11, lr}        // return
	bx lr


tell:                       // tell ( c-addr -- ) print out a counted string
	ldr r2, [r9]

	mov r7, #sys_write
	mov r0, #stdout
	add r1, r9, #1
	swi #0

	pop {r9}
	b next


	// Function for integer division modulo
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


nip:                            // nip ( x y -- y )
	pop {r0}
	b next


no_rstack:
	ldr r11, =rstack_start      // Init or reset the return stack.
	b next


abs:                            // ( x -- +x ) absolute value
	cmp r9, #0
	neglt r9, r9
	b next


ok:
	mov r7, #sys_write
	mov r0, #stdout
	ldr r1, =ok_msg
	mov r2, #ok_msg_end - ok_msg
	swi #0
	b next
ok_msg: .ascii " ok"
ok_msg_end:

