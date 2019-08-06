#define _SFR_ASM_COMPAT 1
#define __SFR_OFFSET 0

#include <avr/io.h>  // Analogo a m328pdef.inc
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)
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


//Strings para el LCD
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
	rcall	SD_initialization

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
SD_escribirBloque:
//SD_escribirBloque: Lee el bloque elegido y lo almacena en un buffer
//parametros de entrada: Y: Y=buffer, 22=LOWSECTOR, 23=HIGHSECTOR
//parametros de salida: 24=Respuesta. 0 si no hay error
//******************************************************************