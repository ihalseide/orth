// FORTH word
// u>chars ( u1 -- addr u2 )
// where u1 is an unsigned number;
// where addr is the start address for the output string;
// where u2 is the length of the output string, and is 0 upon an error.
u_to_chars:
	ldr r0, =var_pad   // r0 = pad addr
	ldr r0, [r0]
	push {r0}          // push addr

	ldr r1, =var_base  // r1 = number base
	ldr r1, [r1]

	cmp r1, #2         // if base < 2, error condition
	movlt r9, #0          
	blt next

	cmp r9, #0         // u = 0 is a trivial case
	moveq r1, #'0'
	streq r1, [r0]
	moveq r9, #1
	beq next           // early return

	mov r2, #-1        // r2 = index i

    // Hard-coded routines for a base that is a power of 2
	cmp r1, #2
	beq base2
	cmp r1, #4
	beq base4
	cmp r1, #8
	beq base8
	cmp r1, #16
	beq base16
	cmp r1, #32
	beq base32

baseN:                        // Base that is not a power of 2
	cmp r9, #0                // loop until input number is divided and turned into 0
	beq finish

	// This (Inlined) Function for integer division modulo
	// Copied and modified from the project https://github.com/organix/pijFORTHos (which itself is a copy)
	// Arguments: r3 = numerator, r1 = denominator
	// Returns: r3 = remainder, r1 = denominator, r4 = quotient
	// Temporary: r6
	mov r6, r1
	cmp r6, r3, LSR #1
1:	movls r6, r6, LSL #1
	cmp r6, r3, LSR #1
	bls 1b
	mov r4, #0
2:	cmp r3, r6
	subcs r3, r3, r6
	adc r4, r4, r4
	mov r6, r6, LSR #1
	cmp r6, r1
	bhs 2b

_div_end:	mov r9, r4         // n = n / base (quotient)
	add r2, #1         // increment index into the number output buffer
	str r3, [r0, r2]   // put remainder into the buffer
	b baseN            // loop
	
base2:                   // this program structure is duplicated for bases which are powers of 2
	cmp r9, #0
	beq finish
	and r4, r9, #0b1     // get last bit(s)
	add r2, #1           // increment index into number buffer
	strb r4, [r0, r2]    // store into number buffer
	lsr r9, #1           // shift the number down
	b base2

base4:
	cmp r9, #0
	beq finish
	and r4, r9, #0b11
	add r2, #1
	strb r4, [r0, r2]
	lsr r9, #2
	b base4

base8:
	cmp r9, #0
	beq finish
	and r4, r9, #0b111
	add r2, #1
	strb r4, [r0, r2]
	lsr r9, #3
	b base8

base16:
	cmp r9, #0
	beq finish
	and r4, r9, #0b1111
	add r2, #1
	strb r4, [r0, r2]
	lsr r9, #4
	b base16

base32:
	cmp r9, #0
	beq finish
	and r4, r9, #0b11111
	add r2, #1
	strb r4, [r0, r2]
	lsr r9, #5
	b base32

finish:                    
	mov r9, r2             // push the string length to the stack
	cmp r2, #1             // only need to reverse the string if it's longer than 1 char
	ble next
	mov r1, #0             // r0 = index
revloop:                   // Reverse the number buffer for printing
	ldrb r3, [r0, r1]      // fetch at two indices
	ldrb r4, [r0, r2]

	cmp r3, #9             // convert digits to chars
	addgt r3, #7           // if digit >9 then make A = digit.10
	cmp r4, #9
	addgt r4, #7
	add r3, #'0'
	add r4, #'0'

	strb r3, [r0, r2]      // swap the chars into different indices
	strb r4, [r0, r1]

	sub r2, #1             // move indices towards the middle
	add r1, #1

	cmp r1, r2             // we're done when no more chars to swap
	bne revloop
	b next

