.cpu "65816"                        ; Tell 64TASS that we are using a 65816

.include "includes/TinyVicky_Def.asm"
.include "includes/interrupt_def.asm"
.include "includes/f256jr_registers.asm"
.include "includes/f256k_registers.asm"
.include "includes/macros.s"

dst_pointer = $30
src_pointer = $32
text_memory_pointer = $38 ; 16bit
need_score_update = $3B ; could be a flag
animation_index = $3F

letter0_ascii = $40
letter0_pos = $41

lives = $47
score = $48


; PGZ header
* =  0
                ; Place the one-byte PGZ signature before the code section
                .text "Z"           
                .long MAIN_SEGMENT_START               
                
                ; Three-byte segment size. Make sure the size DOESN'T include this metadata.
                .long MAIN_SEGMENT_END - MAIN_SEGMENT_START 

                ; Note that when your executable is loaded, *only* the data segment after the metadata is loaded into memory. 
                ; The 'Z' signature above, and the metadata isn't loaded into memory.


; Code
.logical $4000
MAIN_SEGMENT_START

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ENTRYPOINT    
    CLC                ; Disable interrupts
    SEI

    LDA #$B3           ; EDIT_EN=true, EDIT_LUT=3, ACT_LUT=3
    STA MMU_MEM_CTRL
    LDA #$07
    STA MMU_MEM_BANK_7 ; map the last bank    
    LDA #$3            ; EDIT_EN=false, EDIT_LUT=0, ACT_LUT=3

    STA MMU_MEM_CTRL    

    ; Initialize graphics mode
    STZ MMU_IO_CTRL
    LDA #(Mstr_Ctrl_Text_Mode_En|Mstr_Ctrl_Text_Overlay|Mstr_Ctrl_Graph_Mode_En|Mstr_Ctrl_Bitmap_En)
    STA @w MASTER_CTRL_REG_L 
    LDA #(Mstr_Ctrl_Text_XDouble|Mstr_Ctrl_Text_YDouble)
    STA @w MASTER_CTRL_REG_H             

    ; Disable the cursor
    LDA VKY_TXT_CURSOR_CTRL_REG
    AND #$FE
    STA VKY_TXT_CURSOR_CTRL_REG
    
    ; Clear
    LDA #$00
    STA $D00D ; Background red channel
    LDA #$00
    STA $D00E ; Background green channel
    LDA #$00
    STA $D00F ; Background blue channel
    
    ; Turn off the border
    STZ VKY_BRDR_CTRL
    
    STZ TyVKY_BM0_CTRL_REG ; Make sure bitmap 0 is turned off
    STZ TyVKY_BM1_CTRL_REG ; Make sure bitmap 1 is turned off
    STZ TyVKY_BM2_CTRL_REG ; Make sure bitmap 2 is turned off
    
    ; Initialize matrix keyboard
    LDA   #$FF
    STA   VIA_DDRB
    LDA   #$00
    STA   VIA_DDRA
    STZ   VIA_PRB
    STZ   VIA_PRA
    
    ; Initialize IRQ
    JSR Init_IRQHandler ; This program is a bit unhygenic and takes over the machine.

disable_int_mode16
    JSR ClearScreenCharacterColorsNative
    JSR TitleScreenNative
enable_int_mode8

    STZ MMU_IO_CTRL
    JSR PollForSpaceBarPress
    
    ; Initialize RNG
    LDA #1
    STA $D6A6
    
    ; Initialize text memory pointer
    LDA #<VKY_TEXT_MEMORY
    STA text_memory_pointer
    LDA #>VKY_TEXT_MEMORY
    STA text_memory_pointer+1    
    
    STZ animation_index
    LDA #0
    STA score
    STZ score+1
    STZ need_score_update
    LDA #5
    STA lives    
    
    disable_int_mode16
    JSR ClearScreenCharactersNative
    JSR NewLetter
    enable_int_mode8

GameplayLoop

Lock
    ; Check for keypress
    STZ MMU_IO_CTRL  ; Need to be on I/O page 0
    
    JSR CheckKeys
    BNE DoneCheckInput
    
    disable_int_mode16
    JSR EraseLetter ; If they pressed the 'A' key, erase the 'A' letter.
    JSR PrintHUD
    enable_int_mode8

    JMP DoneCheckInput
        
DoneCheckInput

    ; SOF handler will update animation_index behind the scenes.
    LDA animation_index
    BNE Lock
    ; Unblocked. Reset for next frame
    LDA #$9
    STA animation_index

    disable_int_mode16
    JSR LetterFall
    JSR UpdateScore
    JSR UpdateLives
    JSR PrintHUD
    enable_int_mode8
   
    JMP GameplayLoop    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckKeys
    LDA letter0_ascii
    CLC
    SBC #65
    INA
    TAY
    LDA PBMasks,Y
    STA VIA_PRB
    LDA VIA_PRA
    CMP PAMasks,Y
    RTS

; There isn't much rhyme or reason behind these, so this throws a bunch of data at the problem.
PAMasks
    .byte (1 << 1 ^ $FF) ; A
    .byte (1 << 3 ^ $FF) ; B
    .byte (1 << 2 ^ $FF) ; C
    .byte (1 << 2 ^ $FF) ; D
    .byte (1 << 1 ^ $FF) ; E
    .byte (1 << 2 ^ $FF) ; F
    .byte (1 << 3 ^ $FF) ; G
    .byte (1 << 3 ^ $FF) ; H
    .byte (1 << 4 ^ $FF) ; I
    .byte (1 << 4 ^ $FF) ; J
    .byte (1 << 4 ^ $FF) ; K
    .byte (1 << 5 ^ $FF) ; L
    .byte (1 << 4 ^ $FF) ; M
    .byte (1 << 4 ^ $FF) ; N
    .byte (1 << 4 ^ $FF) ; O
    .byte (1 << 5 ^ $FF) ; P
    .byte (1 << 7 ^ $FF) ; Q
    .byte (1 << 2 ^ $FF) ; R
    .byte (1 << 1 ^ $FF) ; S
    .byte (1 << 2 ^ $FF) ; T
    .byte (1 << 3 ^ $FF) ; U
    .byte (1 << 3 ^ $FF) ; V
    .byte (1 << 1 ^ $FF) ; W
    .byte (1 << 2 ^ $FF) ; X
    .byte (1 << 3 ^ $FF) ; Y
    .byte (1 << 1 ^ $FF) ; Z

PBMasks
    .byte (1 << 2 ^ $FF) ; A
    .byte (1 << 4 ^ $FF) ; B
    .byte (1 << 4 ^ $FF) ; C
    .byte (1 << 2 ^ $FF) ; D
    .byte (1 << 6 ^ $FF) ; E
    .byte (1 << 5 ^ $FF) ; F
    .byte (1 << 2 ^ $FF) ; G
    .byte (1 << 5 ^ $FF) ; H
    .byte (1 << 1 ^ $FF) ; I
    .byte (1 << 2 ^ $FF) ; J
    .byte (1 << 5 ^ $FF) ; K
    .byte (1 << 2 ^ $FF) ; L
    .byte (1 << 4 ^ $FF) ; M
    .byte (1 << 7 ^ $FF) ; N
    .byte (1 << 6 ^ $FF) ; O
    .byte (1 << 1 ^ $FF) ; P
    .byte (1 << 6 ^ $FF) ; Q
    .byte (1 << 1 ^ $FF) ; R
    .byte (1 << 5 ^ $FF) ; S
    .byte (1 << 6 ^ $FF) ; T
    .byte (1 << 6 ^ $FF) ; U
    .byte (1 << 7 ^ $FF) ; V
    .byte (1 << 1 ^ $FF) ; W
    .byte (1 << 7 ^ $FF) ; X
    .byte (1 << 1 ^ $FF) ; Y
    .byte (1 << 4 ^ $FF) ; Z
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NewLetter
    LDA #$0 ; Set I/O page to 0
    STA MMU_IO_CTRL

    LDY #40
    JSR RandModY16Bit

    ; Move down a row so we don't overlap the HUD
    CLC
    TYA
    ADC #$28

    STA letter0_pos
    STZ letter0_pos+1

    LDY #26
    JSR RandModY16Bit
    TYA
    CLC
    ADC #65
    STA letter0_ascii
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EraseLetter
    LDA #$02 ; Set I/O page to 2
    STA MMU_IO_CTRL
    
    ; Print a space to cover up the falling character
    LDY letter0_pos ; 16bit type                   
    LDA #32                        
    STA (text_memory_pointer),Y
        
    STZ MMU_IO_CTRL 
    JSR NewLetter

    LDA #1
    STA need_score_update

    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LetterFall
    LDA #$02 ; Set I/O page to 2
    STA MMU_IO_CTRL
    
    ;;;;;;;;;;;;;;;;
    ; Print a space to cover up the falling character
    LDY letter0_pos                   
    LDA #32                        
    STA (text_memory_pointer),Y

    ; Increment the character pos, to move 1 row lower
    setal
    TYA
    CLC
    ADC #$28
    STA letter0_pos

    ; Check if it's fallen to the bottom
    setas
    CPY #$4AF
    BPL FallenToBottom
    
    ; Print the fallen character
    LDY letter0_pos                  ; Y reg contains position of character    
    LDA letter0_ascii                ; Load the character to print
    STA (text_memory_pointer),Y
    BRA DoneLetterFall
    ;;;;;;;;;;;

FallenToBottom
    LDA lives
    DEC A
    BEQ GameOverScreen
    STA lives
    JSR NewLetter

DoneLetterFall
    RTS
    
TX_GAMEOVER_MAIN .null "G A M E   O V E R"
TX_GAMEOVER_PROMPT .null "Press SPACE to try again"

GameOverScreen
    JSR ClearScreenCharactersNative

    LDX #TX_GAMEOVER_MAIN   ; Print string
    STX src_pointer
    LDY #$C1C4
    STY dst_pointer    
    JSR PrintAscii_ForEach

    LDA #60 ; Lock for a few seconds
    STA animation_index        
    enable_int_mode8
GameOverTextDelay
    LDA animation_index
    BNE GameOverTextDelay
    disable_int_mode16

    LDX #TX_GAMEOVER_PROMPT ; Print a prompt for space
    STX src_pointer
    LDY #$C260
    STY dst_pointer    
    JSR PrintAscii_ForEach

    ;JMP TestLock2
    
    enable_int_mode8
    STZ MMU_IO_CTRL
    JSR PollForSpaceBarPress    ; hw runs into trouble here.


GameOverUnlock ; new game
    STZ animation_index
    LDA #0
    STA score
    STZ score+1
    STZ need_score_update
    LDA #5
    STA lives    
    
    disable_int_mode16
    JSR ClearScreenCharactersNative
    JSR NewLetter
    RTS ; Returns back up to GameplayLoop


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UpdateLives
    LDA #' '
    STA TX_LIVES+0
    STA TX_LIVES+1
    STA TX_LIVES+2
    STA TX_LIVES+3   
    STA TX_LIVES+4    
    STA TX_LIVES+5

    ; Update the display.
    LDY #TX_LIVES
    STY dst_pointer
    setxs
    LDA lives
    BEQ UpdateLives_Done
    TAY

    
UpdateLives_ForEach
    DEY
    LDA #'*'
    STA (dst_pointer), Y
    CPY #0
    BEQ UpdateLives_Done
    BRA UpdateLives_ForEach

UpdateLives_Done
    setxl
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UpdateScore
    LDA need_score_update
    BEQ outline_DoneScoreUpdate
    LDY score
    INY ; Increment score
    STY score
    STZ need_score_update

    ; Update the display too.    
    LDA #$0 ; Set I/O page to 0- needed for fixed function math
    STA MMU_IO_CTRL        

    LDY score
    LDX #5

EachDigitToAscii
    STY $DE06   ; Fixed function numerator
    LDY #10
    STY $DE04   ; Fixed function denomenator    
    LDA $DE16   ; Load the remainder
    CLC
    ADC #'0'    ; Turn into ASCII and save to stack
    PHA
    LDY $DE14   ; Load the quotient
    DEX
    BNE EachDigitToAscii          
          
    PLA
    STA TX_SCORE
    PLA
    STA TX_SCORE+1    
    PLA
    STA TX_SCORE+2
    PLA
    STA TX_SCORE+3
    PLA
    STA TX_SCORE+4

outline_DoneScoreUpdate
    RTS    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TX_HUD .text "LIVES:"
TX_LIVES .text "      SCORE:"
TX_SCORE .text "00000"

PrintHUD    
    LDA #$2 ; Set I/O page to 2
    STA MMU_IO_CTRL
    
    LDX #0
    LDY #16
PrintHUD_Loop
    LDA TX_HUD, X
    STA (text_memory_pointer),Y
    INY
    INX
    CPX #23
    BNE PrintHUD_Loop

    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearScreenCharactersNative ; The console size here is 40 wide x 30 high.
    LDA #$02 ; Set I/O page to 2
    STA MMU_IO_CTRL

    LDY #$C000
    STY dst_pointer    
ClearScreenNative_ForEach
    LDA #32 ; Character 0
    STA (dst_pointer)
    INY
    STY dst_pointer  
    CPY #$C4B0
    BNE ClearScreenNative_ForEach

    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TitleScreenNative
    LDA #$02 ; Set I/O page to 2
    STA MMU_IO_CTRL    
    LDY #$C000
    STY dst_pointer
    LDX #TX_TITLESCREEN
    STX src_pointer
    JSR PrintAscii
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TX_TITLESCREEN
.text "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
.text "XF                                    YX"
.text "X 88888888888                          X"
.text "X     888                              X"
.text "X     888     888                      X"
.text "X     888 888  888 88888b.   .d88b.    X"
.text 'X     888 888  888 888 "88b d8P  Y8b   X'
.text "X     888 888  888 888  888 88888888   X"
.text "X     888 Y88b 888 888 d88P Y8b.       X"
.text 'X     888  "Y88888 88888P"   "Y8888    X'
.text "X              888 888                 X"
.text "X    .d8888b.  888 888                 X"
.text "X   d88P  Y88b 888 888    o            X"
.text "X   Y88b.      888       ,8b           X"
.text 'X    "Y888b.   888888   ,888b   888d88 X'
.text 'X       "Y88b. 888   "Y8888888F"888P"  X'
.text 'X         "888 888     "F8"YF"  888    X'
.text "X   Y88b  d88P Y88b.   d8F T8b  888    X"
.text 'X    "Y8888P"   "Y888 d"     "b 888    X'
.text "X                                      X"
.text "X                                      X"
.text "X                                      X"
.text "X                                      X"
.text "X         Press SPACE to start!        X"
.text "X                                      X"
.text "X                                      X"
.text "X                                      X"
.text "X                                      X"
.text "Xb                                    dX"
.text "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Init_IRQHandler
    ; Back up I/O state
    LDA MMU_IO_CTRL
    PHA        

    ; Disable IRQ handling
    SEI

    ; Load our interrupt handler. Should probably back up the old one oh well
    LDA #<IRQ_Handler
    STA $FFFE ; VECTOR_IRQ
    LDA #>IRQ_Handler
    STA $FFFF ; (VECTOR_IRQ)+1

    ; Mask off all but start-of-frame
    LDA #$FF
    STA INT_MASK_REG1
    AND #~(JR0_INT00_SOF)
    STA INT_MASK_REG0

    ; Re-enable interrupt handling    
    CLI
    PLA ; Restore I/O state
    STA MMU_IO_CTRL 
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IRQ_Handler
    PHP
    PHA
    PHX
    PHY
    
    ; Save the I/O page
    LDA MMU_IO_CTRL
    PHA

    ; Switch to I/O page 0
    STZ MMU_IO_CTRL

    ; Check for start-of-frame flag
    LDA #JR0_INT00_SOF
    BIT INT_PENDING_REG0
    BEQ IRQ_Handler_Done
    
    ; Clear the flag for start-of-frame
    STA INT_PENDING_REG0        

    ; Advance frame
    LDA animation_index
    BEQ IRQ_Handler_Done
    DEC A
    STA animation_index

IRQ_Handler_Done
    ; Restore the I/O page
    PLA
    STA MMU_IO_CTRL
    
    PLY
    PLX
    PLA
    PLP
    RTI
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClearScreenCharacterColorsNative ; The console size here is 40 wide x 30 high.
    stz $0001 ;

    ; Set foreground #4 to green
    LDA #$04
    STA $D810 
    lda #$A5
    STA $D811
    LDA #$0D
    sta $D812

    STZ $D854 ; Set background #5 to black
    STZ $D855
    STZ $D856

    LDA #$03 ; Set I/O page to 3
    STA MMU_IO_CTRL

    LDY #$C000
    STY dst_pointer    
ClearScreenCharacterColorsNative_ForEach
    LDA #$45 ; Color 1
    STA (dst_pointer)
    INY
    STY dst_pointer  
    CPY #$C4B0
    BNE ClearScreenCharacterColorsNative_ForEach

    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RandModY16Bit
    ; Precondition: Y contains the value to mod by.
    ; Postcondition: Y contains the result. X is scrambled

    LDX $D6A4 ; Load 16bit random value

    STX $DE06   ; Fixed function numerator
    STY $DE04   ; Fixed function denomenator    
    LDY $DE16   ; Load the remainder

    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PollForSpaceBarPress
    LDA #(1 << 4 ^ $FF)
    STA VIA_PRB
    LDA VIA_PRA
    CMP #(1 << 7 ^ $FF)
    BNE PollForSpaceBarPress
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PrintAscii
    ; Precondition: src_pointer, dst_pointer are initialized
    ;               src_pointer is set to X
    ;               dst_pointer is set to Y
    ;               X and Y are in 16 bit mode
PrintAscii_ForEach
    LDA (src_pointer)
    BEQ PrintAscii_Done
    STA (dst_pointer)
    INY
    STY dst_pointer
    INX
    STX src_pointer
    BRA PrintAscii_ForEach
PrintAscii_Done
    RTS
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MAIN_SEGMENT_END
.endlogical

; Entrypoint segment metadata
                .long ENTRYPOINT
                .long 0       ; Dummy value to indicate this segment is for declaring the entrypoint.