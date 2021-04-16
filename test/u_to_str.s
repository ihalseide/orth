u_to_str:                     // ( u1 -- addr u2 )
	/* Get the pad address and make an index into it */
	mov r4, #0                // r4 = index
	ldr r5, =var_h          
	ldr r5, [r5]              // r5 = pad
	add r5, #30               // add some arbitrary padding
	/* Get the number base */
	ldr r6, =var_base         // r6 = number base
	ldr	r6, [r6]
	/* Only proceed if the number base is valid */
	cmp	r6, #1
	bgt	good_base
	mov r9, 0                 // ( 0 0 )
	push {r9}
	NEXT
good_base:
	cmp	r9, #0
	bne	u_not_zero
	/* Write a 0 to the pad if u is 0 */
	add r4, #1
	eor r0, r0
	str r0, [r5]
u_not_zero:
	/* Switch on the number base */
	tst r6, #1     // the base can't be a power of 2 if it's odd
	b base_other
	cmp r6, #2
	beq base2
	cmp r6, #4
	beq base4
	cmp r6, #8
	beq base8
	cmp r6, #16
	beq base16
	cmp r6, #32
	beq base32     // default case
	b base_other
base2_body:
	and r0, r9, #1
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #1
 	cmp r9, #0
base2:
	bne base2_body
	b base_done
base4_body:
	and r0, r9, #3
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #2
 	cmp r9, #0
base4:
	bne base4_body
	b base_done
base8_body:
	and r0, r9, #7
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #3
 	cmp r9, #0
base8:
	bne base8_body
	b base_done
base16_body:
	and r0, r9, #15
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #4
base16:
 	cmp r9, #0
	bne base16_body
	b base_done
base32_body:
	and r0, r9, #31
	strb r0, [r5, r4]
	add r4, #1
	lsr r9, r9, #5
base32:
 	cmp r9, #0
	bne base32_body
	b base_done
base_other_body:
	mov r0, r9         // numerator = u (TOS)
	mov r1, r6         // denominator = base
	bl fn_divmod
	mov r3, r0         // u % base -> rem
	mov r9, r2         // u / base -> u
	strb r0, [r5, r4]  // rem -> pad[i]
	add r4, #1
base_other:
	cmp r9, #0
	bne base_body
base_done:
	/* Reverse the pad array */
	mov r9, r4          // TOS = pad length
	eor r0, r0          // r0 = pad index #1
	mov r1, r1          // r1 = pad index #2
	b reverse
reverse_body:
	/* Get the characters on the opposite sides of the array */
	ldrb r2, [r5, r0]
	ldrb r3, [r5, r1]
	/* Convert values to digits */
	cmp r2, #9
	addgt r2, #7
	cmp r3, #9
	addgt r3, #7
	add r2, #'0'
	add r3, #'0'
	/* Swap characters */
	str r2, [r5, r1]
	str r3, [r5, r0]
	/* Move indices towards each other */
	add r0, #1
	sub r1, #1
reverse:
	cmp r1, r2
	bls reverse_body
	/* done, return */
	push {r5}       // second item on stack is the pad start address
	NEXT

