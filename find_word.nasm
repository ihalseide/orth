
find:
	mov di, val_last
findl:
	push d1
	push bx
	mov cl, byte[bx]
	mov ch, 0
	inc cx
findc:
	mov al, byte[di + 2]
	and al, 07Fh
	cmp al, byte[bx]
	je findm
	pop bx
	pop di
	mov di, word[di]
	test di, di
	jne findl
findf:
	push bx
	xor bx, bx
	jmp next
findm:
	inc di
	inc bx
	loop findc
	pop bx
	pop di
	mov bx, 1
	inc di
	inc di
	mov al, byte[di]
	test al, 080h
	jne findi
	neg bx
findi:
	and ax, 31
	add di, ax
	inc di
	push di
	jmp next

