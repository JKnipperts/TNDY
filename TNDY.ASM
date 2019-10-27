; TSR to redirect port access
; for use with TNDY and TLPT tandy 3-voice sound devices
; by Jan Knipperts
; v0.9 - 10/17/2019
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
		EmuPCjr			db 0	;Emulate PCjr?
		SBOFF		        db 0    ;Disable Sound Blaster?
                int15_old_handler       dw 0    ;Handler for int 15
                int15_old_handler_seg   dw 0
  	        int11_equipment  	dw 0	;Equipment bits returned by int 11h




		;Include protected mode routines:

                include 386pdef.asm          ; Definitions first
                include 386pdata.asm         ; Then data segment
                include 386plib.asm          ; PM library
                include 386pint.asm          ; ISR's
                include 386pdt.asm           ; Descriptor tables


Int15_handler:
              cmp ah,0C0h         ;Return system configuraton?
              je .get_rom_table   ;Yes -> Send table
              jmp dword ptr cs:int15_old_handler    ;Else jump to old handler

  .get_rom_table:
              sti
              push cs
              pop es
              mov bx, offset _rom_table  ;ES:BX = pointer to descriptor table
              xor ah,ah
              iret
  _rom_table:
             dw 8      ;Length of descriptor table (8 minimum)
             db 0FDh   ;Model byte
             db 000h   ;Sub Model byte (Model FC 0B = IBM PS/1, FD 00 for PCjr)
             db 000h   ;BIOS revision
             db 070h   ;Feature Information
             db 000h   ;Reserved
	     db 000h
	     db 000h
	     db 000h


Int11_handler:
	    xor ax,ax
	    mov ax,cs:int11_equipment	;Return our equipment bits
	    iret




;============================== Non resident code ============================



Setup_IOmap  proc near             ;Sets bits in IO map for Tandy and PS/2 ports
		push cs
		pop es
                mov     IOportMap[0C0h/8],11111111b  ;Port 0C0-C07h
                mov     IOportMap[205h/8],00100000b  ;Port 205h
		mov	IOportMap[388h/8],00000011b  ;Port 388h / 389h
		mov	IOportMap[220h/8],11111111b  ;Port 220-227h
		mov	IOportMap[228h/8],11111111b  ;Port 228-22Fh
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



Mute_Tandy  proc near			;Inits chip and Mutes output of SN76496N
		 mov dx,cs:InPort

		 mov al,1		        ;Init sound chip	
		 out dx,al
		 mov ax,50
		 call Delay	
		 mov al,9
		 out dx,al
		 mov ax,50
                 call Delay
			
		 mov al,09Fh			 ;Mute output of all channels
		 out dx,al
		 mov ax,10 		
		 call Delay
		 mov al,0BFh
		 out dx,al
		 mov ax,10 		
		 call Delay
		 mov al,0DFh
		 out dx,al
		 mov ax,10 		
		 call Delay
		 mov al,0FFh
		 out dx,al
		 mov ax,100 		
		 call Delay
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
		push cx
		clc

;Check for possible second option
		mov si,dx
		mov di,offset PCJR
		call string_compare
		jc Enable_PCJR_2
		clc
                mov si,dx
		mov di,offset NOSB
		call string_compare
		jc Enable_NOSB_2

		jmp Check_Option

Enable_PCJR_2:
		mov EmuPCjr,1
		jmp Check_Option

Enable_NOSB_2:
		mov SBOFF,1
		jmp Check_Option


Check_Option:	
		pop cx
		clc
                mov si,cx
		mov di,offset PCJR
		call string_compare
		jc Enable_PCJR
		clc
                mov si,cx
		mov di,offset NOSB
		call string_compare
		jc Enable_NOSB

		pop ax
		pop bx
		jmp Handle_Port_Cmds

Enable_PCJR:
		mov EmuPCjr,1
		pop ax
		pop bx
		jmp Handle_Port_Cmds

Enable_NOSB:
		mov SBOFF,1
		pop ax
		pop bx


Handle_Port_Cmds:
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

		cmp	EmuPCjr,0
		je	SkipEmulation

		;Do some stuff to increase compatibility

		;Change Int 15h (get system configuration) to emulate a PCjr

                mov     ah,35h
                mov     al,15h
                int     21h
                mov     int15_old_handler_seg,es
                mov     int15_old_handler,bx

                mov     ah,25h
                mov     al,15h
                mov     dx, offset Int15_handler
                int     21h

		;Change Int 11h (BIOS equipment flags) to return no 2nd DMA controller
                xor     ax,ax
		int	11h                 ;Get equipment bits
                or      ax,100h             ;set Bit 8 (No DMA)
		mov	Int11_equipment,ax  ;save equipment bits

                mov     ah,25h
                mov     al,11h
                mov     dx, offset Int11_handler  ;Install new handler for int 11h
                int     21h

		mov    si,offset EmuMsg
		call   write_string

SkipEmulation:
		;No Emulation required but do we have to disable SB/ADLIB?
		cmp	SBOFF,0
		je	SkipDisableSB  ;No

		mov	si,offset SBMsg
		call	write_string


SkipDisableSB:
                call    Mute_Tandy
                mov si,offset SuccessMsg
                call    write_string

		mov dx, offset Setup_IOmap   ;Everything that should remain memory resident, stands before Setup_IOmap
		int 27h                      ;TSR

                include 386rdata.asm         ; Real-mode data
                include 386preal.asm         ; Real-mode subroutines
                include strings.inc          ; String handling routines

      		TitleMsg  	db 'I/O redirector for TNDY and TLPT three voice sound devices',10,13
				db 'Version 0.9 - 10/17/2019 '
				db 'by Jan Knipperts (Dragonsphere/DOSReloaded.de)',10,13
				db 'Uses i386 protected mode library by Andrew Zabolotny',10,13
				db 'Greetings and thanks to Matze79 and Peter De Wachter',10,13,0


		Return		db 10,13,0

		SuccessMsg	db 10,13,'V86 mode and port redirection successfully installed!',10,13,0

                NoLPTMsg	db 10,13,'ERROR: Parallel port not found!',10,13,0

		ECPMsg		db 10,13,'Parallel port is in ECP mode, forcing SPP mode.',10,13,0

		EmuMSG		db 10,13,'Int 15h and Int 11h changed',10,13,0

		SBMSG		db 10,13,'Adlib and Sound Blaster disabled',10,13,0

                BadOption       db 10,13,'Please specify port addresses as parameters: ',10,13
				db 'TNDY.COM <Tandy port> <Port of the TNDY or TLPT> <Option>',10,13
				db 10,13
				db 'Possible Tandy ports (in Hex): ',10,13
				db '0C0, C0-C7, 205',10,13,10,13
                                db 'Possible ports for TNDY or TLPT (in Hex): ',10,13
				db '2E0, 2C0, 1E0, 0E0, 0C0, LPT1, LPT2, LPT3',10,13,10,13
				db 'Possible Options (not mandatory):',10,13
				db 'NOSB - Disables Adlib/Sound Blaster',10,13
				db 'PCJR - Int 11h returns machine byte of a PCjr',10,13
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
		PCJR		db 'PCJR',0
		NOSB		db 'NOSB',0

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





