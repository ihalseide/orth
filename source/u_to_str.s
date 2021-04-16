u_to_str:                     // ( u1 -- addr u2 )
	ldr r3, =var_base         // r3 = number base
	ldr	r3, [r3]
	/* Only proceed if the number base is valid */
	cmp	r3, #1
	bgt	good_base
	mov r9, 0                 // ( 0 0 )
	push {r9}
	NEXT
good_base:
	/* Index into the pad */
	mov r4, #0                // r4 = index
	ldr r5, =var_h          
	ldr r5, [r5]              // r5 = pad
	cmp	r9, #0
	bne	u_not_zero
	/* Write a 0 to the pad if u is 0 */
	add r4, #1
	eor r0, r0
	str r0, [r5]
u_not_zero:
	/* Switch on the number base */
	tst r3, #1
	b base_other
	cmp r3, #2
	beq base2
	cmp r3, #4
	beq base4
	cmp r3, #8
	beq base8
	cmp r3, #16
	beq base16
	cmp r3, #32
	beq base32
	b base_other
base2:
	and r0, r9, #1
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #1
 	cmp r9, #0
	bne base2
	b reverse_it
base4:
	and r0, r9, #3
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #2
 	cmp r9, #0
	bne base4
	b reverse_it
base8:
	and r0, r9, #7
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #3
 	cmp r9, #0
	bne base8
	b reverse_it
base16:
	and r0, r9, #15
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #4
 	cmp r9, #0
	bne base16
	b reverse_it
base32:
	and r0, r9, #31
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #5
 	cmp r9, #0
	bne base32
	b reverse_it
base_other:
	// r0 = r9 % r3
	// r9 = r9 / r3
	strb r0, [r5, r4]
	add r4, #1
	cmp r9, #0
	bne base_other
reverse_it:
	/* Reverse the output string */
	mov r9, r4          // TOS = final index
	eor r1, r1          // r0 = index #1
	mov r2, r9          // r3 = index #2
	b reverse_check
reverse_body:
	/* Get the characters on the opposite sides of the array */
	ldrb r3, [r5, r1]
	ldrb r4, [r5, r2]
	/* Convert values to digits */
	cmp r3, #9
	addgt r3, #7
	cmp r4, #9
	addgt r4, #7
	add r3, #'0'
	add r4, #'0'
	/* Swap characters */
	str r3, [r5, r2]
	str r4, [r5, r1]
	/* Move indices towards each other */
	add r1, #1
	sub r2, #1
reverse_check:
	cmp r1, r2
	bls reverse_body
	/* return */
	push {r5}
	NEXT

