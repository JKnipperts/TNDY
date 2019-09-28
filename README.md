# TNDY
Driver for Matze79's TNDY and Serdaco's TNDLPT sound devices

This is a small DOS TSR program that redirects access to the I/O ports 0C0h or 205h (Tandy and PS/2 ports for audio) to the possible I/O ports of Matze79's TNDY ISA card or the parallel port for Serdacos's TNDLPT adapter.
To make this possible, the processor is switched to V86 mode. Does not work if EMM386 or another memory manager is loaded.

The code I use to switch the computer into protected mode is not my own. I am using the i386 protected mode library, written in 1993 by Andrew Zabolotny. He decided to release his source code into the public domain and all he reasonably asks for in return is his continued attribution for this work.

    When I have released the sources I had no good knowledge about open-source licenses and such things :)
    Consider them public domain, but I will be grateful if you keep my attribution somewhere. - Andrew Zabolotny, 24 October 2016
  
See also 
TEMU Tandy emulator: https://github.com/volkertb/temu-vsb and TNDLPT driver by Peter De Wachter: https://github.com/pdewacht/tndlpt
       
  
