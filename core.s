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

// Macro system for defining a word header in the data section

	// Previous word link pointer for while it's assembling word defs
	.set link, 0

	// The macro defines a word with it's name (and length), flags, xt, and runtime code
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

// Begin normal program data, which needs to be before the dictionary because the dictionary will grow upwards in memory.

 	.data

	// DEBUG {
	.align 2
docol_word_data:
	.word 0

	.align 2
docol_return_data:
	.word 0
	// }

	.align 2
the_input_buffer:
	.space 64

	// 256 cells for the return stack, which grows downwards in memory
	.align 2
rstack_end:
	.space 4*256
rstack_start:

	// 64 cells for the parameter stack, which grows downwards in memory
	.align 2
pstack_end:
	.space 4*64
pstack_start:

// Begin word header definitions.
	.data
	.align 2

	define "true", 4, , true, doconst
	// -1 constant true
	.word -1

	define "false", 5, , false, doconst
	// 0 constant false
	.word 0

	define "S0", 2, , s_zero, doconst
	.word pstack_start

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

	// decimal ( -- ) change to base 10
	define "decimal", 7, , decimal, docol
	.word xt_lit, 10
	.word xt_base, xt_store
	.word xt_exit

	// hex ( -- ) change to base 16
	define "hex", 3, , hex, docol
	.word xt_lit, 16
	.word xt_base, xt_store
	.word xt_exit

	// source ( -- c-addr u ) length and address of input to use
	define "source", 6, , source, docol
	.word xt_tib
	.word xt_to_in, xt_fetch
	.word xt_num_tib, xt_fetch
	.word xt_minus
	.word xt_exit

	define ">LFA", 4, , to_lfa, docol
	// ( addr -- addr2 ) word address to length field address
	.word xt_lit, 4, xt_plus
	.word xt_exit

	define ">CFA", 4, , to_cfa, docol
	.word xt_lit, 36
	.word xt_plus
	.word xt_exit

	define ">body", 5, , to_body, docol
	// ( xt -- addr )
	.word xt_lit, 4, xt_plus
	.word xt_exit

	define "'", 1, F_IMMEDIATE, tick, docol
	// ( -- xt )
	.word xt_bl, xt_word
	.word xt_find, xt_drop
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

	define "recurse", 7, F_IMMEDIATE, recurse, docol
	.word xt_latest, xt_fetch
	.word xt_to_cfa, xt_comma
	.word xt_exit

	define "immediate", 9, , immediate, docol
	// ( -- )
	.word xt_latest, xt_fetch
	.word xt_to_lfa
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
	.word xt_cell_minus
	.word xt_store
	.word xt_right_bracket                        // Enter into compile mode
	.word xt_exit

	define ";", 1, F_IMMEDIATE, semicolon, docol
	// ( -- ) end a colon definition while still in compile mode
	.word xt_lit, xt_exit     // append "exit" to the word definition
	.word xt_comma
	.word xt_bracket          // Enter into immediate mode
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

	define "create", 6, , create, docol
	// ( -- ) create a word header with the next word in the input stream as a name
	// when name is executed, it will push the address of it's data field
	.word xt_align
	.word xt_h, xt_fetch        // compile the link field
	.word xt_latest, xt_fetch
	.word xt_comma
	.word xt_latest, xt_store   // make this word the latest one
	.word xt_bl                 // get a word from the input
	.word xt_word
	.word xt_count              // ( c-addr len )
	.word xt_dup                // ( c-addr len len )
	.word xt_c_comma            // ( c-addr len ) write the name length
	.word xt_h, xt_fetch        // ( c-addr len here )
	.word xt_swap               // ( c-addr here len )
	.word xt_c_move             // write the name
	.word xt_h, xt_fetch        // make sure to increment "here" to after the name
	.word xt_lit, 31
	.word xt_plus
	.word xt_h
	.word xt_store              // here has been incremented
	.word xt_lit, dovar         // make this header push it's data field address when it is executed
	.word xt_comma
	.word xt_exit

	define "2dup", 4, , two_dup, docol
	// ( x y -- x y x y )
	.word xt_over
	.word xt_over
	.word xt_exit

	define "2drop", 5, , two_drop, docol
	// ( x y -- )
	.word xt_drop
	.word xt_drop
	.word xt_exit

	define "2swap", 5, , two_swap, docol
	// ( x y z w -- z w x y )
	.word xt_to_r
	.word xt_minus_rot
	.word xt_r_from
	.word xt_minus_rot
	.word xt_exit

	define "cmove1", 6, , c_move_one, docol
	// ( c-addr1 c-addr2 -- ) copy one character from c-addr1 to c-addr2
	.word xt_swap      // ( c-addr2 c-addr1 )
	.word xt_c_fetch   // ( c-addr2 c )
	.word xt_swap      // ( c c-addr2 )
	.word xt_c_store
	.word xt_exit

	define "move1", 5, , move_one, docol
	// ( addr1 addr2 -- ) copy one cell from addr1 to addr2
	.word xt_swap
	.word xt_aligned
	.word xt_fetch
	.word xt_swap
	.word xt_aligned
	.word xt_store
	.word xt_exit

	define "cmove", 5, , c_move, docol
	// ( c-addr1 c-addr2 u -- ) - copy u chars from c-addr1 to c-addr2
	.word xt_over              // save the final c-addr2 to the return stack
	.word xt_plus
	.word xt_to_r
1:	.word xt_two_dup           // loop to copy chars:
	.word xt_c_move_one         // copy one char
	.word xt_one_plus          // increment both of the c-addr
	.word xt_swap
	.word xt_one_plus
	.word xt_swap
	.word xt_dup               // see if the c-addr2 is the final c-addr in the return stack
	.word xt_r_dup
	.word xt_r_from
	.word xt_equals
	.word xt_zero_branch, 1b   // keep copying chars until they are equal
	.word xt_r_drop             // clean the return stack
	.word xt_drop              // clean the parameter stack
	.word xt_drop
	.word xt_exit

	define "move", 4, , move, docol
	// ( addr1 addr2 u -- ) - copy u cells from addr1 to addr2
	.word xt_over              // save the final addr2 to the return stack
	.word xt_plus
	.word xt_to_r
1:	.word xt_two_dup           // loop to copy cells:
	.word xt_move_one          // copy one cell
	.word xt_one_plus          // increment both of the addr
	.word xt_swap
	.word xt_one_plus
	.word xt_swap
	.word xt_dup               // see if the addr2 is the final addr in the return stack
	.word xt_r_dup
	.word xt_r_from
	.word xt_equals
	.word xt_zero_branch, 1b   // keep copying until they are equal
	.word xt_r_drop             // clean the return stack
	.word xt_drop              // clean the parameter stack
	.word xt_drop
	.word xt_exit

	define "constant", 8, , constant, docol
	// ( x -- )
	.word xt_create           // create the first part of the header
	.word xt_comma            // compile x to the data field
	.word xt_lit, doconst     // make 'doconst' be the codeword
	.word xt_latest
	.word xt_fetch
	.word xt_to_cfa           // ( doconst cfa )
	.word xt_store
	.word xt_exit

	define "postpone", 8, F_IMMEDIATE, postpone, docol
	// ( -- ) compile the following word
	.word xt_state, xt_fetch          // ( f )
	.word xt_zero_branch, 2f          // Must be in compile mode
	.word xt_find_word_question
	.word xt_zero_branch, 1f          // ( xt ) must find
	.word xt_comma
	.word xt_exit
1:	.word xt_paren_semicolon_cancel
	.word xt_quit
2:	.word xt_exit

	define "]", 1, , right_bracket, docol
	// ( -- ) enter compile mode
	.word xt_lit, -1, xt_state, xt_store
	.word xt_exit

	define "[", 1, F_IMMEDIATE, bracket, docol
	// ( -- ) enter immediate mode
	.word xt_lit, 0, xt_state, xt_store
	.word xt_exit

	define "cs>number", 9, , cs_to_number, docol
	// ( ca1 -- ud ca2 len )
	.word xt_lit, 0
	.word xt_lit, 0
	.word xt_rot
	.word xt_to_number
	.word xt_exit

	define "do-compile", 10, , do_compile, docol
	// ( -- / x*i -- x*j )
	.word xt_find_word_question       // ( xt f )
	.word xt_dup                      // ( xt f f )
	.word xt_zero_branch, 4f          // ( xt f )
	.word xt_lit, 1
1:	.word xt_equals                   // ( xt f2 )
	.word xt_zero_branch, 3f          // ( xt f2 -- xt )
2:	.word xt_execute                  // ( )
	.word xt_exit
3:	.word xt_comma                    // ( )
	.word xt_exit
4:	.word xt_drop                     // ( ca )
	.word xt_cs_to_number             // ( ud ca2 len )
	.word xt_zero_branch, 6f          // ( ud ca2 )
5:	.word xt_drop                     // ( ud )
	.word xt_two_drop                 // ( )
	.word xt_paren_semicolon_cancel
	.word xt_quit
6:	.word xt_drop                     // ( ud )
	.word xt_drop                     // ( u )
	.word xt_lit, xt_lit
	.word xt_comma
	.word xt_comma                    // ( )
	.word xt_exit

	define "do-interpret", 12, , do_interpret, docol
	// ( -- n / x*i -- x*j )
	.word xt_find_word_question  // ( c-addr 0 | xt f )
	.word xt_zero_branch, 1f     // ( c-addr | xt )
	.word xt_execute             // ( xt -- )
	.word xt_exit
1:	.word xt_cs_to_number        // ( c-addr -- ud c-addr2 u )
	.word xt_zero_branch, 2f     // ( ud c-addr2 )
	.word xt_quit
2:	.word xt_drop                // ( ud c-addr2 -- u )
	.word xt_drop
	.word xt_exit

	define ";cancel", 7, F_IMMEDIATE, semicolon_cancel, docol
	.word xt_state, xt_fetch
	.word xt_zero_branch, 1f                                  // make sure it's in compile mode
	.word xt_paren_semicolon_cancel
1:	.word xt_exit

	define "(;cancel)", 9, , paren_semicolon_cancel, docol
	// ( -- ) cancel the compilation of the current word
	.word xt_latest, xt_fetch
	.word xt_dup
	.word xt_fetch
	.word xt_latest, xt_store
	.word xt_h, xt_store
	.word xt_bracket
	.word xt_exit

	define "refill", 6, , refill, docol
	// ( -- flag )
	.word xt_tib, xt_fetch, xt_num_tib, xt_fetch
	.word xt_accept
	.word xt_lit, 0, xt_to_in, xt_store
	.word xt_lit, -1
	.word xt_exit

	define "interpret", 9, , interpret, docol
	// ( -- )
	.word xt_source
	.word xt_to_in, xt_fetch
	.word xt_equals
	.word xt_zero_branch, 1f
	.word xt_refill            // ( f )
	.word xt_zero_branch, 3f   // no input available
1:	.word xt_state, xt_fetch
	.word xt_zero_branch, 2f
	.word xt_do_compile
	.word xt_exit
2:	.word xt_do_interpret
	.word xt_exit
3:	.word xt_bye

	define "interpreter", 11, , interpreter, docol
	// ( -- )
1:	.word xt_interpret
	.word xt_branch, 1b
	// no exit because it's an infinite loop

	define "quit", 4, , quit, docol
	// ( -- )
	.word xt_r_zero       // clear the return stack
	.word xt_rsp_store
	.word xt_bracket      // enter immediate mode
	.word xt_interpreter  // start interpreting
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

	define "cells", 5, , cells, docol
	// ( x -- x )
	.word xt_lit, 4
	.word xt_star
	.word xt_exit

	define "cell-", 5, , cell_minus, docol
	// ( x -- x )
	.word xt_lit, 4
	.word xt_minus
	.word xt_exit

	define "cell+", 5, , cell_plus, docol
	// ( x -- x )
	.word xt_lit, 4
	.word xt_plus
	.word xt_exit

	define "chars", 5, , chars, docol
	// ( x -- x )
	.word xt_exit

	define "char+", 5, , char_plus, docol
	.word xt_one_plus
	.word xt_exit

	define "char-", 5, , char_minus, docol
	.word xt_one_minus
	.word xt_exit

	define "PSP@", 4, , psp_fetch, psp_fetch
	// ( -- addr )

	define "PSP!", 4, , psp_store, psp_store
	// ( addr -- )

	define "RSP@", 4, , rsp_fetch, rsp_fetch
	// ( -- addr )

	define "RSP!", 4, , rsp_store, rsp_store
	// ( addr -- )

	define "depth", 5, , depth, docol
	// ( -- x ) where x is the stack depth
	.word xt_s_zero, xt_fetch
	.word xt_psp_fetch
	.word xt_minus
	.word xt_cell_minus
	.word xt_exit

	define "id.", 3, , id_dot, docol
	// ( xt -- )
	.word xt_lit, -32
	.word xt_plus
	.word xt_dup
	.word xt_one_plus
	.word xt_swap
	.word xt_fetch
	.word xt_f_lenmask
	.word xt_and
	.word xt_tell
	.word xt_exit

	define "and", 3, , and, do_and
	// ( x y -- z )
	// z: the result of bitwise and-ing of x and y

	define "max", 3, , max, docol
	// ( x y -- x | y )
	// Chooses to keep the maximum of x and y on the stack.
	.word xt_two_dup
	.word xt_more
	.word xt_zero_branch, 1f
	.word xt_swap
1:	.word xt_drop
	.word xt_exit

	define "min", 3, , min, docol
	// ( x y -- x | y )
	// Chooses to keep the minimum of x and y on the stack.
	.word xt_two_dup
	.word xt_less
	.word xt_zero_branch, 1f
	.word xt_swap
1:	.word xt_drop
	.word xt_exit

	define "*", 1, , star, multiply
	// ( x y -- z ) z:x*y

	define "+", 1, , plus, add
	// ( x y -- z ) z:x+y

	define "invert", 6, , invert, invert
	// ( x -- y )
	// y: the bitwise inverse of x

	define "mod", 3, , mod, mod
	// ( x y -- z )
	// z: result of x mod y

	define "negate", 6, , negate, negate
	// ( x -- y )
	// y: negative x

	define "1+", 2, , one_plus, increment

	define "-", 1, , minus, sub
	// ( x1 x2 -- x3 )
	// x3 = x1 - x2

	define "1-", 2, , one_minus, decrement

	define "/", 1, , slash, divide
	// ( x y -- z ) z: x / y

	define "/mod", 4, , slash_mod, divmod

	define "<", 1, , less, less
	// ( x y -- f )
	// f: x < y

	define "=", 1, , equals, equals
	// ( x y -- f ) f:x=y?

	define ">", 1, , more, more
	// ( x y -- f )
	// f: x > y

	define ">R", 2, , to_r, to_r
	// ( x -- R: -- x )

	define "R>", 2, , r_from, r_from
	// ( -- x R: x -- )

	define "Rdrop", 5, , r_drop, docol
	// ( -- R: x -- )
	.word xt_r_from
	.word xt_drop
	.word xt_exit

	define "Rdup", 4, , r_dup, docol
	// ( -- R: x -- x x )
	.word xt_r_from
	.word xt_dup
	.word xt_to_r
	.word xt_to_r
	.word xt_exit

	define ">number", 7, , to_number, to_number
	// ( d c-addr1 u -- d c-addr2 0 | x addr2 nonzero )

	define "!", 1, , store, store
	// ( x addr -- )
	// x: the value to be stored in memory at the addr

	define "@", 1, , fetch, fetch
	// ( addr -- x )
	// x: the cell value stored in memory at addr

	define "c!", 2, , c_store, c_store
	// ( c c-addr -- )

	define "c@", 2, , c_fetch, c_fetch
	// ( c-addr -- c )
	// c: the char stored in c-addr

	define "xor", 3, , xor, xor
	// ( x y -- z ) z = x XOR y

	define "abs", 3, , abs, abs
	// ( x -- y )
	// y: absolute value of x

	define "accept", 6, , accept, accept
	// ( c-addr len -- len2 )
	// c-addr: the address to store characters into
	// len: the number of characters to accept from input
	// len2: the number of characters actually received (will not be greater than len)

	define "count", 5, , count, count
	// ( c-addr1 -- c-addr2 u )
	// u: the length of the counted string at c-addr1
	// c-addr2: the address of the first character of the counted string

	define "drop", 4, , drop, drop
	// ( x -- )

	define "dup", 3, , dup, dup
	// ( x -- x x )

	define "nip", 3, , nip, nip
	// ( x y -- y )

	define "over", 4, , over, over
	// ( x y -- x y x )

	define "rot", 3, , rot, rot
	// ( x y z -- y z x )

	define "-rot", 4, , minus_rot, minus_rot
	// -rot ( x y z -- z x y )

	define "swap", 4, , swap, swap
	// ( x y -- y x )

	define "tuck", 4, , tuck, docol
	// ( x y -- y x y )
	.word xt_swap
	.word xt_over
	.word xt_exit

	define "execute", 7, , execute, execute
	// ( xt -- )

	define "branch", 6, , branch, branch

	define "0branch", 7, , zero_branch, zero_branch

	define "find", 4, , find, find
	// ( c-addr -- c-addr 0 | xt -1 | xt 1 )

	define "find-word?", 10, , find_word_question, docol
	// ( -- c-addr 0 | xt -1 | xt 1 )
	.word xt_bl
	.word xt_word
	.word xt_find
	.word xt_exit

	define "emit", 4, , emit, emit
	// ( c -- )
	// Emit a character to the output stream

	define "BL", 2, , bl, docol
	// ( -- c )
	// push a space character
	.word xt_lit, ' '
	.word xt_exit

	define "CR", 2, , cr, docol
	// ( -- )
	// emit a newline character
	.word xt_lit, '\n', xt_emit
	.word xt_exit

	define "space", 5, , space, docol
	// ( -- )
	// emit a space
	.word xt_bl
	.word xt_emit
	.word xt_exit

	define "tell", 4, , tell, tell
	// ( c-addr u -- )
	// Print out a counted string
	// u: length of counted string

	define "word", 4, , word, word
	// ( c -- c-addr )
	// c: character delimiting the word to get from input
	// c-addr: counted string of the word received

	define "char", 4, , char, docol
	// ( -- c )
	.word xt_bl
	.word xt_word
	.word xt_char_plus
	.word xt_c_fetch
	.word xt_exit

	define "words", 5, , words, docol
	// ( -- ) print all words currently in the dictionary
	.word xt_latest
	.word xt_fetch              // ( link )
1:	.word xt_dup                // ( link link )
	.word xt_zero_branch, 4f    // ( link ) break the loop at the end of the dictionary
	.word xt_dup                // ( link link )
	.word xt_break
	.word xt_to_cfa             // ( link xt )
	.word xt_question_hidden    // ( link f )
	.word xt_zero_branch, 2f
	.word xt_branch, 3f
2:	.word xt_dup                // ( link link )
	.word xt_to_cfa             // ( link xt )
	.word xt_id_dot             // ( link )
	.word xt_space
3:	.word xt_fetch              // ( link->link )
	.word xt_branch, 1b
4:	.word xt_drop               // ( 0 -- )
	.word xt_cr
	.word xt_exit

	define "?hidden", 7, , question_hidden, docol
	// ( xt -- f )
	.word xt_break
	.word xt_lit, -32
	.word xt_plus                 // ( c-addr )
	.word xt_break
	.word xt_c_fetch              // ( len+flags )
	.word xt_f_hidden
	.word xt_and                  // ( F_HIDDEN | 0 )
	.word xt_zero_equals
	.word xt_invert
	.word xt_exit

	define "break", 5, , break, break

	define "0=", 2, , zero_equals, docol
	// ( x -- f )
	.word xt_lit, 0
	.word xt_equals
	.word xt_exit

	define "or", 2, , or, do_or
	// ( x y -- x|y ) bitwise or

	define "aligned", 7, , aligned, docol
	// ( c-addr -- addr ) align an address to a cell
	.word xt_lit, 3
	.word xt_plus
	.word xt_lit, 3
	.word xt_invert
	.word xt_and
	.word xt_exit

	define "align", 5, , align, docol
	// ( -- ) make the address of h(ere) aligned
	.word xt_h, xt_fetch
	.word xt_aligned
	.word xt_h, xt_store
	.word xt_exit

	define "ctell", 5, , c_tell, docol
	// ( c-addr -- )
	.word xt_count
	.word xt_tell
	.word xt_exit

	define "init", 4, , init, docol
	// ( x*i -- R: x*j -- )
	.word xt_s_zero               // initialize the parameter stack
	.word xt_psp_store
	.word xt_decimal
	.word xt_num_tib, xt_fetch    // set >in to #tib so that we need to get input
	.word xt_to_in, xt_store
	.word xt_quit                 // start the interpreter
	// no exit because quit does not return

	define "test_", 5, F_HIDDEN, test_, docol
	.word xt_words
	.word xt_bye

	define "syscall0", 8, , syscall_zero, syscall_zero
	// ( X -- )

	define "syscall1", 8, , syscall_one, syscall_one
	// ( x X -- )

	define "syscall2", 8, , syscall_two, syscall_two
	// ( x x X -- )

	define "syscall3", 8, , syscall_three, syscall_three
	// ( x x x X -- )

	define "syscall4", 8, , syscall_four, syscall_four
	// ( x x x x X -- )

	define "syscall5", 8, , syscall_five, syscall_five
	// ( x x x x x X -- )

	define "syscall6", 8, , syscall_six, syscall_six
	// ( x x x x x x X -- )

the_final_word:

	define "bye", 3, , bye, bye
	// ( -- ) exit the program (successfully)

dictionary_space:
	.space 2048

// Variable literal pool for assembly code to reference.

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

	// DEBUG purposes {
docol_word:
	.word docol_word_data
docol_return:
	.word docol_return_data
	// }

// Begin the main assembly code.

	.global _start
_start:
	ldr sp, =pstack_start    // init parameter stack
	ldr r11, =rstack_start   // init return stack
	mov r9, #0               // zero out the top of the stack
	ldr r10, =init_code      // launch the interpreter with the "init" word
	b next
init_code:
	.word xt_test_

docol:
	// DEBUG purposes {
	ldr r0, =docol_word
	ldr r0, [r0]
	str r8, [r0]
	ldr r0, =docol_return
	ldr r0, [r0]
	str r10, [r0]
docol2:
	// } DEBUG purposes
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


bye:
	mov r0, #0           // successful exit code
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


c_comma:
	ldr r0, =var_h
	ldr r0, [r0]
	cpy r1, r0
	ldr r0, [r0]

	strb r9, [r0, #1]!      // This line is the only difference with "comma" (see above)
	str r0, [r1]

	pop {r9}
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


minus_rot:                  // -rot ( x y z -- z x y )
	pop {r0}            // r0 = y
	pop {r1}            // r1 = x
	push {r9}           // push z
	push {r1}           // push x
	mov r9, r0          // push y
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


increment:
	add r9, #1
	b next


decrement:
	sub r9, #1
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


// TODO: should this push to the return stack?
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


// TODO: this algorithm may be wrong
to_number:                   // ( d c-addr1 u -- d c-addr2 0 | x addr2 nonzero )
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
word_skip:                      // skip leading whitespace
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

	ldr r0, =const_tib        // get length inside the input buffer (includes the skipped whitespace)
	ldr r0, [r0]
	sub r1, r0

	ldr r0, =var_to_in      // store back to the variable ">in"
	ldr r0, [r0]
	str r1, [r0]

	b next                  // TOS (r9) has been pointing to the pad addr the whole time


emit:                           // emit ( char -- )
	mov r0, r9
	bl fn_emit
	pop {r9}
	b next


fn_emit:                        // void fn_emit(char);
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


tell:                       // tell ( c-addr u -- ) u: string length. Emit a counted string
	mov r2, r9          // len = u
	pop {r1}            // buf = [pop]

	mov r7, #sys_write
	mov r0, #stdout
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


abs:                            // ( x -- +x ) absolute value
	cmp r9, #0
	neglt r9, r9
	b next


break:
	mov r0, r0
	b next


syscall_zero:
	mov r7, r9         ; get the syscall id from TOS
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next


syscall_one:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall_two:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall_three:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall_four:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall_five:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	pop {r4}     // get the 5th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall_six:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	pop {r4}     // get the 5th arg from stack
	pop {r5}     // get the 6th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next

