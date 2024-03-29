;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;This program implements a microwave oven controller.  A time is set using
;the matrix keypad.  Time is counted down and displayed on two seven-segment
;LEDs.  Other LEDs indicate cooking status.
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

			Title "Microwave"
			#include <p18F4520.inc>	;Header file for PIC18F4520

			ZERO	EQU	0x00			;Zero register
			BCD0	EQU	0x01			;Time low BCD Digit
			BCD1	EQU	0x02			;Time high BCD Digit
			TEMP	EQU	0x10			;Temporary register for GETCODE
			KYSOPEN	EQU	0x11			;Code register for all keys open
			START	EQU	0x12			;Code register for Start
			STOP	EQU	0x13			;Code register for Stop
			DOOR	EQU	0x14			;Code register for Door
			SCALE	EQU	0xC0			;Scale for Timer0


			ORG	0x00				;Begin assembly
			GOTO	MAIN			;Program begins at 0020H

			ORG	0x08
			GOTO 	TMR0_ISR		;Timer0 Interrupt Vector

			ORG	0x20
MAIN: 			MOVLW	B'11100000'		;Init Timer0:interrupt enable
			MOVWF	INTCON
			MOVLW	B'01000100'		;Timer0:8-bit,internal clock,prescale-1:32
			MOVWF	T0CON
			MOVLW	SCALE			;Low count
			MOVWF	TMR0L			;Load low count in Timer0
			BCF 	INTCON,TMR0IF		;Clear TIMR0 overflow flag � Reset timer
			MOVLW	0xF0			;Enable RB7-RB4 as input and RB3-RB0 as output
			MOVWF	TRISB
			MOVLW	0x0F			;PORTA, PORTB Digital
			MOVWF	ADCON1
			CLRF	ZERO			;Code for zero
			MOVLW	0x80			;Code when all keys are open
			MOVWF	KYSOPEN
			MOVLW	0x0F			;Code for Start
			MOVWF	START
			MOVLW	0x0A				;Code for Stop
			MOVWF	STOP
			MOVLW	0x0B					;Code for Door Open
			MOVWF	DOOR
			MOVLW	0X00



			MOVWF	TRISA			;Init PORTs A,C,D as output ports
			MOVWF	TRISC
			MOVWF	TRISD
			MOVWF	PORTA
			MOVLW	0xC0			;Init LEDs OFF
			MOVWF	PORTC			;Init 7-Seg LEDs OFF
			MOVLW	0xC0
			MOVWF	PORTD
			CLRF	BCD0			;Init Time=0
			CLRF	BCD1



I_LOOP:			CALL	INPUT			;Call Input to get Time
			CALL	KEYCHK			;Check for Start
			CPFSEQ	START
			BRA	I_LOOP


C_START:		BSF	T0CON,TMR0ON		;Enable Timer0
C_LOOP:			CALL	COOK			;Cooking
			MOVF	BCD0, W			;Time = 0?
			IORWF	BCD1, W
			CPFSEQ	ZERO
			BRA	C_LOOP
			CALL	OUTLED
			BCF 	PORTA, 1		;Turn off magnetron
			BCF	T0CON,TMR0ON		;Disable timer
BUZZER:			BSF 	PORTA, 0		;Turn on buzzer
			CALL	KEYCHK			;Door?
			CPFSEQ	DOOR			;If door not opened, loop
			BRA	BUZZER
			BCF 	PORTA, 0		;Turn off buzzer
			BRA	I_LOOP			;Return to input loop
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		;Function:	INPUT gets User Input for Time.
		;			Calls KEYCHK and OUTLED.
		;Output:	Time in BCD1
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

INPUT:		CALL 	KEYCHK		;If KEYCHK returns B'10000000' no keys were pressed
		CPFSGT	STOP
		RETURN

		MOVWF	BCD1		;If so, move to BCD1
		MOVLW	0x00
		MOVWF	BCD0
		CALL	OUTLED		;Display

		RETURN
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		;Function:	COOK checks for Stop and Door and Lights Magnetron:
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::



COOK:		BSF	PORTA,1
		BSF	T0CON,TMR0ON
		CALL	KEYCHK		; CHECK BUTTON
		CPFSEQ	STOP		; CHECK FOR STOP
		CPFSEQ	DOOR		; IF NOT STOPPED, CHECK FOR DOOR
		GOTO   STOPB
DOORWAIT:	BCF	PORTA, 1	; IF DOOR OPEN, MAGNETRON OFF
		BCF	T0CON,TMR0ON	;	"	TIMER OFF
		CALL	KEYCHK
		CPFSEQ	KYSOPEN
		GOTO	DOORWAIT
		BSF	T0CON,TMR0ON
		BSF	PORTA, 1
		GOTO	COOK

STOPB:		CPFSEQ	STOP
		GOTO	RSM
		CLRF	BCD0
		CLRF	BCD1
		RETURN




RSM:		BSF	PORTA, 1	; MAGNETRON ON
		BSF	T0CON,TMR0ON	;
		RETURN			; RETURN TO C_LOOP

		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		;Timer0 Interrupt Service Routine:  Resets Timer0.
		;Decrements Time and calls OUTLED.
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

TMR0_ISR:		MOVLW	SCALE			;Low count
			MOVWF	TMR0L			;Load low count in Timer0
			BCF 	INTCON,TMR0IF		;Clear TIMR0 overflow flag � Reset timer

			MOVLW	0X00
			CPFSEQ	BCD0
			BRA	DLOOP
			DECF	BCD1,f
			MOVLW	0x09
			MOVWF	BCD0
			BRA	CLOOP
DLOOP:			DECF	BCD0,f
CLOOP:			CALL	OUTLED

			RETFIE	FAST			;Return from Interrupt

        ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      	;Function: KEYCHK checks first that all keys are open, then     :
	    ;checks a key closure using KEYCODE                             :
		;Output: Sets Bit7 if all keys are open                         :
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

KEYCHK:			MOVLW	0x0F		;Set RB0-RB3 Hi
			MOVWF	PORTB
			MOVF	PORTB,W		;Read PORTB
			CPFSEQ 	KYSOPEN		;Are all keys open?
			BRA	KEYCODE
			MOVLW	B'10000000'	;Return a 1 in Bit7 if all open
			RETURN

		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		;KEYCODE encodes the key and identify the key position:         :
		;Output: Encoded key position in W register                     :
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

KEYCODE:
COLRB0:		MOVLW	0x00		;Get ready to scan Column RB0
		ANDWF	PORTB, F	;All other keys should be 0s
SETRB0:		BSF	PORTB, 0	;Set Column - RB0
KEYB04:		BTFSS 	PORTB, 4	;Check RB4, if = 1, find code
			BRA		KEYB05 		;If RB4 = 0, check next key
			MOVLW	0x01		;Code for Key '1'
			RETURN
KEYB05:		BTFSS	PORTB, 5 	;Check RB5, if = 1, find code
			BRA		KEYB06		;If RB5 = 0, check next key
			MOVLW	0x04		;Code for key '4'
			RETURN
KEYB06:		BTFSS	PORTB, 6 	;Check RB6, if = 1, find code
			BRA		KEYB07		;If RB6 = 0, check next key
			MOVLW	0x07		;Code for key '7'
			RETURN
KEYB07:		BTFSS	PORTB, 7 	;Check RB7, if = 1, find code
			BRA		COLRB1		;If RB7 = 0, go to next column
			MOVLW	0x0A		;Code for key 'A'
			RETURN
COLRB1:		MOVLW	0x00		;Get ready to scan Column RB1
			ANDWF	PORTB, F	;All other keys should be 0s
SETRB1:		BSF		PORTB, 1	;Set Column - RB1
KEYB14:		BTFSS 	PORTB, 4	;Check RB4, if = 1, find code
			BRA		KEYB15 		;If RB4 = 0, check next key
			MOVLW	0x02		;Code for Key '2'
			RETURN
KEYB15:		BTFSS	PORTB, 5 	;Check RB5, if = 1, find code
			BRA		KEYB16		;If RB5 = 0, check next key
			MOVLW	0x05		;Code for key '5'
			RETURN
KEYB16:		BTFSS	PORTB, 6 	;Check RB6, if = 1, find code
			BRA		KEYB17		;If RB6 = 0, check next key
			MOVLW	0x08		;Code for key '8'
			RETURN
KEYB17:		BTFSS	PORTB, 7 	;Check RB7, if = 1, find code
			BRA		COLRB2		;If RB7 = 0, go to next column
			MOVLW	0x00		;Code for key '0'
			RETURN
COLRB2:		MOVLW	0x00		;Get ready to scan Column RB2
			ANDWF	PORTB, F	;All other keys should be 0s
SETRB2:		BSF		PORTB, 2	;Set Column - RB2
KEYB24:		BTFSS 	PORTB, 4	;Check RB4, if = 1, find code
			BRA		KEYB25 		;If RB4 = 0, check next key
			MOVLW	0x03		;Code for Key '3'
			RETURN
KEYB25:		BTFSS	PORTB, 5 	;Check RB5, if = 1, find code
			BRA		KEYB26		;If RB1 = 5, check next key
			MOVLW	0x06		;Code for key '6'
			RETURN
KEYB26:		BTFSS	PORTB, 6 	;Check RB6, if = 1, find code
			BRA		KEYB27		;If RB6 = 0, check next key
			MOVLW	0x09		;Code for key '9'
			RETURN
KEYB27:		BTFSS	PORTB, 7 	;Check RB7, if = 1, find code
			BRA		COLRB3		;If RB7 = 0, go to next column
			MOVLW	0x0B		;Code for key 'B'
			RETURN
COLRB3:		MOVLW	0x00		;Get ready to scan Column RB3
			ANDWF	PORTB, F	;All other keys should be 0s
SETRB3:		BSF		PORTB, 3	;Set Column - RB3
KEYB34:		BTFSS 	PORTB, 4	;Check RB4, if = 1, find code
			BRA		KEYB35 		;If RB4 = 0, check next key
			MOVLW	0x0C		;Code for Key 'C'
			RETURN
KEYB35:		BTFSS	PORTB, 5 	;Check RB5, if = 1, find code
			BRA		KEYB36		;If RB5 = 0, check next key
			MOVLW	0x0D		;Code for key 'D'
			RETURN
KEYB36:		BTFSS	PORTB, 6 	;Check RB6, if = 1, find code
			BRA		KEYB37		;If RB6 = 0, check next key
			MOVLW	0x0E		;Code for key 'E'
			RETURN
KEYB37:		BTFSS	PORTB, 7 	;Check RB7, if = 1, find code
		BRA	RTN			;If RB7 = 0, go to next column
		MOVLW	0x0F		;Code for key 'F'
		RETURN

RTN:		MOVLW	B'10000000'	;Return a 1 in Bit7 if all open
		RETURN

		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 		;Function:	OUTLED gets the two BCD digits from BCD1 and		:
		;		BCD0, gets seven-segment code by calling another 	:
		;		subroutine GETCODE and displays BCD digits at 		:
		;		PORTD and PORTC       					:
 		;Input: 	BCD digits in BCD1 and BCD0       			:
 		;Calls another subroutine GETCODE                			:
       	;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

OUTLED:			MOVF	BCD0,W			;Get low-order BCD digit in W
			CALL	GETCODE			;Find its seven-segment code
			MOVFF 	TABLAT,PORTC 	;Display it at PORTC
			MOVF	BCD1,W			;Get high-order BCD
			CALL	GETCODE			;Get its code
			MOVFF	TABLAT,PORTD	;Display at PORTD
			RETURN
		;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		;Function:	GETCODE.  This subroutine gets a BCD digit from WREG,  		:
		;		looks up its seven-segment code, and returns it in TABLAT  	:
 		;Input: 	BCD digit in W                   				:
 		;Output: 	Seven-segment LED code in TABLAT            			:
       	;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

GETCODE:	MOVWF	TEMP			;Save BCD digit in TEMP
			MOVLW	UPPER LEDCODE	;Copy upper bits of LEDCODE to Table Pointer
			MOVWF	TBLPTRU
			MOVLW	HIGH LEDCODE	;Copy high bits to Table Pointer
			MOVWF	TBLPTRH
			MOVLW	LOW LEDCODE		;Copy low bits to Table Pointer
			MOVWF	TBLPTRL
			MOVF	TEMP,W			;Get BCD digit from TEMP
			ADDWF	TBLPTRL,F 		;Add BCD digit to Table Pointer
			BNC		READ			;Check for Carry
			INCF	TBLPTRH,F
READ:		TBLRD*					;Read LED code from memory
		RETURN




LEDCODE:	DB		0xC0, 0xF9, 0xA4, 0xB0, 0x99	;Codes for digits 0 to 4
			DB		0x92, 0x82, 0xF8, 0x80, 0x90	;Codes for digits 5 to 9

			END