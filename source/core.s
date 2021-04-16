/* Forth Implementation in ARMv7 assembly for GNU/Linux eabi by Izak Nathanael
Halseide. This is an indirect threaded forth. The top of the parameter stack
is stored in register R9. The parameter stack pointer (PSP) is stored in
register R13. The parameter stack grows downwards. The return stack pointer
(RSP) is stored in register R11. The return stack grows downwards. The forth
virtual instruction pointer (IP) is stored in register R10. The address of the
current execution token (XT) is stored in register R8. */

// Word bitmasks constant
.set F_LENMASK, 0b00011111

// The inner interpreter
.macro NEXT
	ldr r8, [r10], #4       // r10 = the virtual instruction pointer
	ldr r0, [r8]            // r8 = xt of current word
	bx r0
.endm

// Word header definition macros
.set link, 0

.macro defcode name, len, label
	.section .rodata
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len               // name field
	.ascii "\name"
	.space 31-\len
	.align 2
	.global xt_\label
xt_\label:                   // code field
	.int code_\label
params_\label:               // parameter field
	.text
	.align 2
	.global code_\label
code_\label:
.endm

.macro defword name, len, label
	.section .rodata
	.align 2                 // link field
	.global def_\label
def_\label:
	.int link
	.set link, def_\label
	.byte \len               // name field
	.ascii "\name"
	.space 31-\len
	.align 2
	.global xt_\label
xt_\label:                   // code field
	.int enter_colon
params_\label:               // parameter field
.endm

.data

.align 2
.set NUM_TIB, 1024
input_buffer: .space NUM_TIB

.align 2
.set NUM_TOB, 1024
output_buffer: .space NUM_TOB

dictionary:

def "!", 1, store, store
def "c!", 2, c_store, c_store
def "@", 1, fetch, fetch
def "c@", 2, c_fetch, c_fetch
def "=", 1, equals, equals
def "<", 1, less, less
def ">", 1, more, more
def "+", 1, plus, plus
def "-", 1, minus, minus
def "*", 1, star, star
def "/", 1, slash, slash
def "/mod", 4, slash_mod, slash_mod
def "mod", 3, mod, mod
def "negate", 6, negate, negate
def "not", 3, not, not
def "and", 3, and, and
def "or", 2, or, or
def "xor", 3, xor, xor
def "dup", 3, dup, dup
def "drop", 4, drop, drop
def "swap", 4, swap, swap
def "nip", 3, nip, nip
def "over", 4, over, over
def "PSP!", 4, psp_store, psp_store
def "PSP@", 4, psp_fetch, psp_fetch
def "RSP!", 4, rsp_store, rsp_store
def "RSP@", 4, rsp_fetch, rsp_fetch
def ">R", 2, to_r, to_r
def "R>", 2, r_from, r_from
def "key", 3, key, key
def "emit", 4, emit, emit
def "exit", 4, exit, exit
def "lit", 3, lit, lit
def "branch", 6, branch, branch
def "0branch", 7, zero_branch, zero_branch
def "create", 6, create, create
def "'", 1, tick, tick
def ",", 1, comma, comma
def "c,", 1, c_comma, c_comma
def "execute", 7, execute, execute
def "skip", 4, skip, skip
def "word", 4, word, word
def "find", 4, find, find
def ">num", 4, to_num, to_num
def "halt", 4, halt, halt

def "S0", 2, s_zero, do_constant
	.word 0x100

def "R0", 2, r_zero, do_constant
	.word 0x8000

def "H", 1, h, do_variable
	.word freespace

def "latest", 6, latest, do_variable
	.word the_last_word

def ">in", 3, to_in, do_variable
	.word 0

def "#tib", 4, num_tib, do_constant
	.word NUM_TIB

def "tib", 3, tib, do_constant
	.word input_buffer

def ">out", 3, to_out, do_variable
	.word 0

def "#tob", 4, num_tob, do_constant
	.word NUM_TOB

def "tob", 3, tob, do_constant
	.word output_buffer

def "enter", 5, enter, do_constant
	.word enter

def "variable", 8, variable, enter
	.word xt_create
	.word xt_lit, xt_do_variable
	.word xt_comma
	.word xt_lit, 0
	.word xt_comma
	.word xt_exit

def "constant", 8, constant, enter
	.word xt_create
	.word xt_lit, xt_do_constant
	.word xt_comma
	.word xt_comma
	.word xt_exit

the_last_word:

def "quit", 4, quit, enter
	.word xt_halt

free:

.text

init_code: .word xt_quit

.global _start
_start:
	ldr sp, =0x100           // init parameter stack
	ldr r11, =0x8000         // init return stack

	mov r9, #0               // zero the TOS register

	ldr r10, =init_code      // start the inner interpreter
	NEXT

next:                        // Inner interpreter
	NEXT

enter_colon:
	str r10, [r11, #-4]!     // Save the return address to the return stack
	add r10, r8, #4          // Get the next instruction
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

exit:                        // End a forth word.
	ldr r10, [r11], #4       // ip = pop return stack
	NEXT

halt:
	b halt

lit:
	push {r9}                // Push the next virtual instruction value to the stack.
	ldr r9, [r10], #4
	NEXT

comma:
	ldr r0, =params_h
	cpy r1, r0
	ldr r0, [r0]

	str r9, [r0, #4]!    // *H = TOS
	str r0, [r1]         // H += 4

	pop {r9}
	NEXT

c_comma:
	ldr r0, =params_h
	cpy r1, r0
	ldr r0, [r0]

	strb r9, [r0, #1]!   // *H = TOS
	str r0, [r1]         // H += 1

	pop {r9}
	NEXT

psp_fetch:
	push {r9}
	mov r9, sp
	NEXT

psp_store:
	mov sp, r9
	NEXT

rsp_fetch:
	push {r9}
	mov r9, r11
	NEXT

rsp_store:
	mov r11, r9
	pop {r9}
	NEXT

dup:
	push {r9}
	NEXT

drop:
	pop {r9}
	NEXT

nip:
	pop {r0}
	NEXT

swap:
	pop {r0}
	push {r9}
	mov r9, r0
	NEXT

over:
	ldr r0, [r13]       // get a copy of the second item on stack
	push {r9}           // push TOS to the rest of the stack
	mov r9, r0          // TOS = copy of the second item from earlier
	NEXT

to_r:
	str r9, [r11, #-4]!
	pop {r9}
	NEXT

r_from:
	push {r9}
	ldr r9, [r11], #4
	NEXT

plus:
	pop {r0}
	add r9, r0
	NEXT

minus:
	pop {r0}
	sub r9, r0, r9    // r9 = r0 - r9
	NEXT

star:
	pop {r0}
	mov r1, r9        // use r1 because multiply can't be a src and a dest on ARM
	mul r9, r0, r1
	NEXT

equals:            // ( x1 x2 -- f )
	pop {r0}
	cmp r9, r0
	eor r9, r9     // 0 for false
	mvneq r9, r9   // invert for true
	NEXT

less:
	pop {r0}
	cmp r0, r9      // r9 < r0
	eor r9, r9
	mvnlt r9, r9
	NEXT

more:
	pop {r0}
	cmp r0, r9      // r9 > r0
	eor r9, r9
	mvngt r9, r9
	NEXT

and:
	pop {r0}
	and r9, r9, r0
	NEXT

or:
	pop {r0}
	orr r9, r9, r0
	NEXT

xor:
	pop {r0}
	eor r9, r9, r0
	NEXT

not:
	mvn r9, r9
	NEXT

negate:
	neg r9, r9
	NEXT

store:
	pop {r0}
	str r0, [r9]
	pop {r9}
	NEXT

fetch:
	ldr r9, [r9]
	NEXT

c_store:
	pop {r0}
	strb r0, [r9]
	pop {r9}
	NEXT

c_fetch:
	mov r0, r0
	ldrb r9, [r9]
	NEXT

branch:
	ldr r10, [r10]
	NEXT

zero_branch:                  // 0branch ( x -- )
	cmp r9, #0
	ldreq r10, [r10]          // Set the IP to the next codeword if 0,
	addne r10, #4             // or increment IP otherwise
	pop {r9}                  // DO pop the stack (regardless if it was 0)
	NEXT

execute:
	mov r8, r9                // r8 = the xt
	pop {r9}                  // pop the stack
	ldr r0, [r8]              // r0 = code address
	bx r0

accept:                       // ( c-addr u -- u2 )
	pop {r1}
	eor r2, r2
accept_key:
	cmp r2, r9
	beq accept_done
	bl fn_key
	// TODO: handle lots of keys
	add r2, #1
accept_done:
	mov r2, r9
	NEXT

key:                          // key ( -- c )
	push {r9}
	bl fn_key
	mov r9, r0
	NEXT

emit:                         // emit ( c -- )
	ldr r3, =params_num_tob   // Write a char to the output buffer, increment
	ldr r3, [r3]              // >out, and reset >out if it goes out of range
	ldr r0, =const_tob        // for the output buffer.
	ldr r0, [r0]
	ldr r1, =params_to_tob
	cpy r2, r1
	ldr r1, [r1]
	cmp r1, r3
	movge r1, #0
	strb r9, [r0, r1]
	add r1, #1
	str r1, [r2]
	pop {r9}
	NEXT

find:                       // ( addr u -- xt )
	ldr r0, =params_latest  // r0 = address of current word link field address
	pop {r1}                // r1 = address of string to find
	sub r6, r9, #1          // r6 = 0-based index of r9 (which is u)
link_loop:                  // Search through the dictionary linked list.
	ldr r0, [r0]            // r0 = r0->link
	cmp r0, #0              // test for end of dictionary
	beq no_find
	ldrb r2, [r0, #4]       // get word length+flags byte
	and r2, #F_LENMASK
	cmp r2, r9              // compare the lengths
	bne link_loop           // loop back since lengths are not equal

	add r2, r0, #5          // r2 = start address of word name string buffer
	eor r3, r3              // r3 = 0 index
char_loop:                  // Loop through both strings to test for equality.
	ldrb r4, [r1, r3]       // compare input string char to word char
	ldrb r5, [r2, r3]
	cmp r4, r5
	bne link_loop           // go to the next word if the chars don't match
	cmp r3, r6              // keep looping until the whole strings have been compared
	add r3, #1              // increment index (starts at index 1)
	bne char_loop

	mov r9, r0              // return the link field address
	NEXT
no_find:
	eor r9, r9              // return 0 for not found (no xt is equal to 0)
	NEXT

word:                       // ( c -- addr u )
	// TODO
	NEXT

// / ( n m -- q ) division quotient
slash:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r2
	NEXT

// /mod ( n m -- r q ) division remainder and quotient
slash_mod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	push {r0}
	mov r9, r2
	NEXT

// mod ( n m -- r ) division remainder
mod:
	mov r1, r9
	pop {r0}
	bl fn_divmod
	mov r9, r0
	NEXT

// Function for integer division and modulo
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

fn_key:
	// TODO: usb craziness
	bx lr

