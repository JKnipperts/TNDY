;�������������������������������������������������������������������������۲��
;����                 A i386(R) protected mode library                    ۲��
;����               (C)opyright 1993 by FRIENDS software                  ۲��
;����                           Real-mode data                            ۲��
;�������������������������������������������������������������������������۲��

CPUerror:       db      0Dh,0Ah,'ERROR: This program requires an i386 or higher!',0Dh,0Ah,'$'
AlreadyV86:     db      0Dh,0Ah,'ERROR: Processor is already running in protected mode!',0Dh,0Ah,'$'
A20error:       db      0Dh,0Ah,'ERROR: Cannot control A20 line!',0Dh,0Ah,'$'
