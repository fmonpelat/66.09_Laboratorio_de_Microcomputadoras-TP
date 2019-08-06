#define _SFR_ASM_COMPAT 1
#define __SFR_OFFSET 0

#include <avr/io.h>  // Analogo a m328pdef.inc// DEFINICIONES GENERALES:
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)TEMP			= 16COUNTER			= 19RESPUESTA		= 24LOWSECTOR			= 22HIGHSECTOR			= 23ZL				= 30ZH				= 31YL				= 28YH				= 29//Defino los puertos para la SDSD_PORT = PORTB
SD_DDR = DDRB

.section .data 

.section .text
.extern		loop
.global		SPI_init
.global		SD_init
.global		SD_escribirBloque
.global		SD_leerBloque
.global		SD_debug
.global		SD_erase

.extern		SD_writeSingleBlock
.extern		SD_readSingleBlock
.extern		SD_initialization


//Strings para el LCDlcdinit:	.asciz	"LCD Inicializado"
sdinit:		.asciz	"SD Inicializado " 
sderror1:	.asciz	"SD no detectada "
sderror2:	.asciz	"FALLA init SD   " 


//******************************************************************
//SPI_init: Inicializa el puerto de la tarjeta SD y y la configuracion del SPI
//parametros de entrada: Ninguno
//parametros de salida: Ninguno
//******************************************************************
SPI_init:
	push	TEMP

	ldi		TEMP,0xFB
	out		SD_PORT,TEMP	// Chip Select (PB2) OFF, resto ON
	ldi		TEMP,0XEF
	out		SD_DDR,TEMP		//MISO (PB4) input, resto output
	ldi		TEMP,0x52		
	out		SPCR,TEMP		//Configuracion del SPI: Master mode, MSB primero, SCK phase low, SCK idle low
	ldi		TEMP,0x00
	out		SPSR,TEMP		//Status Register en 0

	pop		TEMP
	ret
//******************************************************************
//SD_init: Inicializa la tarjeta SD y termina el programa si hay algun error
//parametros de entrada: Ninguno
//parametros de salida: Ninguno
//******************************************************************
SD_init:
	clr		24					//compatibilidad con subrutina en C
	clr		25				
	rcall	SD_initialization	cpi		RESPUESTA,0	brne	SD_error1	ldi		ZH,hi8(sdinit)	ldi		ZL,lo8(sdinit)	rcall	LCD_ImprimirString	rjmp	initEnd	rcall   LCD_BorrarSD_error1:	cpi		RESPUESTA,1	brne	SD_error2	ldi		ZH,hi8(sderror1)	ldi		ZL,lo8(sderror1)	rcall	LCD_ImprimirString	rjmp	error_sd_loopSD_error2:	ldi		ZH,hi8(sderror2)	ldi		ZL,lo8(sderror2)	rcall	LCD_ImprimirString	rjmp    error_sd_looperror_sd_loop:    rjmp error_sd_loop	//rjmp	SD_error2initEnd:	ret

//******************************************************************
//SD_erase: Escribe en el bloque elegido el contenido de un espacio de memoria
//parametros de entrada: Y: Y=buffer, 22=LOWSECTOR, 23=HIGHSECTOR
//parametros de salida: 24=Respuesta. 0 si no hay error
//******************************************************************
SD_erase:
	push	COUNTER
	push	TEMP
	push	YL
	push	YH

	ldi		TEMP,0
	ldi		COUNTER,2		//to make 255 times the loop
eraseLoop:
	st		Y+,TEMP
	st		Y+,TEMP
	inc		COUNTER
	brne	eraseLoop

	rcall	SD_writeSingleBlock

	pop		YH
	pop		YL
	pop		TEMP
	pop		COUNTER
	ret

//******************************************************************
//SD_escribirBloque: Escribe en el bloque elegido el contenido de un espacio de memoria
//parametros de entrada: Y: Y=buffer, 22=LOWSECTOR, 23=HIGHSECTOR
//parametros de salida: 24=Respuesta. 0 si no hay error
//******************************************************************
SD_escribirBloque:	push	ZL	push	ZH	push	YL	push	YH	push	18	push	19	push	20	push	21	push	22	push	23	push	25	push	26	push	27	push	1	//r1 para C siempre tiene que estar en 0	ldi		TEMP,0x00	mov		1,TEMP	//startblock es unsigned long (4 bytes) pero no vamos a usar mas de 650000 sectores asi que se dejan en 0 los ultimos 2	ldi		25,0x00	ldi		24,0x00	//22 y 23 son bloque low y high	//char* es puntero a buffer (2 bytes)	mov		21,YH	mov		20,YL	//llamo a la funcion	rcall	SD_writeSingleBlock	//return en r24 = RESPUESTA	pop		1	pop		27	pop		26	pop		25	pop		23	pop		22	pop		21	pop		20	pop		19	pop		18	pop		YH	pop		YL	pop		ZH	pop		ZL	ret//******************************************************************
//SD_escribirBloque: Lee el bloque elegido y lo almacena en un buffer
//parametros de entrada: Y: Y=buffer, 22=LOWSECTOR, 23=HIGHSECTOR
//parametros de salida: 24=Respuesta. 0 si no hay error
//******************************************************************SD_leerBloque:	push	ZL	push	ZH	push	18	push	19	push	20	push	21	push	22	push	23	push	25	push	26	push	27	push	1	//r1 para C siempre tiene que estar en 0	ldi		TEMP,0x00	mov		1,TEMP	//startblock es unsigned long (4 bytes) pero no vamos a usar mas de 650000 sectores asi que se dejan en 0 los ultimos 2	ldi		25,0x00	ldi		24,0x00	//22 y 23 son bloque 1 y 2	//char* es puntero a buffer (2 bytes)	ldi		21,ZH	ldi		20,ZL	//llamo a la funcion	rcall	SD_readSingleBlock	//return en r24 = RESPUESTA	pop		1	pop		27	pop		26	pop		25	pop		23	pop		22	pop		21	pop		20	pop		19	pop		18	pop		ZH	pop		ZL	ret