
;-------------------------------------------------------------------------------
; System calls
;-------------------------------------------------------------------------------

	.word link
	.set link, xt_syscall0
	.byte 8
	.ascii "syscall0"
	.balign 4
xt_syscall0:
	.word syscall0
syscall0:
	mov r7, r9         ; get the syscall id from TOS
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall1
	.byte 8
	.ascii "syscall1"
	.balign 4
xt_syscall1:
	.word syscall1
syscall1:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall2
	.byte 8
	.ascii "syscall2"
	.balign 4
xt_syscall2:
	.word syscall2
syscall2:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	ldr r1, [r13], #4  ; get the 2nd arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall3
	.byte 8
	.ascii "syscall3"
	.balign 4
xt_syscall3:
	.word syscall3
syscall3:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	ldr r1, [r13], #4  ; get the 2nd arg from stack
	ldr r2, [r13], #4  ; get the 3rd arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall4
	.byte 8
	.ascii "syscall4"
	.balign 4
xt_syscall4:
	.word syscall4
syscall4:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	ldr r1, [r13], #4  ; get the 2nd arg from stack
	ldr r2, [r13], #4  ; get the 3rd arg from stack
	ldr r3, [r13], #4  ; get the 4th arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall5
	.byte 8
	.ascii "syscall5"
	.balign 4
xt_syscall5:
	.word syscall5
syscall5:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	ldr r1, [r13], #4  ; get the 2nd arg from stack
	ldr r2, [r13], #4  ; get the 3rd arg from stack
	ldr r3, [r13], #4  ; get the 4th arg from stack
	ldr r4, [r13], #4  ; get the 5th arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next

	.word link
	.set link, xt_syscall6
	.byte 8
	.ascii "syscall6"
	.balign 4
xt_syscall6:
	.word syscall6
syscall6:
	mov r7, r9         ; get the syscall id from TOS
	ldr r0, [r13], #4  ; get the 1st arg from stack
	ldr r1, [r13], #4  ; get the 2nd arg from stack
	ldr r2, [r13], #4  ; get the 3rd arg from stack
	ldr r3, [r13], #4  ; get the 4th arg from stack
	ldr r4, [r13], #4  ; get the 5th arg from stack
	ldr r5, [r13], #4  ; get the 6th arg from stack
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next
