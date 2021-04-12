// FORTH word
// u>chars ( u -- addr n )
// where u is an unsigned number
// where addr is the pad address, for the beginning address of the character string
// where n is the length of the string of chars, n is 0 if error
u_dot:
	ldr r0, =var_pad   // r0 = pad addr
	ldr r0, [r0]
	push {r0}          // push addr

	ldr r1, =var_base  // r1 = number base
	ldr r1, [r1]

	cmp r1, #2         // if base < 2, error condition
	movlt r9, #0          
	blt next

	cmp r9, #0         // handle the trivial case of u = 0
	moveq r1, #'0'
	streq r1, [r0]
	moveq r9, #1
	beq next

	mov r2, #-1        // r2 = index i

    // Jump to extract digits with a base that is a power of 2
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
	cmp r9, #0
	beq finish

	// (Inlined) Function for integer division modulo
	// Copied from the project https://github.com/organix/pijFORTHos (which itself is a copy)
	// Arguments: r0 = numerator, r1 = denominator
	// Returns: r0 = remainder, r1 = denominator, r2 = quotient
	push {r0-r2}
	mov r0, r9

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

	mov r9, r2
	mov r3, r0
	pop {r0-r2}

	add r2, #1
	str r3, [r0, r2]

	b baseN
	
base2:
	cmp r9, #0
	beq finish
	and r4, r9, #0b1
	add r2, #1
	str r4, [r0, r2]
	lsr r9, #1
	b base2

base4:
	cmp r9, #0
	beq finish
	and r4, r9, #0b11
	add r2, #1
	str r4, [r0, r2]
	lsr r9, #2
	b base4

base8:
	cmp r9, #0
	beq finish
	and r4, r9, #0b111
	add r2, #1
	str r4, [r0, r2]
	lsr r9, #3
	b base8

base16:
	cmp r9, #0
	beq finish
	and r4, r9, #0b1111
	add r2, #1
	str r4, [r0, r2]
	lsr r9, #4
	b base16

base32:
	cmp r9, #0
	beq finish
	and r4, r9, #0b11111
	add r2, #1
	str r4, [r0, r2]
	lsr r9, #5
	b base32

finish:                    
	push {r2}              // push string length
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

