#define _SFR_ASM_COMPAT 1 
#define __SFR_OFFSET 0
// Pointers in use: ->Z(r31 r30),Y(r29 r28),->X(r27 r26)
DATA			= 20
COUNTER			= 19

RX_PIN          = 0
TX_PIN          = 1
SERIAL_PORT     = PORTD
SERIAL_DDR      = DDRD

//USART parameter from Atmega328p Datasheet
// Error < 0.2% bitrate = 9615.38
UBRR = 103

.section .text
.global		USART_init
.global		Serial_TX
.global		GPS_getString
.global     GPS_getString_SD
.global     GPS_lookForFix

.extern		buffer_sd
.extern		buffer_gps_ubx

// GPS LCD Messages

// ******************************************************************
// USART_init: initialize USART
// Input: Nothing
// Output:Nothing
// ******************************************************************
USART_init:
	push	TEMP
	cbi		SERIAL_DDR,RX_PIN	//RX_PIN is an Input
	cbi		SERIAL_PORT,RX_PIN	//no PULLUP
	sbi		SERIAL_DDR,TX_PIN	//TX_PIN is an Output

	// USART Parameters:
	// 8 data bits, 1 stop bit, no parity
	// USART Baud Rate: 9600
	LDI		TEMP, lo8(UBRR)
	STS		UBRR0L,TEMP
	LDI		TEMP, hi8(UBRR)
	STS		UBRR0H,TEMP

	; Asynchronic mode (UMSEL01=0 y UMSEL00=0) No parity (UPM01=0 y UPM00=0), 1 stop bit (USBS0=0), 8 data bits (UCSZ01=1 y UCSZ00=1)
	; UCSR0C = |UMSEL01|UMSEL00|UPM01|UPM00|USBS0|UCSZ01|UCSZ00|UCPOL0|
	LDI		TEMP,(1<<UCSZ01)|(1<<UCSZ00)
	STS		UCSR0C,TEMP

	// RX enable (RXEN0), TX enable (TXEN0), UCSZ02=0 8 data bites
	// UCSR0B = |RXCIE0|TXCIE0|UDRIE0|RXEN0|TXEN0|UCSZ02|RXB80|TXB80|
	LDI		TEMP, (1<<RXEN0)|(1<<TXEN0)		//To activate interruption RXCIE0|(1<<RXCIE0)
	STS		UCSR0B, TEMP
	//cli
	//sei
	pop		TEMP
	ret

// ******************************************************************
// GPS_getString: get string from GPS using UART (UBX protocol)
// Input: buffer_gps_ubx empty
// Output: buffer_gps_ubx with string
// ******************************************************************
GPS_getString:
// GPS_lookForFix: looks if string in buffer_gps_ubx is fixed
// Input: buffer_gps_ubx with UBX string
// Output:ANS - 0 if fixed, 1 if not fixed
// ******************************************************************
      NF No Fix
      DR Dead reckoning only solution
      G2 Stand alone 2D solution
      G3 Stand alone 3D solution
      D2 Differential 2D solution
      D3 Differential 3D solution
      RK Combined GPS + dead reckoning solution
      TT Time only solution  */
	push DATA
	push TEMP

LOOP_TX:				// Wait for empty transmit buffer
	lds TEMP,UCSR0A		//Load into R17 from SRAM UCSR0A
	sbrs TEMP,UDRE0 	//Skip next instruction If Bit Register is set
	rjmp LOOP_TX
	sts UDR0,DATA

	pop TEMP
	pop DATA
	ret