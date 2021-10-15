	.equ BCM_PERI_BASE, 0x3F000000
	.equ BCM_GPIO_BASE, 0x3F200000
	.equ GPFSEL3, 0x3F20000C
	.equ GPFSEL4, 0x3F200010
	.equ GPSET1, 0x3F200020
	.equ GPCLR1, 0x3F20002C

	/*
	.section .data
	.align 4
	.global FrameBufferInfo
FrameBufferInfo:
	.int 1024 // #0 Physical Width
	.int 768 // #4 Physical Height
	.int 1024 // #8 Virtual Width
	.int 768 // #12 Virtual Height
	.int 0 // #16 GPU - Pitch
	.int 16 // #20 Bit Depth
	.int 0 // #24 X
	.int 0 // #28 Y
	.int 0 // #32 GPU - Pointer
	.int 0 // #36 GPU - Size
	*/

	.section .init
	.align 2
	.global _start
_start:
	// Shut off extra cores
	//mrc p15, 0, r5, c0, c0, 5
	//and r5, r5, #3
	//cmp r5, #0
	//bne halt

	// Init stack
	mov sp, #0x8000
	b main

halt:
	wfe
	b halt

	.section .text
	.align 2
main:
	ldr r0, =GPFSEL4
	mov r1, #7
	lsl r1, #21
	mvn r1, r1
	and r1, r0, r1
	orr r1, #1
	lsl r1, #21
	str r1, [r0]

	ldr r0, =GPFSEL3
	mov r1, #7
	lsl r1, #15
	mvn r1, r1
	and r1, r0, r1
	orr r1, #1
	lsl r1, #15
	str r1, [r0]

loop:
	ldr r0, =GPSET1
	mov r1, #1
	lsl r1, #47-32
	str r1, [r0]

	ldr r0, =GPCLR1
	mov r1, #1
	lsl r1, #35-32
	str r1, [r0]

	bl wait

	ldr r0, =GPCLR1
	mov r1, #1
	lsl r1, #47-32
	str r1, [r0]

	ldr r0, =GPSET1
	mov r1, #1
	lsl r1, #35-32
	str r1, [r0]

	bl wait

	b loop

wait:
	push {lr}
	ldr r0, =#5000000
waitLoop$:
	sub r0, #1
	cmp r0, #0
	bne waitLoop$
	pop {pc}

/*
	// Initialize screen buffer
	mov r0, #1024
	mov r1, #768
	mov r2, #16
	bl frameBufferInit

	// Test if the screen init was successful
	teq r0, #0
	beq error$

	fbInfoAddr .req r4
	mov fbInfoAddr, r0

render$:

	fbAddr .req r3
	ldr fbAddr, [fbInfoAddr, #32]

	color .req r0
	y .req r1
	mov y, #768

drawRow$:

	x .req r2
	mov x, #1024

drawPixel$:

	strh color, [fbAddr]
	add fbAddr, #2
	sub x, #1
	teq x, #0
	bne drawPixel$
	
	sub y, #1
	add color, #1
	teq y, #0
	bne drawRow$

	b render$
	.unreq fbAddr
	.unreq fbInfoAddr
	.unreq x
	.unreq y

error$:

	mov r5, #5

	mov r0, #16
	mov r1, #1
	bl gpioSetFunction
	mov r0, #16
	mov r1, #0
	bl gpioSet

errorLoop$:

	b errorLoop$

mailboxGetBase:
	ldr r0, =0x2000B880
	mov pc, lr

// Write data to mailbox
// Inputs:
//     r0: data
//     r1: mailbox
// Outputs:
//     none
mailboxWrite:
	// Validate inputs
	tst r0, #0b1111
	movne pc, lr
	cmp r1, #15
	movhi pc, lr

	channel .req r1
	value .req r2
	mov value, r0
	push {lr}
	bl mailboxGetBase
	mailbox .req r0

wait1$:
	// Get current mailbox status
	status .req r3
	ldr status, [mailbox, #0x18]

	tst status, #0x80000000
	.unreq status
	bne wait1$

	add value, channel
	.unreq channel

	// store the result
	str value, [mailbox, #0x20]
	.unreq value
	.unreq mailbox
	pop {pc}

// Read data from mailbox
// Inputs:
//     r0: mailbox to read from
// Outputs:
//     r0: data
mailboxRead:
	// Validate mailbox input
	cmp r0, #15
	movhi pc, lr

	channel .req r1
	mov channel, r0
	push {lr}
	bl mailboxGetBase
	mailbox .req r0
	
rightMail$:
wait2$:
	// get current status
	status .req r2
	ldr status, [mailbox, #0x18]

	// Loop until the 30th bit of status is 0
	tst status, #0x40000000
	.unreq status
	bne wait2$

	// Read mailbox
	mail .req r2
	ldr mail, [mailbox, #0]

	// Check that the channel is the one we want
	inChan .req r3
	and inChan, mail, #0b1111
	teq inChan, channel
	.unreq inChan
	bne rightMail$
	.unreq mailbox
	.unreq channel

	// Return the result
	and r0, mail, #0xfffffff0
	.unreq mail
	pop {pc}

// Initialize the frame buffer used for the GPU
// Inputs:
//     r0: width
//     r1: height
//     r2: bit depth
frameBufferInit:
	width .req r0
	height .req r1
	bitDepth .req r2

	// Validate our inputs: width, height both <= 4096, and bitDepth <= 32
	cmp width, #4096
	cmpls height, #4096
	cmpls bitDepth, #32
	result .req r0
	movhi result, #0
	movhi pc, lr

	// Write the inputs into the frame buffer
	fbufInfoAddr .req r3
	push {lr}
	ldr fbufInfoAddr, =FrameBufferInfo
	str width, [fbufInfoAddr, #0]
	str height, [fbufInfoAddr, #4]
	str width, [fbufInfoAddr, #8]
	str height, [fbufInfoAddr, #12]
	str bitDepth, [fbufInfoAddr, #20]
	.unreq width
	.unreq height
	.unreq bitDepth

	// Send the address of the frame buffer + 0x40000000 to the mailbox
	mov r0, fbufInfoAddr
	add r0, #0x40000000
	mov r1, #1
	bl mailboxWrite

	// Receive the reply from the mailbox
	mov r0, #1
	bl mailboxRead

	// If the reply is not 0, the method has failed. We return 0 to indicate failure
	teq result, #0
	movne result, #0
	popne {pc}

	// Return a pointer to the frame buffer info.
	mov result, fbufInfoAddr
	pop {pc}
	.unreq result
	.unreq fbufInfoAddr

gpioGetAddress:
	ldr r0, =BCM_GPIO_BASE
	mov pc, lr

// ...
gpioSetFunction:
	cmp r0, #53
	cmpls r1, #7
	movhi pc, lr

	push {lr}
	mov r2, r0
	bl gpioGetAddress

funcLoop$:
	cmp r2, #9
	subhi r2, #10
	addhi r0, #4
	bhi funcLoop$

	add r2, r2, lsl #1
	lsl r1, r2
	str r1, [r0]
	pop {pc}

// Set a GPIO value
// Inputs:
//     r0: pin number
//     r1: value to set the pin to
gpioSet:
	pinNum .req r0
	pinVal .req r1

	// Validate input pin
	cmp pinNum, #53
	movhi pc, lr

	mov r2, pinNum
	.unreq pinNum
	pinNum .req r2
	bl gpioGetAddress
	gpioAddr .req r0

	pinBank .req r3
	lsr pinBank, pinNum, #5
	lsl pinBank, #2
	add gpioAddr, pinBank
	.unreq pinBank

	and pinNum, #31
	setBit .req r3
	mov setBit, #1
	lsl setBit, pinNum
	.unreq pinNum

	teq pinVal, #0
	.unreq pinVal
	streq setBit, [gpioAddr, #40]
	strne setBit, [gpioAddr, #28]
	.unreq setBit
	.unreq gpioAddr
	pop {pc}

*/

b halt
