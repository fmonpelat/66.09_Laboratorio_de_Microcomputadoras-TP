; ******************************************************************
;    Facultad de Ingenieria UBA 2017
;    Titulo: Tracker Project 66.09 Laboratorio de Microcomputadoras
;    Autores: Leando Palazzo
;             Victor pizarew
;             Facundo Monpelat
;    Placa de desarrollo: Arduino Uno + shield microsd + GPS Ublox NEO 6M + LCD Shield Hitachi 
; ******************************************************************
; Windows Command line avrdude flash:
; avrdude.exe -p m328p -c usbtiny -U flash:w:GPS.hex:i#define _SFR_ASM_COMPAT 1
#define __SFR_OFFSET 0#include <avr/io.h>  // m328pdef.inc analog// GENERAL REGISTERS:
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)TEMP			= 16TEMP2			= 17
TEMP3			= 25
DATA			= 20
COUNTER			= 19ANS				= 24LOWSECTOR		= 22HIGHSECTOR		= 23
LF		= 10		//Line Feed ASCII
CR		= 13		//Carry Return ASCII
buffer_sd_length		= 512buffer_gps_ubx_length	= 126.section .databuffer_sd:				.space	buffer_sd_lengthbuffer_gps_ubx:			.space  buffer_gps_ubx_length // block size for UBX Navigation Paquet.section .text//Subroutines definitions.global		main.global		loop.global		buffer_sd.global		buffer_gps_ubx//LCD.extern		LCD_Borrar.extern		LCD_EnviarChar.extern		LCD_Init//DELAY.extern		DELAY1MS
.extern		DELAY10MS
.extern		DELAY100MS
.extern		DELAY1S//SD.extern		SPI_init.extern		SD_init.extern		SD_escribirBloque.extern		SD_leerBloque.extern		SD_debug.extern		SD_erase//USART.extern		USART_init.extern		GPS_getString.extern     GPS_getString_SD.extern     Serial_TX .extern     GPS_lookForFixsd_wrerror:				.asciz	"SD Write error"sd_outofmem:			.asciz	"SD out of memory"/******************************************************************//******************************************************************/
// main: Where main program starts
/******************************************************************/main:	rcall	DELAY100MS			//Voltage stabilization time	rcall	initializations	rcall	GPS_getString		// Get UBX String from GPS	rcall	GPS_getString		// Get UBX String from GPS	rcall	GPS_getString		// Get UBX String from GPS	rcall	GPS_getString		// Get UBX String from GPS	rcall	GPS_getString		// Get UBX String from GPS	rcall	GPS_getString		// Get UBX String from GPS/******************************************************************/
// loop: Where the program loops forever
/******************************************************************/loop://	rcall	bufferSDErase//	rcall	bufferGPSErase	ldi		COUNTER,4			//number of UBX strings stored in one sector	ldi		YH,hi8(buffer_sd)	ldi		YL,lo8(buffer_sd)SD_Loop_SaveData:	rcall	GPS_getString		// Get UBX String from GPS	rcall	LCD_printLine1		// Print relevant data to the 1st line of LCD	rcall	LCD_printLine2		// Print relevant data to the 2nd line of LCD	rcall	GPS_lookForFix		// Check for fix	cpi		ANS,0				// IF there is fix, then save the data	brne	SD_Loop_SaveData	// IF not, check again	rcall	GPStoSDbuffer		// copy buffer_gps_ubx to buffer_sd	dec		COUNTER				// IF there are 4 ubx strings then send buffer_sd to SD card	brne	SD_Loop_SaveData	// IF no, look for other string	ldi		YH,hi8(buffer_sd)	ldi		YL,lo8(buffer_sd)	rcall	SD_escribirBloque	//Send buffer_sd to SD card	cpi		ANS,0				//if ANS == 0 write succed	brne	SD_WRerror			// else, error, quit programm	inc		LOWSECTOR			// increment low sector	lds		TEMP,SREG	sbic	TEMP,0				//if carry flag set, increment high sector	inc		HIGHSECTOR				cpi		HIGHSECTOR,255		//Check for max memmory for SD (65535 sectors)	breq	SD_outOfMemmory		// if out of memmory, print in LCD and quit program	rjmp	loop				// if not, do it all againSD_WRerror:	rcall	LCD_Borrar	ldi		ZH,hi8(sd_wrerror)	ldi		ZL,lo8(sd_wrerror)	rcall	LCD_ImprimirString	rcall	DELAY1S	rjmp	SD_WRerrorSD_outOfMemmory:	rcall	LCD_Borrar	ldi		ZH,hi8(sd_outofmem)	ldi		ZL,lo8(sd_outofmem)	rcall	LCD_ImprimirString	rcall	DELAY1S	rjmp	SD_outOfMemmory/******************************************************************/// ******************************************************************
// initializations: initialize LCD, SPI, SD, USART and HIGH/LOW SECTORS
// Input: none
// Output: none
// ******************************************************************initializations:
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
	ldi		LOWSECTOR,0x00	ldi		HIGHSECTOR,0x00
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
	ldi		COUNTER,8					// after the 8 comma, Fix is placedfixLoop:	ld		TEMP,Z+	cpi		TEMP,','	brne	fixLoop	dec		COUNTER	brne	fixLoop	ld		TEMP,Z+	rcall	LCD_EnviarChar	ld		TEMP,Z	rcall	LCD_EnviarChar
	ldi		TEMP,' '
	rcall	LCD_EnviarChar
//print time		8 char
	ldi		ZL,lo8(buffer_gps_ubx)
	ldi		ZH,hi8(buffer_gps_ubx)
	ldi		COUNTER,2					// after the 2 comma, Time is placedtimeLoop:	ld		TEMP,Z+	cpi		TEMP,','	brne	timeLoop	dec		COUNTER	brne	timeLoop	ld		TEMP,Z+	rcall	LCD_EnviarChar	ld		TEMP,Z+	rcall	LCD_EnviarChar
	ldi		TEMP,':'
	rcall	LCD_EnviarChar
	ld		TEMP,Z+	rcall	LCD_EnviarChar	ld		TEMP,Z+	rcall	LCD_EnviarChar
	ldi		TEMP,':'
	rcall	LCD_EnviarChar
	ld		TEMP,Z+	rcall	LCD_EnviarChar	ld		TEMP,Z+	rcall	LCD_EnviarChar
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
	ldi		COUNTER,11					// after the 3 comma, Latitude is placedspeedLoop:	ld		TEMP,Z+	cpi		TEMP,','	brne	speedLoop	dec		COUNTER	brne	speedLoop	ld		TEMP,Z+speedLoop2:	rcall	LCD_EnviarChar	ld		TEMP,Z+	cpi		TEMP,'.'	brne	speedLoop2
	rcall	LCD_EnviarChar	// one digit for speed only	ld		TEMP,Z+
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
	ldi		COUNTER,12  				// after the 3 comma, Latitude is placedheadingLoop:	ld		TEMP,Z+	cpi		TEMP,','	brne	headingLoop	dec		COUNTER	brne	headingLoop	ld		TEMP,Z+headingLoop2:	rcall	LCD_EnviarChar	ld		TEMP,Z+	cpi		TEMP,'.'	brne	headingLoop2
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