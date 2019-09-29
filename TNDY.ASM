; TSR to redirect port access
; for use with TNDY and TLPT tandy 3-voice sound devices
; by Jan Knipperts
; v0.83 - 29th of September 2019
;

.MODEL  TINY
.386P		;We need 386 instructions for the protected mode routines
.CODE
SMART
ORG     100h


;======================= Code to stay resident ===========================

                PortHandler     equ     <port.asm> ;Set port handler to its routine

Start:
		jmp	Init		;Skip data

		;Variables for Port values:

		InPort	    	        dw 0    ;Original port
		OutPort			dw 0    ;Port to redirect to
		LPT			db 0    ;use parallel port?

		;Include protected mode routines:

                include 386pdef.asm          ; Definitions first
                include 386pdata.asm         ; Then data segment
                include 386plib.asm          ; PM library
                include 386pint.asm          ; ISR's
                include 386pdt.asm           ; Descriptor tables


;============================== Non resident code ============================



Setup_IOmap  proc near             ;Sets bits in IO map for Tandy and PS/2 ports
		push cs
		pop es
                mov     IOportMap[0C0h/8],11111111b  ;Port 0C0-C07h
                mov     IOportMap[205h/8],00100000b  ;Port 205h
		retn
	       endp

Delay	     proc near		;Just a small delay (in: AX = delay in ms)
		pusha
		mov bx,1000
		mul bx
		mov cx,dx
		mov dx,ax
		xor al,al
		mov ah,86h
		int 15h
		popa
		retn
	      endp



Mute_Tandy  proc near			;Mutes output of SN76496N
		 mov dx,[InPort]
		 mov al,09Fh
		 out dx,al
		 mov al,0BFh
		 out dx,al
		 mov al,0DFh
		 out dx,al
		 mov al,0FFh
		 out dx,al
		 retn
	    endp



Init:
                mov ax,03
                int 10h

                mov si,offset TitleMsg
                call write_string

                xor ax,ax
                mov si,80h
                lodsb
                cmp al,0
                je  NoValidCmd
                mov cx,ax
		mov di,offset CmdLine

	.GetString:
		lodsb
		stosb
		loop .GetString
                xor al,al
                stosb

                mov ax,offset CmdLine
                call string_uppercase  ;make command line uppercase

                mov si,ax
                call string_parse

                cmp bx,0         ;Only one paramter?
                je NoValidCmd   ;Not what we have expected!

                push bx
                push ax

		clc
                mov si,ax
                mov di,offset SC0
                call string_compare
                jc .isC0


		clc
                mov si,ax
                mov di,offset SC0alt
                call string_compare
                jc .isC0


		clc
		pop ax
                push ax
		mov si,ax
		mov di,offset SC0C7
                call string_compare
                jc .isC0C7

		clc
		pop ax
                push ax
		mov si,ax
                mov di,offset S205
                call string_compare
                jc .is205

                pop ax
                jmp NoValidCmd


        .isC0:
		mov InPort,0C0h
                jmp DoDestParam

               .isC0C7:
		mov InPort,0C7h
                jmp DoDestParam

		.is205:
		mov InPort,205h

DoDestParam:
		pop ax
                pop bx
                push bx
                mov si,bx

		mov di,offset S2E0
                call string_compare
                jc .is2E0

                mov si,bx
                mov di,offset S2C0
                call string_compare
                jc .is2C0

                mov si,bx
                mov di,offset S1E0
                call string_compare
                jc .is1E0

		mov si,bx
                mov di,offset SE0
                call string_compare
                jc .is0E0

		mov si,bx
                mov di,offset SE0alt
                call string_compare
                jc .is0E0

		mov si,bx
                mov di,offset SC0
                call string_compare
                jc .is0C0

		mov si,bx
                mov di,offset SC0alt
                call string_compare
                jc .is0C0

                mov  si,bx
                mov di,offset SLPT1
                call string_compare
                jc .isLPT1

                mov si,bx
                mov di,offset SLPT2
                call string_compare
                jc .isLPT2

                mov si,bx
                mov di,offset SLPT3
                call string_compare
                jc .isLPT3

                pop bx
                jmp NoValidCmd

                .is2E0:
                mov OutPort,2E0h
		jmp Continue

                .is2C0:
                mov OutPort,2C0h
		jmp Continue

                .is1E0:
                mov OutPort,1E0h
		jmp Continue

                .is0E0:
                mov OutPort,0E0h
		jmp Continue

                .is0C0:
                mov OutPort,0C0h
                jmp Continue

        .isLPT1:
		mov ax,0040h
		mov es,ax
		mov ax,es:[08h]
                mov OutPort,ax
		jmp Init_LPT

        .isLPT2:
		mov ax,0040h
		mov es,ax
         	mov ax,es:[0Ah]
       		mov OutPort,ax
		jmp Init_LPT

        .isLPT3:
		mov ax,0040h
		mov es,ax
		mov ax,es:[0Ch]
                mov OutPort,ax



Init_LPT:
                cmp OutPort,0
                je LPT_failed
                mov LPT,1

		mov dx,[OutPort]
		add dx,2		;ctrl port

		;Test if port is in ECR mode
		xor al,al
		out dx,al

		in al,dx
		and al,3
		mov bl,al

		mov dx,[OutPort]
		add dx,402h		;ecp port

		in al,dx
		and al,3

		cmp al,1
		je Continue

		cmp bl,1
		jne Continue

		mov al,34h
		out dx,al
		in al,dx
		cmp al,35h
		jne Continue

                mov si,offset ECPMsg
                call write_string

		xor al,al
		out dx,al

		mov ax,100
		call delay


Continue:
                pop bx
		clc
                call 	CheckCPU
		call	Setup_IOmap
                call    SwitchToPM
                call    SwitchToVM86

                call    Mute_Tandy
                mov si,offset SuccessMsg
                call    write_string

		mov dx, offset Setup_IOmap   ;Everything that should remain memory resident, stands before Setup_IOmap
		int 27h                      ;TSR

                include 386rdata.asm         ; Real-mode data
                include 386preal.asm         ; Real-mode subroutines
                include strings.inc          ; String handling routines

      		TitleMsg  	db 'I/O redirector for TNDY and TLPT three voice sound devices',10,13
				db 'Version 0.83 - 09/29/2019 '
				db 'by Jan Knipperts (Dragonsphere/DOSReloaded.de)',10,13
				db 'Uses i386 protected mode library by Andrew Zabolotny',10,13,
				db 'Greetings and thanks to Matze79 and Peter De Wachter',10,13,0
			


		Return		db 10,13,0

		SuccessMsg	db 10,13,'V86 mode and port redirection successfully installed!',10,13,0

                NoLPTMsg	db 10,13,'ERROR: Parallel port not found!',10,13,0

		ECPMsg		db 10,13,'Parallel port is in ECP mode, forcing SPP mode.',10,13,0

                BadOption       db 10,13,'Please specify port addresses as parameters: ',10,13
				db 'TNDY.COM <Tandy port (source)> <Port of the TNDY or TLPT (destination)>',10,13
				db 10,13
				db 'Possible source ports (in Hex): ',10,13
				db '0C0, C0-C7, 205',10,13,10,13
                                db 'Possible destination ports (in Hex): ',10,13
				db '2E0, 2C0, 1E0, 0E0, 0C0, LPT1, LPT2, LPT3',10,13
				db 10,13
				db 'Example: ',10,13
				db 'TNDY.COM C0 2C0',10,13
				db 'All access to port 0C0h will be redirected to port 2C0h ',10,13,0

                SC0             db 'C0',0
		SC0alt		db '0C0',0
		SE0		db 'E0',0
		SE0alt		db '0E0',0
                SC0C7           db 'C0-C7',0
                S205            db '205',0
                S1E0            db '1E0',0
                S2C0            db '2C0',0
		S2E0		db '2E0',0
                SLPT1           db 'LPT1',0
                SLPT2           db 'LPT2',0
		SLPT3		db 'LPT3',0

		CmdLine		db 10 dup(0)

LPT_failed:
	        mov si,offset NoLPTMsg
                call write_string
                mov ah,4Ch
                int 21h

NoValidCmd:
                mov si,offset BadOption
                call write_string

                mov ah,4Ch
                int 21h


                end     Start





