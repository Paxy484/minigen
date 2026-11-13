.section .text
.globl _start

/* ========================================================================= */
/* 1. 68000 Vector Table ($000000 - $0000FF)                                 */
/* ========================================================================= */
_start:
    .long   0x00FFFFFE          /* Initial Stack Pointer (Top of 64KB RAM)   */
    .long   EntryPoint          /* Initial Program Counter (Reset Vector)    */
    .rept   62                  /* Remaining 62 exception/interrupt vectors  */
    .long   IgnoreInt
    .endr

/* ========================================================================= */
/* 2. Sega Genesis ROM Header ($000100 - $0001FF)                            */
/* ========================================================================= */
    .ascii  "SEGA MEGA DRIVE "  /* $100: Console name (16 bytes)             */
    .ascii  "(C)PAXY 2026.NOV"  /* $110: Copyright & date (16 bytes)         */
    .ascii  "MINIGEN HELLO WORLD                             " /* $120: Domestic (48B) */
    .ascii  "MINIGEN HELLO WORLD                             " /* $150: Overseas (48B) */
    .ascii  "GM 00000000-00"    /* $180: Serial number (14 bytes)            */
    .word   0x0000              /* $18E: Checksum (ignored if TMSS satisfied)*/
    .ascii  "J               "  /* $190: I/O support (16 bytes)              */
    .long   0x00000000          /* $1A0: ROM start address                   */
    .long   RomEnd-1            /* $1A4: ROM end address                     */
    .long   0x00FF0000          /* $1A8: RAM start address                   */
    .long   0x00FFFFFF          /* $1AC: RAM end address                     */
    .ascii  "            "      /* $1B0: SRAM info (12 bytes)                */
    .ascii  "            "      /* $1BC: Modem info (12 bytes)               */
    .ascii  "                                        " /* $1C8: Notes (40B) */
    .ascii  "JUE             "  /* $1F0: Region codes (Japan/USA/Europe)     */

/* ========================================================================= */
/* 3. Entry Point & Hardware Init ($000200)                                  */
/* ========================================================================= */
EntryPoint:
    move.w  #0x2700, %sr        /* Disable all interrupts                    */

    /* --- Satisfy TMSS (Trademark Security System) on Model 1/2 Genesis --- */
    move.b  0x00A10001, %d0     /* Read hardware version                     */
    andi.b  #0x0F, %d0
    beq.s   SkipTMSS            /* Version 0 = early Japanese MD (no TMSS)   */
    move.l  #0x53454741, 0x00A14000 /* Write "SEGA" to unlock VDP!           */
SkipTMSS:

    /* --- Initialize VDP Registers --- */
    lea     0x00C00004, %a0     /* %a0 = VDP Control Port                    */
    lea     0x00C00000, %a1     /* %a1 = VDP Data Port                       */

    move.w  #0x8004, (%a0)      /* Reg 0: Enable H-blank / display mode      */
    move.w  #0x8144, (%a0)      /* Reg 1: Enable display + DMA               */
    move.w  #0x8230, (%a0)      /* Reg 2: Plane A nametable at VRAM $C000    */
    move.w  #0x8407, (%a0)      /* Reg 4: Plane B nametable at VRAM $E000    */
    move.w  #0x8700, (%a0)      /* Reg 7: Background color = Palette 0, Col 0*/
    move.w  #0x8F02, (%a0)      /* Reg 15: Auto-increment VRAM addr by +2    */
    move.w  #0x9001, (%a0)      /* Reg 16: Nametable size = 64x32 tiles      */

    /* --- Load CRAM Palette 0 (Color 0 = Black, Color 1 = White) --- */
    move.l  #0xC0000000, (%a0)  /* VDP command: Write to CRAM $0000          */
    move.w  #0x0000, (%a1)      /* Color 0: Black (0000 BBB0 GGG0 RRR0)      */
    move.w  #0x0EEE, (%a1)      /* Color 1: Pure White                       */

    /* --- Load 8x8 4bpp Font Tiles into VRAM $0000 --- */
    move.l  #0x40000000, (%a0)  /* VDP command: Write to VRAM $0000          */
    lea     FontTiles, %a2
    move.w  #(8*8)-1, %d0       /* 8 tiles x 8 rows (longwords)              */
LoadTiles:
    move.l  (%a2)+, (%a1)
    dbra    %d0, LoadTiles

    /* --- Clear Plane A Nametable ($C000, 64x32 = 2048 words) --- */
    move.l  #0x40000003, (%a0)  /* VDP command: Write to VRAM $C000          */
    move.w  #2048-1, %d0
ClearPlane:
    move.w  #0x0000, (%a1)      /* Tile 0 (Space)                            */
    dbra    %d0, ClearPlane

    /* --- Print "HELLO WORLD" on Row 13, Col 14 ($C000 + (13*64 + 14)*2 = $C69C) --- */
    move.l  #0x469C0003, (%a0)  /* VDP command: Write to VRAM $C69C          */
    lea     Message, %a2
PrintLoop:
    clr.w   %d0
    move.b  (%a2)+, %d0
    cmpi.b  #0xFF, %d0          /* Check for $FF end marker                  */
    beq.s   DonePrint
    move.w  %d0, (%a1)          /* Write tile index to Plane A               */
    bra.s   PrintLoop

DonePrint:
    /* --- Trigger a Classic Sega PSG Square-Wave Beep ($C00011) --- */
    lea     0x00C00011, %a0     /* %a0 = SN76489 PSG Sound Port              */
    move.b  #0x8E, (%a0)        /* Channel 0 Tone low 4 bits (A4 ~440Hz)     */
    move.b  #0x0F, (%a0)        /* Channel 0 Tone high 6 bits                */
    move.b  #0x92, (%a0)        /* Channel 0 Volume = loud (0x90=max, 0x9F=mute) */

    move.l  #0x00030000, %d0    /* Short delay loop (~0.25 seconds)          */
BeepDelay:
    subq.l  #1, %d0
    bne.s   BeepDelay

    move.b  #0x9F, (%a0)        /* Channel 0 Volume = Mute (0x9F)            */

    stop    #0x2700             /* Halt CPU cleanly                          */

IgnoreInt:
    rte

/* ========================================================================= */
/* 4. Data: Message & 8x8 4bpp Font (1 nibble = 1 pixel, Color 1 = White)    */
/* ========================================================================= */
Message:
    .byte   1, 2, 3, 3, 4, 0, 5, 4, 6, 3, 7, 0xFF
    .align  2

FontTiles:
    /* Tile 0: Space */
    .long 0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000
    /* Tile 1: 'H' */
    .long 0x01100110,0x01100110,0x01100110,0x01111110,0x01100110,0x01100110,0x01100110,0x00000000
    /* Tile 2: 'E' */
    .long 0x01111110,0x01100000,0x01100000,0x01111100,0x01100000,0x01100000,0x01111110,0x00000000
    /* Tile 3: 'L' */
    .long 0x01100000,0x01100000,0x01100000,0x01100000,0x01100000,0x01100000,0x01111110,0x00000000
    /* Tile 4: 'O' */
    .long 0x00111100,0x01100110,0x01100110,0x01100110,0x01100110,0x01100110,0x00111100,0x00000000
    /* Tile 5: 'W' */
    .long 0x01100011,0x01100011,0x01100011,0x01101011,0x01111111,0x01110111,0x01100011,0x00000000
    /* Tile 6: 'R' */
    .long 0x01111100,0x01100110,0x01100110,0x01111100,0x01101100,0x01100110,0x01100011,0x00000000
    /* Tile 7: 'D' */
    .long 0x01111000,0x01101100,0x01100110,0x01100110,0x01100110,0x01101100,0x01111000,0x00000000

    RomEnd: