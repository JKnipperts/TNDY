PortHandler     proc    near
                cmp     ah,0EEh
                je      OutDX_AL
                cmp     ah,0E6h
                je      Out@@_AL
                cmp     ah,0ECh
                je      InAL_DX
                cmp     ah,0E4h
                je      InAL_@@
                jmp     TooBad

OutDX_AL:       push    dx

CheckPort:      cbw
                add     [ebp],ax
                mov     al,byte ptr [ebp-4]

                cmp     dx,205h
                je      @PS1

                cmp     dx,0C0h
                jae     @TandyPort


@Other:
		out     dx,al
                jmp     @@AllRight


@@AllRight:     pop     dx
                pop     ebp
                pop     ds
                pop     ebx
                pop     eax
                iretd

@TandyPort:

                cmp     dx,0C0h
                je      .CheckC0
                ja      .CheckC0C7
		
                jmp     @Other

                .CheckC0:
                cmp     [ss:InPort],205h
                je      @Other
                jmp     .doit

                .CheckC0C7:
                cmp     [ss:InPort],0C7h
                jne     @Other
                cmp     dx,0C7h
                ja      @Other
                jmp     .doit


.doit:
                cmp     [ss:LPT],1   ;Redirect to LPT port?
                je      .doLPT

                mov 	dx,[ss:OutPort]
		out     dx,al

		jmp	@@AllRight


.doLPT:
                pusha

                mov 	dx,[ss:OutPort]
		out 	dx,al

                inc     dx             ;Ctrl Port
		inc 	dx

		mov	al,12
		out	dx,al

                dec     dx             ;Status port

                mov     cx,18h

                Wait_not_ready:
                in      al,dx
		test	al,40h
		loopnz    Wait_not_ready

		inc     cx

		Wait_ready:
		in 	al,dx
		test	al,40h
		loopz	Wait_ready

		inc dx
		mov al,9
		out dx,al

		mov dx,03FFh
		mov al,cl
		out dx,al

                popa

		jmp	@@AllRight



@PS1:           cmp     [ss:InPort],205h
                je      .doit
                jmp     @Other


Out@@_AL:       push    dx
                movzx   dx,byte ptr [ebx]
                inc     al
                jmp     CheckPort


InAL_DX:        push    dx

ReadPort:       cbw
                add     [ebp],ax
		in      al,dx
                mov     byte ptr [ebp-4],al
                jmp     @@AllRight

InAL_@@:        push    dx
                inc     al
                movzx   dx,byte ptr [ebx]
                jmp     ReadPort

TooBad:

PortHandler     endp