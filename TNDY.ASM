; TSR to redirect port access
; for use with TNDY and TLPT tandy 3-voice sound devices
; by Jan Knipperts
; v0.94 - 10/13/2020
; HAndle options schlieát ports 0C und 0E aus

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
		OutPort			dw 0    ;Port to redirect access to
		LPT			db 0    ;use parallel port?
		EmuPCjr			db 0	;Emulate PCjr?
		Emu			db 0	;Emulate?
		SBOFF		        db 0    ;Disable Sound Blaster?
		OPLOFF			db 0    ;Disable Adlib/OPL FM?
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

Tandy_Int15_handler:
              cmp ah,0C0h         ;Return system configuraton?
              je .Tandy_get_rom_table   ;Yes -> Send table
              jmp dword ptr cs:int15_old_handler    ;Else jump to old handler

  .Tandy_get_rom_table:
              sti
              push cs
              pop es
              mov bx, offset .Tandy_rom_table  ;ES:BX = pointer to descriptor table
              xor ah,ah
              iret

  .Tandy_rom_table:
             dw 8      ;Length of descriptor table (8 minimum)
             db 0FFh   ;Tandy 1000TL Model byte
             db 001h   ;Tandy 1000TL Sub Model byte
             db 000h   ;BIOS revision
             db 070h   ;Feature Information
             db 000h   ;Reserved
	     db 000h
	     db 000h
	     db 000h


PCjr_Int15_handler:
              cmp ah,0C0h         ;Return system configuraton?
              je .PCjr_get_rom_table   ;Yes -> Send table
              jmp dword ptr cs:int15_old_handler    ;Else jump to old handler

  .PCjr_get_rom_table:
              sti
              push cs
              pop es
              mov bx, offset .PCjr_rom_table  ;ES:BX = pointer to descriptor table
              xor ah,ah
              iret

  .PCjr_rom_table:
             dw 8      ;Length of descriptor table (8 minimum)
             db 0FDh   ;PCjr Model byte
             db 000h   ;Sub Model byte
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



Setup_IOmap  proc near             ;Sets bits in IO map for Tandy, PS/2 and sound card ports
		push cs
		pop es
                mov     IOportMap[042h/8],00000100b  ;Port 42h
                mov     IOportMap[0C0h/8],11111111b  ;Port 0C0-C07h
                mov     IOportMap[205h/8],00100000b  ;Port 205h
		mov	IOportMap[388h/8],00000011b  ;Port 388h / 389h
		mov	IOportMap[220h/8],01001111b  ;Port 220-223h,226h
		mov	IOportMap[228h/8],01010100b  ;Port 22Ah,22Ch,22Eh
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


Write_to_LPT  proc near
                 pusha
                 mov 	dx,[ss:OutPort]
		 out 	dx,al

                 inc     dx             ;Ctrl Port
		 inc 	dx

		 mov	al,0Ch
		 out	dx,al

                 dec     dx             ;Status port
                 mov     cx,18h

                Not_ready:

                 in      al,dx
		 test	al,01000000b
		 loopnz  Not_ready

		 cmp     cx,0
		 je      LPT_done

                 mov     cx,18h

		ready:

		in 	al,dx
		test	al,01000000b
		loopz	ready

		LPT_done:
                inc dx
		mov al,9
		out dx,al
                popa
                retn
endp



Mute_Tandy  proc near			;Inits chip and Mutes output of SN76496N
		 mov dx,cs:InPort

		 cmp LPT,1
		 jne .mute_tndy

                 ;Mute TNDLPT

                 mov al,09Fh
                 call Write_to_LPT
                 mov al,0BFh
                 call Write_to_LPT
                 mov al,0DFh
                 call Write_to_LPT
                 mov al,0FFh
                 call Write_to_LPT
                 jmp .End_mute




.mute_tndy:
		 mov al,1		        ;Init sound chip
		 out dx,al

		 mov ax,100
		 call Delay

		 mov al,9
		 out dx,al

		 mov ax,100
                 call Delay

		 mov al,09Fh			 ;Mute output of all channels
		 out dx,al

		 mov ax,100
		 call Delay

		 mov al,0BFh
		 out dx,al

		 mov ax,100
		 call Delay

		 mov al,0DFh
		 out dx,al

		 mov ax,100
		 call Delay

		 mov al,0FFh
		 out dx,al

		 mov ax,100
		 call Delay
.end_mute:
		 retn
endp



Handle_Options	proc near
                ;In: AX = offset of string to test; Out: FoundOption = 1 if found
		pusha

                clc

                mov si,ax
		mov di,offset PCJR
		call string_compare
		jc Enable_PCJR

                mov si,ax
		mov di,offset TANDY
		call string_compare
		jc Enable_Tandy

                mov si,ax
		mov di,offset NOSB
		call string_compare
		jc Enable_NOSB

                mov si,ax
		mov di,offset NOFM
		call string_compare
		jc Enable_NOOPL

		jmp Options_End

Enable_PCJR:
		mov EmuPCjr,1
		mov FoundOption,1
		mov Emu,1
		jmp Options_End

Enable_Tandy:
		mov Emu,1
		mov EmuPCjr,0
		mov FoundOption,1
		jmp Options_End

Enable_NOSB:
		mov SBOFF,1
		mov FoundOption,1
		jmp Options_End

Enable_NOOPL:
		mov OPLOFF,1
		mov FoundOption,1

Options_End:
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

        	push ax

                mov ax,dx               ;Test string in dx for known options
                call Handle_Options

                mov ax,cx               ;Test string in cx for known options
                call Handle_Options

                mov ax,bx               ;Test string in bx for known options
                call Handle_Options

                pop ax                  ;Test string in ax for known options
                call Handle_Options


		cmp bx,0		; There is only one parameter?
		je .OnlyOne 		; If so, there is nothing else to do here


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

                jmp .OnlyOne


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
		cmp  FoundOption,1      ;ist the paramter an option?
		je   Continue           ;Yes, the proceed
		jmp  NoValidCmd         ;Else command is not valid

.DoDestParam:

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

                jmp .OnlyOne

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

                add dx,400h             ;ECR port
                in  al,dx
                and al,3
                cmp al,1                ;Is ECR enabled?
                jne  .No_ECR

                xor al,al               ;if yes, disable it
                out dx,al

                .No_ECR:

                call Mute_Tandy

                ;Send initialization sequence for TNDLPT

	        sub dx,400h		;ctrl port again

   	        mov al,07
   		out dx,al

   		mov ax,200
   		call delay

   		mov al,09
   		out dx,al

   		mov ax,200
   		call delay




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

.Emulation:
		cmp	Emu,0
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

		cmp     EmuPCjr,1
		je	.Do_PCjr_int
                mov     dx, offset Tandy_Int15_handler
                int     21h
		jmp     .Disable_DMA2
.Do_PCjr_int:
                mov     dx, offset PCjr_Int15_handler
                int     21h

.Disable_DMA2:
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

		cmp    EmuPCjr,1
		jne    TStr

		mov    si, offset PCJR
		jmp    Write

		TStr:
		mov	si, offset Tandy_str

		Write:
		call   write_string
		mov    si, offset Return
		call   write_string
		jmp    .SkipEmulation





.SkipEmulation:
		;No Emulation required but do we have to disable SB or FM?
		cmp	SBOFF,0
		je	.SkipDisableSB  ;No SB disabling

		mov	si,offset SBMsg
		call	write_string


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
		mov dx, offset Setup_IOmap   ;Everything that should remain memory resident stands before Setup_IOmap
		int 27h                      ;TSR

                include 386rdata.asm         ; Real-mode data
                include 386preal.asm         ; Real-mode subroutines
                include strings.inc          ; String handling routines




;Data:





      		TitleMsg  	db 'I/O redirector for TNDY and TLPT three voice sound devices',10,13
				db 'by Jan Knipperts (Dragonsphere/DOSReloaded.de)',10,13
				db 'Alternative C0-C7 redirection test (v.0.94.2)',10,13,0

		Return		db 10,13,0

		V86SuccessMsg	db 'V86 mode successfully installed.',10,13,0

		RedirectMsg	db 'Port redirection installed.',10,13,0

                NoLPTMsg	db 10,13,'ERROR: Parallel port not found!',10,13,0

		EmuMSG		db 'Int 15h and Int 11h changed to report a',0

		SBMSG		db 'Sound Blaster disabled.',10,13,0

		OPLMSG		db 'FM-Chip disabled.',10,13,0


                BadOption       db 10,13,'Specify port addresses to redirect port access: ',10,13
				db 'TNDY.COM <Tandy port> <Port of the TNDY or TLPT> (Option 1) (Option 2)',10,13
                                db 10,13
				db 'Possible Tandy ports (in Hex): ',10,13
				db '0C0, C0-C7, 205',10,13
                                db 'Possible ports for TNDY or TLPT (in Hex): ',10,13
				db 'C0, E0, 1E0, 2C0, 2E0, LPT1, LPT2, LPT3',10,13,10,13
				db 'Possible Options (not mandatory):',10,13
				db 'NOSB  - Disables access to Sound Blaster DSP',10,13
				db 'NOFM  - Disables access to Adlib/FM-chip',10,13
				db 'PCJR  - Changes Int 15h, function 0Ch to report a PCjr',10,13
				db 'TANDY - Changes Int 15h, function 0Ch to report a Tandy 1000TL',10,13
				db 10,13
				db 'Example: ',10,13
				db 'TNDY.COM 0C0 2C0 NOSB PCJR',10,13
				db 'All access to port 0C0h will be redirected to port 2C0h, Sound Blaster output ',10,13
				db 'will be disabled and the Interrupts 11h, and 15h will report a PCjr system.',10,13,0

		Tandy_str	db 'Tandy 1000TL',0

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
		TANDY		db 'TANDY',0
		NOSB		db 'NOSB',0
		NOFM		db 'NOFM',0

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





