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

                cmp     dx,0C7h		;Tandy ports C0h-C7h
                jbe     @TandyPort

                cmp     dx,205h         ;PS/1 sound port 205h
                je      @PS1

	        cmp     dx,388h		;Adlib address port
		je	@Adlib

		cmp	dx,389h		;Adlib data port
		je      @Adlib

		cmp	dx,220h		;SB Pro left FM address port
		je      @Adlib

		cmp	dx,221h		;..and left data port
		je      @Adlib

		cmp	dx,222h		;SB Pro right FM address port
		je      @Adlib

		cmp	dx,223h		;..and right data port
		je      @Adlib

		cmp     dx,226h		;SB DSP control ports
		je      @SB

		cmp	dx,22Ah
		je      @SB

		cmp	dx,22Ch
		je      @SB

		cmp     dx,22Eh
		je      @SB





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
		cmp	[ss:InPort],0   ;No redirecting?
		je	@Other
		cmp	[ss:OutPort],0
		je	@Other

                cmp     dx,0C0h
                je      .CheckC0
                cmp     dx,0C0h
                ja      .CheckC0C7

                jmp     @Other

                .CheckC0:
                cmp     [ss:InPort],205h
                je      @Other
                jmp     .doit

                .CheckC0C7:
                cmp     [ss:InPort],0C7h
                jne     @Other

                cmp     [ss:LPT],1
                je      .doit

                sub     dx,0C0h   ;FÅ¸r Matze - !!!
                add     dx,[ss:OutPort]
                out     dx,al

                jmp	@@AllRight


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

		mov	al,0Ch
		out     dx,al

                dec     dx             ;Status port
                mov     cx,18h

                Wait_not_ready:

                in      al,dx
		test	al,01000000b
		loopnz    Wait_not_ready

		cmp     cx,0
		je      LPT_timed_out

                mov     cx,18h

		Wait_ready:
		in 	al,dx
		test	al,01000000b
		loopz	Wait_ready

		LPT_timed_out:
                inc     dx
		mov     al,9
		out     dx,al

                popa

		jmp	@@AllRight



@PS1:           cmp     [ss:InPort],205h
                je      .doit
                jmp     @Other

@Adlib:
		cmp  [ss:OPLOFF],1 ;OPL disabled?
		je  @@AllRight	   ;Then do nothing
		jmp .doit	   ;If not, write to port

@SB:
		cmp [ss:SBOFF],1
		je @@AllRight
		jmp .doit




Out@@_AL:       push    dx
                movzx   dx,byte ptr [ebx]
                inc     al
                jmp     CheckPort


InAL_DX:        push    dx

ReadPort:
		cmp     dx,0388h		;Adlib
		je		@ReadAdlib
		cmp		dx,0389h
		je      @ReadAdlib
		cmp     dx,226h			;SB cmd port
		je      @ReadSB
		cmp     dx,22Eh			;SB data port
		je      @ReadSB
		jmp 	.Readit

@ReadAdlib:
		cmp     [ss:OPLOFF],1
		jne     .Readit
		cbw
                add     [ebp],ax
		mov	al,0FFh		;return FF (bus float) if disabled
		mov     byte ptr [ebp-4],al
                jmp     @@AllRight

@ReadSB:
		cmp     [ss:SBOFF],1
		jne     .Readit
		cbw
                add     [ebp],ax
		mov	al,0FFh		;return FF (bus float) if disabled
		mov     byte ptr [ebp-4],al
                jmp     @@AllRight

.Readit:
		cbw
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
