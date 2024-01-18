;
; Oscillator.asm
;
; Created: 1/23/2023 12:26:28 PM
; Author : Amirhossein Azhdarnezhad

.INCLUDE "M32DEF.INC"
.ORG 0
.DEF COUNTER = R17
.DEF KEYPAD_FLAG = R19
.DEF TEMP_1 = R16
.DEF TEMP_2 = R18
.DEF TEMP_3 = R20
.DEF TEMP_4 = R21
.DEF FLAG_DELAY = R22
.DEF STATE = R23
.EQU NUM1 = SRAM_START
.EQU NUM2 = SRAM_START + 1
.EQU NUM3 = SRAM_START + 2
.EQU NUM4 = SRAM_START + 3

; Initialize stack
LDI TEMP_1, HIGH(RAMEND)
OUT SPH, TEMP_1
LDI TEMP_1, LOW(RAMEND)
OUT SPL, TEMP_1

; Initialize keypad
LDI TEMP_1, 0b01110000  ; data direction register column lines output
OUT DDRA, TEMP_1        ; set direction register
LDI TEMP_1, 0b00001111  ; Pull-Up-Resistors to lower four port pins
OUT PORTA, TEMP_1       ; to output port

LDI TEMP_1, 0b11111111
OUT DDRC, TEMP_1

LDI TEMP_1, 0b00000001
OUT DDRB, TEMP_1

LDI KEYPAD_FLAG, 0	; Keypad flag

; Main program
MAIN:
	RCALL PWM				; 10
	RCALL PROCESS_KEYPAD	; 16(ONLY IN SIGNALING)
	RCALL SHOW				; 130(worst)
	RCALL DELAY_SUBROUTINE

	RJMP MAIN;

PWM:
	CPI FLAG_DELAY, 1
	BRNE DONT_SIGNAL
	OUT PORTB, STATE
	LDI TEMP_1, 1
	EOR STATE, TEMP_1
	DONT_SIGNAL: RET

PROCESS_KEYPAD:
	// only check for *
	CPI FLAG_DELAY, 1
	BRNE PROCESS_KEYPAD_NORMALLY
	LDI TEMP_1, 0b00110001
	OUT PORTA, TEMP_1
	IN TEMP_1, PINA
	ANDI TEMP_1, 1
	BREQ RESET_FLAG_DELAY
	RET

	PROCESS_KEYPAD_NORMALLY:

	LDI TEMP_1, 0b00001111 ; PB4..PB6=Null, pull-Up-resistors to input lines
	OUT PORTA, TEMP_1    ; of port pins PB0..PB3
	IN TEMP_1, PINA     ; read key results
	ORI TEMP_1, 0b11110000 ; mask all upper bits with a one
	CPI TEMP_1, 0b11111111 ; all bits = One?
	BREQ NO_KEY         ; yes, no key is pressed 

	SBRC KEYPAD_FLAG, 0
	RET
	
	LDI KEYPAD_FLAG, 1	; A key is pressed

	LDI ZH, HIGH(2 * KeyTable) ; Z is pointer to key code table
	LDI ZL, LOW(2 * KeyTable)
	; read column 1
	LDI TEMP_1, 0b00111111 ; PB6 = 0
	OUT PORTA, TEMP_1
	IN TEMP_1, PINA ; read input line
	ORI TEMP_1, 0b11110000 ; mask upper bits
	CPI TEMP_1, 0b11111111 ; a key in this column pressed?
	; 0b11111011 = r16
	BRNE KEY_ROW_FOUND ; key found
	ADIW ZL, 4 ; column not found, point Z one row down

	; read column 2
	LDI TEMP_1, 0b01011111 ; PB5 = 0
	OUT PORTA, TEMP_1
	IN TEMP_1, PINA ; read again input line
	ORI TEMP_1, 0b11110000 ; mask upper bits
	CPI TEMP_1, 0b11111111 ; a key in this column?
	BRNE KEY_ROW_FOUND ; column found
	ADIW ZL, 4 ; column not found, another four keys down

	; read column 3
	LDI TEMP_1, 0b01101111 ; PB4 = 0
	OUT PORTA, TEMP_1
	IN TEMP_1, PINA ; read last line
	ORI TEMP_1, 0b11110000 ; mask upper bits
	CPI TEMP_1, 0b11111111 ; a key in this column?
	BREQ NO_KEY ; no key pressed at all

KEY_ROW_FOUND: ; column identified, now identify row
; 0b11111011 = r16
	LSR TEMP_1 ; shift a logic 0 in left, bit 0 to carry
	; 0b01111101 = r16
	BRCC KeyFound ; a zero rolled out, key is found
	ADIW ZL, 1 ; point to next key code of that column
	RJMP KEY_ROW_FOUND ; repeat shift

KeyFound: ; pressed key is found 
	LPM TEMP_1, Z; read key code to TEMP_1

	CPI TEMP_1, 0x0A
	BREQ CLEAR_LCD

	CPI TEMP_1, 0x0B
	BREQ SET_DELAY_FLAG

	LDI YL, NUM1
	ADD YL, COUNTER
	STD Y + 0, TEMP_1
	INC COUNTER

	RET

SET_DELAY_FLAG:
	LDI FLAG_DELAY, 1
	RET

RESET_FLAG_DELAY:
	LDI FLAG_DELAY, 0
	RET

CLEAR_LCD:
	LDI COUNTER, 0
	LDI TEMP_1, 0
	STS NUM1, TEMP_1
	STS NUM2, TEMP_1
	STS NUM3, TEMP_1
	STS NUM4, TEMP_1

	RET

	;RJMP KeyProc ; countinue key processing

NO_KEY:
	LDI KEYPAD_FLAG, 0
	RET

END_SHOW:
	LDI TEMP_1, 0b00010000
	OUT PORTC, TEMP_1
	RET

DELAY_SHOW:
	LDI TEMP_3, 5
	DELAY_SHOW_LOOP:
		DEC TEMP_3
		BRNE DELAY_SHOW_LOOP
		RET

SHOW:
	CPI COUNTER, 0
	BREQ END_SHOW
	MOV TEMP_1, COUNTER

	LOOP:
		LDI YL, NUM1
		ADD YL, TEMP_1
		DEC YL
		LDI TEMP_4, 0b0001000
		MOV TEMP_2, TEMP_1
		INNER_LOOP:
			LSL TEMP_4
			DEC TEMP_2
			BRNE INNER_LOOP
		LDD TEMP_3, Y + 0
		OR TEMP_3, TEMP_4
		OUT PORTC, TEMP_3

		RCALL DELAY_SHOW
		DEC TEMP_1
	BRNE LOOP
	RET

DELAY_SUBROUTINE:
	SBRS FLAG_DELAY, 0
		RET

	CPI COUNTER, 4
		BREQ DDELAY_4
	CPI COUNTER, 3
		BREQ DDELAY_2
	CPI COUNTER, 2
		BREQ DDELAY_3
	
	RCALL DELAY_1
	RET

	DDELAY_2: RCALL DELAY_2
	RET
	DDELAY_3: RCALL DELAY_3
	RET
	DDELAY_4: RCALL DELAY_4
	RET

DELAY_1:
	LDI TEMP_1, 10
	LDS TEMP_2, NUM1
	SUB TEMP_1, TEMP_2
	DELAY_1_LOOP:
		LDI TEMP_2, 10
		DELAY_1_INNER_LOOP:
			LDI TEMP_3, 100
			DELAY_1_INNER_INNER_LOOP:
				
				DEC TEMP_3
				BRNE DELAY_1_INNER_INNER_LOOP
			DEC TEMP_2
			BRNE DELAY_1_INNER_LOOP
		DEC TEMP_1
		BRNE DELAY_1_LOOP
	RET

DELAY_2:
	LDI TEMP_1, 10
	LDS TEMP_2, NUM2
	SUB TEMP_1, TEMP_2
	DELAY_2_LOOP:
		LDI TEMP_2, 100
		DELAY_2_INNER_LOOP:

			DEC TEMP_2
			BRNE DELAY_2_INNER_LOOP
		DEC TEMP_1
		BRNE DELAY_2_LOOP
	RET

DELAY_3:
	LDI TEMP_1, 10
	LDS TEMP_2, NUM3
	SUB TEMP_1, TEMP_2
	DELAY_3_LOOP:
		LDI TEMP_2, 10
		DELAY_3_INNER_LOOP:

			DEC TEMP_2
			BRNE DELAY_3_INNER_LOOP
		DEC TEMP_1
		BRNE DELAY_3_LOOP
	RET

DELAY_4:
	LDI TEMP_1, 10
	LDS TEMP_2, NUM4
	SUB TEMP_1, TEMP_2

	DELAY_4_LOOP:

		DEC TEMP_1
		BRNE DELAY_4_LOOP 
	RET
;
; Table for code conversion
;

KeyTable:
.DB 0x0A, 0x07, 0x04, 0x01 ; First column, keys *, 7, 4 und 1
.DB 0x00, 0x08, 0x05, 0x02 ; second column, keys 0, 8, 5 und 2
.DB 0x0B, 0x09, 0x06, 0x03 ; third column, keys #, 9, 6 und 3
