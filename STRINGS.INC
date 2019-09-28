;String handling routines
;v 1.0 - June 2000 by Jan Knipperts
;Note: Strings must be 0 terminated


string_length:

; Return length of a string
; IN: AX = string location
; OUT: AX = length (other regs preserved)

	push gs 			
	pusha

	mov bx, ax			

	xor cx, cx			

.l_more:
        xor al,al
	cmp byte [bx], al        	
	je .l_done
	inc bx				
	inc cx
	jmp .l_more

.l_done:
	mov gs, cx			
	popa

	mov ax, gs			
	pop gs
	ret

string_uppercase:
; Converts zero-terminated string to upper case
; IN: AX = string location
; OUT: AX = string location

	pusha
	mov si, ax			

.u_more:
        mov al,0
	cmp byte [si], al		; Zero-termination of string?
	je .done			; If so, quit

        mov al,'a'
	cmp byte [si], al		; In the lower case A to Z range?
	jb .noatoz
        mov al,'z'
	cmp byte [si], al
	ja .noatoz

        mov al,20h
	sub byte [si], al		; If so, convert input char to upper case

	inc si
	jmp .u_more

.noatoz:
	inc si
	jmp .u_more

.done:
	popa
	ret



string_parse:
; pointers to zero-terminated strings 
; IN: SI = string; OUT: AX, BX, CX, DX = individual strings

	push si

	mov ax, si			; AX = start of first string

	lodsb				; Get a byte
	cmp al,0			; End of string?
	je .finish
	cmp al, ' '			; A space?
	jne .clear_adr
	mov ax,si			; Update start of first string

.clear_adr:
	xor bx, bx			; By default, other strings start empty
	xor cx, cx			; Therefore we set BX, CX and DX to 0
	xor dx, dx

	push ax 			; Save to retrieve at end

.loop1:
	lodsb				; Get a byte
	cmp al,0			; End of string?
	je .finish
	cmp al, ' '			; A space?
	jne .loop1
	sub si,2
        mov al,0
	mov byte [si],al		; If so, zero-terminate this bit of the string

	add si,2  			; Store start of next string in BX
	mov bx, si

.loop2: 				; Repeat the above for CX and DX...
	lodsb
	cmp al,0
	je .finish
	cmp al, ' '
	jne .loop2
	sub si,2
        mov al,0
	mov byte [si], al

	add si,2
	mov cx, si

.loop3:
	lodsb
	cmp al,0
	je .finish
	cmp al,' '
	jne .loop3
	sub si,2
        mov al,0
	mov byte [si], al
	add si,2
	mov dx, si

.finish:
	pop ax

	pop si
	ret



write_string:

; write_string -- Writes 0 terminated string to the screen and returns
; IN: SI = string;

  push dx
  push cx
  push ax

  xor cx,cx
  Length_Loop:
      lodsb
      inc cx
      cmp al,0
      jne Length_Loop
  sub si,cx

 Write_Loop:
   lodsb
   mov dl,al
   mov ah,2
   int 21h
 loop Write_Loop

 pop dx
 pop cx
 pop ax

ret


string_compare:

; Compares two strings 
; IN: SI = string one, DI = string two
; OUT: carry set if same, clear if different

	pusha

.c_more:
	mov al, [si]			; Retrieve string contents
	mov bl, [di]

	cmp al, bl			; Compare characters at current location
	jne .not_same

	cmp al, 0			; End of first string? Must also be end of second
	je .terminated

	inc si
	inc di
	jmp .c_more

.not_same:				; If unequal lengths with same beginning, the byte
	popa				; comparison fails at shortest string terminator
	clc				; Clear carry flag
	ret

.terminated:				; Both strings terminated at the same position
	popa
	stc				; Set carry flag
	ret
