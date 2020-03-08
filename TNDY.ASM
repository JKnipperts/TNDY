; TSR to redirect port access
; for use with TNDY and TLPT tandy 3-voice sound devices
; by Jan Knipperts
; v0.91 - 03/07/2020
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
		OPLOFF			db 0    ;Disable Adlib?
		FoundOption		db 0
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
		 mov dx,cs:OutPort

                 cmp LPT,1              ;Are we using an LPT port?
                 jne .mute_it

                 ;Unlock TNDLPT
  		 add dx,2		;ctrl port
                 xor ax,ax
                 mov al,00000100b        ;set bit 2, reset
                 out dx,al
                 mov ax,150
                 call Delay             ;Wait 150 ms
                 xor ax,ax
                 mov dx,cs:OutPort

.mute_it:
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


Handle_Options	proc near
		pusha
		push ax
                ;In: AX = offset of string to test; Out: FoundOption = 1 if found
                call string_length
                cmp ax,2
                jb  NoValidCmd
		pop ax

                clc

                mov si,ax
		mov di,offset PCJR
		call string_compare
		jc Enable_PCJR

                mov si,ax
		mov di,offset NOSB
		call string_compare
		jc Enable_NOSB

                mov si,ax
		mov di,offset NOOPL
		call string_compare
		jc Enable_NOOPL

		mov FoundOption,0
		popa
                retn

Enable_PCJR:
		mov EmuPCjr,1
		mov FoundOption,1
		popa
                retn
Enable_NOSB:
		mov SBOFF,1
		mov FoundOption,1
		popa
                retn
Enable_NOOPL:
		mov OPLOFF,1
		mov FoundOption,1
		popa
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
                je  NoValidCmd          ;There are no parameters

                mov cx,ax               ;Get Commandline
		mov di,offset CmdLine

	.GetCmdString:
		lodsb
		stosb
		loop .GetCmdString
                xor al,al
                stosb

Check_Options:
		mov ax,offset CmdLine
                call string_uppercase  ;make command line uppercase
                mov si,ax
                call string_parse      ;Parse different strings
		pusha
                push ax
                push bx
                push cx

                mov ax,dx               ;Test string in dx for known options
                call Handle_Options

                pop cx                  ;Test string in cx for known options
                mov ax,cx
                call Handle_Options

                pop bx                  ;Test string in bx for known options
                mov ax,bx
                call Handle_Options

                pop ax                  ;Test string in ax for known options
                call Handle_Options

		;Now handle enterend ports
		popa

		cmp bx,0		; There is only one parameter?
		je .OnlyOne 		; If so, there is nothing else to do here

                push bx

		clc
		mov si,ax
                mov di,offset SC0
                call string_compare
                jc .isC0

		mov si,ax
                mov di,offset SC0alt
                call string_compare
                jc .isC0

		mov si,ax
		mov di,offset SC0C7
                call string_compare
                jc .isC0C7

		mov si,ax
                mov di,offset S205
                call string_compare
                jc .is205

                jmp NoValidCmd


        .isC0:
		mov InPort,0C0h
                jmp .DoDestParam

        .isC0C7:
		mov InPort,0C7h
                jmp .DoDestParam

	.is205:
		mov InPort,205h
		jmp .DoDestParam

.OnlyOne:	
		cmp  FoundOption,1
		je   Continue
		jmp  NoValidCmd

.DoDestParam:
                pop bx

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
		jmp Continue


Continue:
		cmp    OutPort,0
		je     .NoRD
		cmp    InPort,0
		je     .NoRD
		jmp    .StartV86

.NoRD:
		cmp     FoundOption,0  ;No valid ports, no valid options -> quit here
		je	NoValidCmd


.StartV86:
		clc
                call 	CheckCPU
		call	Setup_IOmap
                call    SwitchToPM
                call    SwitchToVM86

                mov 	si,offset Greetings
                call    write_string


		cmp	EmuPCjr,0
		je	.SkipEmulation

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

.SkipEmulation:
		;No Emulation required but do we have to disable SB/ADLIB?
		cmp	SBOFF,0
		je	.SkipDisableSB  ;No SB disabling

		mov	si,offset SBMsg
		call	write_string
                mov     OPLOFF,1       ;Disable FM for SB too


.SkipDisableSB:
		cmp	OPLOFF,0	;Do we have to disable FM?
		je	.SkipDisableOPL  ;No OPL disabling

		mov	si,offset OPLMsg
		call	write_string

.SkipDisableOPL:
                call    Mute_Tandy
                mov 	si,offset V86SuccessMsg
                call    write_string

		cmp     OutPort,0
                je	.NoRDMsg
		cmp	InPort,0
		je	.NoRDMsg

		mov	si,offset RedirectMsg
		call    write_string

.NoRDMsg:
		mov dx, offset Setup_IOmap   ;Everything that should remain memory resident, stands before Setup_IOmap
		int 27h                      ;TSR

                include 386rdata.asm         ; Real-mode data
                include 386preal.asm         ; Real-mode subroutines
                include strings.inc          ; String handling routines

      		TitleMsg  	db 'I/O redirector for TNDY and TLPT three voice sound devices',10,13
				db 'Version 0.92 - 03/02/2020 '
				db 'by Jan Knipperts (Dragonsphere/DOSReloaded.de)',10,13
				db 'This program uses the i386 protected mode library by Andrew Zabolotny',10,13,0
				
		Greetings	db 10,13,'Greetings and thanks go to Matze, Serge Defever and Peter De Wachter',10,13,10,13,0


		Return		db 10,13,0

		V86SuccessMsg	db 'V86 mode successfully installed.',10,13,0

		RedirectMsg	db 'Port redirection installed.',10,13,0

                NoLPTMsg	db 10,13,'ERROR: Parallel port not found!',10,13,0

		ECPMsg		db 10,13,'Parallel port is in ECP mode, forcing SPP mode.',10,13,0

		EmuMSG		db 'Int 15h and Int 11h changed to report a PCjr.',10,13,0

		SBMSG		db 'Sound Blaster disabled.',10,13,0

		OPLMSG		db 'OPL FM-Chip disabled.',10,13,0

                BadOption       db 10,13,'Specify port addresses to redirect port access: ',10,13
				db 'TNDY.COM <Tandy port> <Port of the TNDY or TLPT> (Option 1) (Option 2)',10,13
                                db 10,13
				db 'Possible Tandy ports (in Hex): ',10,13
				db '0C0, C0-C7, 205',10,13
                                db 'Possible ports for TNDY or TLPT (in Hex): ',10,13
				db '2E0, 2C0, 1E0, 0E0, 0C0, LPT1, LPT2, LPT3',10,13,10,13
				db 'Possible Options (not mandatory):',10,13
				db 'NOSB  - Disables access to Sound Blaster DSP and FM chip',10,13
				db 'NOOPL - Disables Adlib/OPL FM-chip access',10,13
				db 'PCJR  - Changes Int 11h and Int 15h to report a PCjr',10,13
				db 10,13
				db 'Example: ',10,13
				db 'TNDY.COM 0C0 2C0 NOSB PCJR',10,13
				db 'All access to port 0C0h will be redirected to port 2C0h, Sound Blaster output ',10,13
				db 'will be disabled and the Interrupts 11h, and 15h will report a PCjr system.',10,13,0

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
		NOOPL		db 'NOOPL',0

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





