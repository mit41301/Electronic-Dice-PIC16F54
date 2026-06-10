
LIST P=16C54
;                       Dice.asm   version 1.4 June 17, 1995.
;
; An Electronic Dice demonstration using the Microchip 16C54 PIC
;
; Produced by:  DIY Electronics
;               PO Box 88458
;               Sham Shui PO       Email: peter@kitsrus.com
;               Hong Hong    Voice: 852-2725 0610.  Fax: 852-2725 0610
;
; This program may be freely copied, modified & distributed.


        include "p16c5x.inc"           ; pic fuse setting header
     __FUSES _CP_OFF & _WDT_ON & _RC_OSC

; -------------------------------------------------------------------------
; The Fuse settings in your Programmer should be set to:
;
;                       Watchdog timer     => ON
;                       Osc Start up timer => ON
;                       Code protect       => OFF
;                       Osc type           => RC
;        
; -------------------------------------------------------------------------
; Inputs and Outputs:
;       Port A
;               RA0 - Input  - push button to start Dice Roll
;               RA1 - Input  - unused
;               RA2 - Input  - unused
;               RA3 - Input  - unused
;        Port B
;               RB0 - Output - drives segment "b" of LED display
;               RB1 - Output - drives segment "a"
;               RB2 - Output - drives segment "f"
;               RB3 - Output - drives segment "g"
;               RB4 - Output - drives segment "dec. point"
;               RB5 - Output - drives segment "c"
;               RB6 - Output - drives segment "d"
;               RB7 - Output - drives segment "e"

; define data registers in RAM

                org     H'07'                   ; spare 16c54 RAM begins at 07h

Temp            res     1                       ; misc storage
Temp1           res     1                       ; misc storage
Displ_Pause     res     1                       ; counter for segment hold pause
Segment         res     1                       ; pointer to next segment
Coarse_Delay    res     1                       ; used by general delay routine
Fine_Delay      res     1                       ;   ,,   ,,    ,,    ,,   ,,
Seg_Count       res     1
Flash_Low       res     1                       ; used by Flash delay
Flash_High      res     1                       ;   ,,    ,,   ,,
Button          res     1                       ; store current button status
Sleep_Count     res     1                       ; used by sleep delay
Random_Num      res     1                       ; A number between 1 and six for dice roll

; define Reset Vector

                org     H'1FF'                  ; power-on-reset lands here
                goto    Start                   ; and jumps to start of program

                org     H'00'                   ; Start code at bottom of EPROM

; first we check if this is a wakeup call (eg. were we in sleep mode previously?)

Start           btfsc   STATUS,NOT_PD           ; check Power Down bit in status register (1=watchdog, 0=power reset)
                goto    Start00                 ; ok, it was a normal power up

                btfss   PORTA,0                 ; it was a wake-up call, so is the push button pressed?
                goto    Start03                 ; yes, check if it's stuck
                clrf    Button                  ; no, clear "button stuck" flag
                sleep                           ; and go back to sleep again.

Start03         btfsc   Button,0                ; is button stuck down?
                sleep                           ; yes, go back to sleep again.

; next we initialise everything:
                                                ; watch dog timer is set to wake PIC from sleep
                                                ; approx once every second
Start00         movlw   B'00001111'             ; watch dog runs via prescaler, set to divide by 256
                option                          ; write this to Option reg.
                clrwdt                          ; reset watchdog timer.


                movlw   B'11111111'             ; all PORTA lines are input (RA0 reads push button)
                tris    PORTA                   ; (they are tied high on the PCB to stop them floating)
                movlw   B'11111111'             ; Switch all Port A lines high
                movwf   PORTA

                movlw   B'00000000'             ; switch all of Port B to outputs (to drive the LEDs)
                tris    PORTB
                movlw   B'00000000'             ; Switch all Port_B lines low
                movwf   PORTB                   ; (so that all the LEDs are off)

                movlw   H'01'                   ; initialise various registers
                movwf   Flash_High
                movwf   Flash_Low
                movlw   D'50'
                movwf   Sleep_Count
                movlw   H'06'
                movwf   Random_Num

                bsf     Button,0                ; start with button flag set

Start01         clrwdt                          ; reset watchdog timer
                call    Random                  ; increment random number count
                call    Flash                   ; flash the decimal point
                btfss   PORTA,0                 ; is the button pressed?
                goto    Start02                 ; yes
                clrf    Button                  ;  no, clear flag
                goto    Start01                 ;  and loop back.

Start02         btfsc   Button,0                ; is button stuck down?
                goto    Start01                 ; yes, loop back
                bsf     Button,0                ; no, but now set flag

                call    Roll                    ; roll the dice
                movlw   D'50'                   ; reset sleep counter
                movwf   Sleep_Count
                movlw   H'0F'                   ; pause slightly
                call    Delay

; Display digits: As the LED has only one (common) dropping resistor,
; we "Multiplex" the pattern on to the display, one segment at a time.
; The eye smooths all this into seeing a complete digit.

Display         movf    Random_Num,W            ; get the current random number
                call    Look_Up_Digit           ; go get digit pattern
                movwf   Temp                    ; save it
                
Disp01          movlw   H'FF'                   ; set up for display hold time
                movwf   Displ_Pause
Disp02          movlw   H'07'                   ; set up for seven segments
                movwf   Segment

Disp03          clrwdt                          ; reset watchdog timer
                movf    Segment,W               ; get next segment pattern
                call    Look_Up_Seg
                andwf   Temp,W                  ; mask out this segment
                movwf   PORTB                   ;   and display it

                movlw   H'0F'                   ; set up for a delay
                movwf   Fine_Delay              ; so we can see the segment illuminated
Disp04          decfsz  Fine_Delay              ; is the delay finished?
                goto    Disp04

                decfsz  Segment,F               ; is this the last segment?
                goto    Disp03                  ;   no, do it again.

                decfsz  Displ_Pause,F           ; has timing loop finished?
                goto    Disp02                  ;   no, do it all again.

                clrf    PORTB                   ; yes, clear display
                movlw   H'FF'                   ; restart flash timer
                movwf   Flash_Low
                movlw   H'1F'
                movwf   Flash_High

                goto    Start01                 ; and do it all again.

;--------------------------------------------------------
; General purpose Delay routine: Feed multiples of 10mS in via "W" reg

Delay           movwf   Coarse_Delay
Delay01         movlw   H'FF'
                movwf   Fine_Delay
Delay02         clrwdt                          ; reset watchdog timer
                decfsz  Fine_Delay,F            ; this loop takes approx 10mSec
                goto    Delay02                 ; (300kHz/2/4/256)
                decfsz  Coarse_Delay,F
                goto    Delay01
                retlw   0

;-----------------------------------------------------------------------------
; Flash segments sequentially to simulate dice rolling.

Roll            movlw   H'02'                   ; set up for two rolls
                movwf   Temp1
                movlw   H'08'                   ; set up segement delay
                movwf   Temp

Roll00          movlw   H'06'                   ; set up for six segements
                movwf   Seg_Count

Roll01          movf    Seg_Count,W             ; get next segment count
                call    Look_Up_Seg             ; go get LED pattern
                movwf   PORTB                   ; write it to port B
                movf    Temp,W                  ; wait a while
                call    Delay
                decfsz  Seg_Count,F             ; is this the last segment?
                goto    Roll01
                decfsz  Temp1,F                 ; done two rolls yet?
                goto    Roll00
                clrf    PORTB                   ; switch off LEDs
                retlw   0

;--------------------------------------------------------------------------
; Decimal Point Flash routine. Used to show that PIC is "awake".
; If the button hasn't been pressed for fifty flashes, the processor goes
; to sleep to conserve power.

Flash           decfsz   Flash_Low,F            ; has low timer run out?
                retlw   0                       ;   no, return
                movlw   H'FF'                   ;   yes, reset timer
                movwf   Flash_Low
                decfsz  Flash_High              ; has high timer run out?
                retlw   0                       ;   no, return
                movlw   H'1F'                   ;   yes, reset timer
                movwf   Flash_High
                movlw   B'00010000'             ; set up bit pattern for dec point
                movwf   PORTB                   ; write it out
                movlw   H'05'
                call    Delay                   ; and pause a bit
                clrf    PORTB                   ; switch it off again

; is it sleepy time yet?

                decfsz  Sleep_Count             ; has count expired?
                retlw   0                       ; no.

                movlw   H'FF'                   ; yes, shut down all ports
                tris    PORTA                   ; (make them inputs
                tris    PORTB                   ;       to conserve power)
                sleep                           ; and goto sleep!
                
;----------------------------------------------------------------------------
; Random number generator: We constantly decrement by 1 a number to use as the
; number for the dice roll. This happens every time the subroutine is called.

Random          decfsz  Random_Num              ; has it got to zero?
                goto    Rand01                  ;    no, skip it
                movlw   H'06'                   ;    yes, reset it to 6
                movwf   Random_Num
                retlw   0                       ; return

Rand01          nop                             ; add some delays so that we spend equal time
                nop                             ;   in branch, to make roll truly random.
                retlw   0                       ; return

; ---------------------------------------------------------------------------
; Look-up tables for LED bit patterns: These use a "computed goto" technique.
; The value in "W" is added to the program counter to cause program execution
; to jump to the appropriate line. The "Return-with-Literal-in-W" instruction
; returns the required value.

Look_Up_Seg     addwf   PC           ; return bit pattern for sucessive segments
                nop                  ;     (we skip the "zero" value)


                retlw   B'00000010'             ;  a
                retlw   B'00000001'             ;  b
                retlw   B'00100000'             ;  c
                retlw   B'01000000'             ;  d
                retlw   B'10000000'             ;  e
                retlw   B'00000100'             ;  f
                retlw   B'00001000'             ;  g

; ------------------------------------------------------------------------

Look_Up_Digit   addwf   PC           ; return bit patterns for each digit (from 1 -> 6)
                nop                  ;    (we skip the "zero" digit)

                                        ;                 a
                retlw  B'00100001'      ; '1'          xxxxxxx
                retlw  B'11001011'      ; '2'      f  x       x b
                retlw  B'01101011'      ; '3'         x   g   x
                retlw  B'00101101'      ; '4'           xxxxxx
                retlw  B'01101110'      ; '5'      e  x       x c
                retlw  B'11101110'      ; '6'         x       x
                                        ;               xxxxxx
                                        ;                  d
                                        ;
                                        ; bits         76543210
                                        ; segments     edcXgfab    (X = dec point)

; ------------------------------------------------------------------------
 END
