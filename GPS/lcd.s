#define _SFR_ASM_COMPAT 1 
#define __SFR_OFFSET 0

#include <avr/io.h>  // Analogo a m328pdef.inc

// ******************************************************************
//   RUTINAS DEL LCD
// ******************************************************************
// DEFINICIONES GENERALES:
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)TEMP			= 16TEMP2			= 17
TEMP3			= 25COUNTER			= 19//Defino los puertos para el LCD
LCD_DATPORT	= PORTD
LCD_DATDDR	= DDRD
LCD_DATPIN	= PIND
LCD_CTRPORT	= PORTC
LCD_CTRDDR	= DDRC
LCD_CTRPIN	= PINC//Defino los bits del LCD
LCD_E	= 2
LCD_RW	= 1
LCD_RS	= 0
LCD_D4	= 4
LCD_D5	= 5
LCD_D6	= 6
LCD_D7	= 7
// Defino los comandos del LCD
LCD_INIT_CMD	= 0x20 // 0b00100000
LCD_FUNC_SET	= 0x2C // 0b00101100	Comando "FUNCION SET"
//[0 0 | 0 0 1 DL N F x x] 
LCD_CURS_SHIFT	= 0x14 // 0b00010100	Comando "CURSOR / DISPLAY SHIFT"
//[0 0 | 0 0 0 1 S/C R/L x x]
LCD_DISP_ON		= 0x0C // 0b00001100	Comando "DISPLAY ON/OF"
//[0 0 | 0 0 0 0 1 D C B] 
LCD_ENTRY_MODE	= 0x06 // 0b00000110	comando "ENTRY MODFE SET"
//[0 0 | 0 0 0 0 0 1 I/D S]
LCD_CLEAR_DISP	= 0x01 // 0b00000001	Comando "CLEAR DISPLAY"
//[0 0 | 0 0 0 0 0 0 0 1] 
LCD_CURS_HOME	= 0x02 // 0b00000010	Comando "CURSOR HOME"
//[0 0 | 0 0 0 0 0 0 1 x]
.section .data 
.section .text

.global		LCD_Borrar.global		LCD_EnviarChar.global		LCD_EnviarCmd.global		LCD_ImprimirString.global		LCD_init

// ******************************************************************
// LCD_init: Inicializa el LCD 
//parametros de entrada: Ninguno
//parametros de salida: Ninguno
// ******************************************************************
LCD_init:  
	push	TEMP

	//borro el puerto de datos y control
	cbi		LCD_DATPORT,LCD_D4
	cbi		LCD_DATPORT,LCD_D5
	cbi		LCD_DATPORT,LCD_D6
	cbi		LCD_DATPORT,LCD_D7
	cbi		LCD_CTRPORT,LCD_E
	cbi		LCD_CTRPORT,LCD_RW
	cbi		LCD_CTRPORT,LCD_RS
	//datos y control como salida
	sbi		LCD_DATDDR,LCD_D4
	sbi		LCD_DATDDR,LCD_D5
	sbi		LCD_DATDDR,LCD_D6
	sbi		LCD_DATDDR,LCD_D7
	sbi		LCD_CTRDDR,LCD_E
	sbi		LCD_CTRDDR,LCD_RW
	sbi		LCD_CTRDDR,LCD_RS
	//inicializo el LCD como indica la datasheet
	sbi     LCD_DATPORT,LCD_D6
	sbi     LCD_DATPORT,LCD_D7
	rcall   LCD_PulsoEnable			//Pulso E
	rcall	DELAY10MS
	rcall	LCD_PulsoEnable			//Pulso E
	rcall	DELAY10MS
	rcall	LCD_PulsoEnable			//Pulso E
	rcall	DELAY10MS
	ldi		TEMP, LCD_FUNC_SET		//Comando FUNCION SET
	rcall	LCD_EnviarCmd
	ldi		TEMP, LCD_CURS_SHIFT	//Comando CURSOR SHIFT
	rcall	LCD_EnviarCmd
	ldi		TEMP, LCD_DISP_ON		//Comando DISPLAY ON OFF
	rcall	LCD_EnviarCmd
	ldi		TEMP, LCD_ENTRY_MODE	//Comando LCD ENTRY MODE
	rcall	LCD_EnviarCmd
	rcall	LCD_Borrar				//Borrar LCD

	pop		TEMP
	ret
	
// ******************************************************************
// LCD_ImprimirString: Imprime en el display donde este el cursor hasta
// encontrarse con 0
//parametros de entrada:  Z - string
//parametros de salida: Ninguno
// ******************************************************************
LCD_ImprimirString:
	push	TEMP
	push    TEMP2
	push	ZH
	push	ZL

	ldi		TEMP2,0
LCD_ImprimirLoop: 
	lpm		TEMP,Z+				// Carga el contenido de Z en TEMP
	inc		TEMP2
	cpi		TEMP2,16
	breq	EXIT_PRINT
	tst		TEMP				// Resto 1 al contador de string
	breq EXIT_PRINT
	rcall	LCD_EnviarChar		// Envio Caracter
	rjmp	LCD_ImprimirLoop
    EXIT_PRINT:

	pop		ZL
	pop		ZH
	pop		TEMP2
	pop		TEMP
	ret

// ******************************************************************
// LCD_Borrar: Borra el contenido del display y pone el cursor en home
//parametros de entrada:  Z - string
//parametros de salida: Ninguno
// ******************************************************************
LCD_Borrar:   
	push	TEMP

	ldi		TEMP, LCD_CLEAR_DISP
	rcall	LCD_EnviarCmd
	ldi		TEMP, LCD_CURS_HOME
	rcall	LCD_EnviarCmd

	pop		TEMP
	ret
	
// ******************************************************************
//LCD_EnviarCmd: Envia el elegido comando al display
//parametros de entrada:  TEMP - Comando
//parametros de salida: Ninguno
// ******************************************************************
LCD_EnviarCmd:   
	push	TEMP
	push	TEMP2
	push	TEMP3

	rcall   DELAY10MS			// se crea un delay para no probar si el lcd se encuentra ocupado
	mov		TEMP2, TEMP			// Se utilizan mascaras para no pisar los datos del puerto 
	andi	TEMP2, 0xF0			// que no son del LCD.
	in		TEMP3, LCD_DATPORT	
	andi	TEMP3, 0x0F
	or		TEMP2,TEMP3
	out		LCD_DATPORT,TEMP2	//Se manda el primer nibble
	rcall	LCD_PulsoEnable		//Pulso enable
	swap	TEMP				//Se hace lo mismo que antes pero con los nibbles intercambiados
	mov		TEMP2, TEMP
	andi	TEMP2, 0xF0
	in		TEMP3, LCD_DATPORT
	andi	TEMP3, 0x0F
	or		TEMP2,TEMP3
	out		LCD_DATPORT,TEMP2
	rcall	LCD_PulsoEnable		//Pulso enable

	pop		TEMP3
	pop		TEMP2
	pop		TEMP
	ret
	
// ******************************************************************
// LCD_EnviarChar: Envia el caracter elegido al display
//parametros de entrada:  TEMP - Char
//parametros de salida: Ninguno
// ******************************************************************
LCD_EnviarChar:
	push	TEMP
	push	TEMP2
	push	TEMP3

	rcall	DELAY10MS				// se crea un delay para no probar si el lcd se encuentra ocupado
	sbi		LCD_CTRPORT,LCD_RS		// RS ON: Escritura de DRAM Habilitada
	mov		TEMP2, TEMP				// Se utilizan mascaras para no pisar los datos del puerto 
	andi	TEMP2, 0xF0				// que no son del LCD.
	in		TEMP3, LCD_DATPORT		
	andi	TEMP3, 0x0F
	or		TEMP2,TEMP3
	out		LCD_DATPORT,TEMP2		//Se manda el primer nibble
	rcall	LCD_PulsoEnable			//Pulso enable
	swap	TEMP					//Se hace lo mismo que antes pero con los nibbles intercambiados
	mov		TEMP2, TEMP
	andi	TEMP2, 0xF0
	in		TEMP3, LCD_DATPORT
	andi	TEMP3, 0x0F
	or		TEMP2,TEMP3
	out		LCD_DATPORT,TEMP2
	rcall	LCD_PulsoEnable			//Pulso enable
	cbi		LCD_CTRPORT,LCD_RS		//RS OFF: Escritura de DRAM Deshabilitada

	pop		TEMP3
	pop		TEMP2
	pop		TEMP
	ret
	
// ******************************************************************
// LCD_PulsoEnable: Envia un pulso a la pata E del LCD 
//parametros de entrada: Ninguno
//parametros de salida: Ninguno
// ******************************************************************
LCD_PulsoEnable:   
	sbi   	LCD_CTRPORT, LCD_E	//Enable SET
	rcall	DELAY2NOP
    cbi   	LCD_CTRPORT, LCD_E	//Enable CLEAR
    RET

// ******************************************************************	
// Delay de 2 Nops para mandar pulsos cortos (CLK: 16 MHZ ---> 2 micro segundos)
DELAY2NOP:
	nop
	nop
	RET

/*// *****************************************************************
// strlen - calcula la longitud de caracteres del str guardado en code segment, el valor queda en TEMP2
// creacion: 28/05/2017 (se crea para poder imprimir un string largo y que salte en el lcd a la siguiente linea )
//
_STRLEN:
   push     TEMP    // no queremos tocar TEMP (esta va a ser la variable a guardar el caracter a comparar por '\0')
   push     ZL
   push     ZH
   ldi      TEMP2,0 // inicializamos el contador en 0 en TEMP2
   LOOP_STRLEN:            // Iteramos sobre los caracteres en el string cargado en el puntero z    
    lpm		TEMP,Z+				// Carga el contenido de Z en R0
    inc     TEMP2
	tst     TEMP
    breq    EXIT_LOOP_STRLEN
	rjmp    LOOP_STRLEN
   EXIT_LOOP_STRLEN:
    pop ZH
	pop ZL
	pop TEMP
    reti*/

