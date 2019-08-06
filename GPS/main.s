; ******************************************************************
;    Facultad de Ingenieria UBA 2017
;    Titulo: Tracker Project 66.09 Laboratorio de Microcomputadoras
;    Autores: Leando Palazzo
;             Victor pizarew
;             Facundo Monpelat
;    Placa de desarrollo: Arduino Uno + shield microsd + GPS Ublox NEO 6M + LCD Shield Hitachi 
; ******************************************************************
; Windows Command line avrdude flash:
; avrdude.exe -p m328p -c usbtiny -U flash:w:GPS.hex:i
#define __SFR_OFFSET 0
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)
TEMP3			= 25
DATA			= 20
COUNTER			= 19
LF		= 10		//Line Feed ASCII
CR		= 13		//Carry Return ASCII

.extern		DELAY10MS
.extern		DELAY100MS
.extern		DELAY1S
// main: Where main program starts
/******************************************************************/
// loop: Where the program loops forever
/******************************************************************/
// initializations: initialize LCD, SPI, SD, USART and HIGH/LOW SECTORS
// Input: none
// Output: none
// ******************************************************************
	//LCD initialization
	rcall	LCD_init
	rcall	DELAY10MS
	//SPI initialization
	rcall	SPI_init
	rcall	DELAY10MS
	//SD initialization
	rcall	SD_init
	rcall	DELAY10MS
	//USART initialization
	rcall	USART_init
	rcall	DELAY10MS
	//startSector initialization
	ldi		LOWSECTOR,0x00
	rcall   DELAY100MS
	rcall	LCD_Borrar
	ret

// ******************************************************************
// bufferSDErase: erase content of buffer_sd
// Input: none
// Output: none
// ******************************************************************
bufferSDErase:
	push	ZL
	push	ZH
	push	TEMP
	push	TEMP2

	ldi		ZH,hi8(buffer_sd)
	ldi		ZL,lo8(buffer_sd)
	ldi		TEMP,0
	ldi		TEMP2,0
eraseSDLoop:
	st		Z+,0x00
	inc		TEMP
	brne	eraseSDLoop
	inc		TEMP2
	cpi		TEMP2,2
	brne	eraseSDLoop

	pop		TEMP2
	pop		TEMP
	pop		ZL
	pop		ZH
	ret

// ******************************************************************
// bufferGPSErase: erase content of buffer_gps_ubx
// Input: none
// Output: none
// ******************************************************************
bufferGPSErase:
	push	ZL
	push	ZH
	push	TEMP

	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		TEMP,0
eraseGPSLoop:
	st		Z+,0x00
	inc		TEMP
	cpi		TEMP,126
	brne	eraseGPSLoop

	pop		TEMP
	pop		ZL
	pop		ZH
	ret



// ******************************************************************
// GPStoSDbuffer: pastes the content of buffer_gps_ubx to current pointer
// of Y in buffer_sd
// Input: Y - pointer to buffer_sd (last end of position)
// Output:Y - pointer to buffer_sd (new end of position)
// ******************************************************************
GPStoSDbuffer:
	push	ZL
	push	ZH
	push	TEMP
	push	DATA

	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		ZL,lo8(buffer_gps_ubx)
GPStoSDLoop:
	ld		TEMP,Z+			//load char from buffer_gps_ubx
	st		Y+,TEMP			//store in buffer_sd
	cpi		TEMP,10			//IF Line Feed, end of protocol
	brne	GPStoSDLoop
	ld		TEMP,Z			//load last char
	st		Y+,TEMP			//store last char
	pop		DATA
	pop		TEMP
	pop		ZH
	pop		ZL
	ret

// ******************************************************************
// LCD_printLine1: Prints relevant data to the LCD 1st line
// Input: buffer_gps_ubx,LOWSECTOR,HIGHSECTOR (all untouched)
// Output: none
// ******************************************************************
LCD_printLine1:
	push	ZL
	push	ZH
	push	TEMP
	push	COUNTER
//First column 16 chars
	rcall	LCD_Borrar
//print sector		4 char + space
	mov		TEMP,HIGHSECTOR
	swap	TEMP
	rcall	HexToAscii
	rcall	LCD_EnviarChar
	mov		TEMP,HIGHSECTOR
	rcall	HexToAscii
	rcall	LCD_EnviarChar
	mov		TEMP,LOWSECTOR
	swap	TEMP
	rcall	HexToAscii
	rcall	LCD_EnviarChar
	mov		TEMP,LOWSECTOR
	rcall	HexToAscii
	rcall	LCD_EnviarChar
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
//check if it is $PUBX
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ld		TEMP,Z+
	ld		TEMP,Z
	cpi		TEMP,'P'
	brne	printLine1End
//print fix			2 char + space
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		COUNTER,8					// after the 8 comma, Fix is placed
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
//print time		8 char
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		COUNTER,2					// after the 2 comma, Time is placed
	ldi		TEMP,':'
	rcall	LCD_EnviarChar
	ld		TEMP,Z+
	ldi		TEMP,':'
	rcall	LCD_EnviarChar
	ld		TEMP,Z+
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
printLine1End:
	pop		COUNTER
	pop		TEMP
	pop		ZH
	pop		ZL
	ret

// ******************************************************************
// LCD_printLine2: Prints relevant data to the LCD 1st line
// Input: buffer_gps_ubx,LOWSECTOR,HIGHSECTOR (all untouched)
// Output: none
// ******************************************************************
LCD_printLine2:
	push	ZL
	push	ZH
	push	TEMP
	push	COUNTER
//Second Column 16 chars
	ldi		TEMP,0xC0        // Move cursor to second line 0b11000000
	rcall	LCD_EnviarCmd

//print speed km/h
	ldi		TEMP,'S'
	rcall	LCD_EnviarChar
	ldi		TEMP,'O'
	rcall	LCD_EnviarChar
	ldi		TEMP,'G'
	rcall	LCD_EnviarChar
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		COUNTER,11					// after the 3 comma, Latitude is placed
	rcall	LCD_EnviarChar
	rcall	LCD_EnviarChar
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
//print heading
	ldi		TEMP,'C'
	rcall	LCD_EnviarChar
	ldi		TEMP,'O'
	rcall	LCD_EnviarChar
	ldi		TEMP,'G'
	rcall	LCD_EnviarChar
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		COUNTER,12  				// after the 3 comma, Latitude is placed
printLine2End:
	pop		COUNTER
	pop		TEMP
	pop		ZH
	pop		ZL
	ret

// ******************************************************************
// HexToAscii: Change the content of first nibble in TEMP from HEX to ASCII
// Input: TEMP(first nibble) - HEX nibble
// Output:TEMP - ASCII value
// ******************************************************************
HexToAscii:
	push	TEMP2

	andi	TEMP,0x0F
	cpi		TEMP,0x0A
	brge	AtoF
	ldi		TEMP2,0x30	// IF TEMP is 0 to 9
	add	TEMP,TEMP2		// 0x30H is 0 

	pop		TEMP2
	ret

AtoF:						// IF TEMP is A to F
	ldi		TEMP2,0x37
	add		TEMP,TEMP2		// 0x41H is A and 37h+10d = 41h


	pop		TEMP2
	ret