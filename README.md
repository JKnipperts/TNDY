# TNDY
Driver for Matze79's TNDY and Serdaco's TNDLPT sound devices. Still in development.

This is a small DOS TSR program that redirects access to the I/O ports 0C0h or 205h (Tandy and PS/2 ports for audio) to the possible I/O ports of Matze79's TNDY ISA card or the parallel port for Serdacos's TNDLPT adapter.
To make this possible, the processor is switched to V86 mode. Does not work if EMM386 or another memory manager is loaded.

This driver is still in development and you might run into some bugs testing it. Many games already work very well with it but some crash or cause a Genereal Protection Fault. The use of smartdrv also causes a GPF.

I would like to point out that the code I use to switch the computer into protected / V86 mode is not my own work. I am using the i386 protected mode library with only minor modifications for this. This library was written back in 1993 by Andrew Zabolotny. Kindly, he decided to release his source code to the public and all he reasonably asks for in return is his continued attribution for his work. See the source of TEMU Tandy emulator and VSB Visual Sound Blaster for more details: https://github.com/volkertb/temu-vsb 

And see the TNDLPT driver by Peter De Wachter for for a different approach using memory mangers port forwarding routines: https://github.com/pdewacht/tndlpt
       
  
