TEMP		= 16TEMP2		= 17
.section .text
.global		DELAY1MS
.global		DELAY10MS
.global		DELAY100MS
.global		DELAY1S
// ******************************************************************
//  DELAYS
//	No son exactos
// ******************************************************************
DELAY1S:
	push	TEMP
	ldi		TEMP,10
LOOP1S:
	rcall	DELAY100MS
	dec		TEMP
	brne	LOOP1S
	pop		TEMP
	ret
// ******************************************************************
DELAY100MS:
	push	TEMP
	ldi		TEMP,101
LOOP100MS:
	rcall	DELAY1MS
	dec		TEMP
	brne	LOOP100MS
	pop		TEMP
	ret
// ******************************************************************
DELAY10MS:
	push	TEMP
	ldi		TEMP,11
LOOP10MS:
	rcall	DELAY1MS
	dec		TEMP
	brne	LOOP10MS
	pop		TEMP
	ret
// ******************************************************************
DELAY1MS:
	push	TEMP2
	push	TEMP
	ldi		TEMP2, 21
	ldi		TEMP, 197
LOOP1MS:
	dec		TEMP
	brne	LOOP1MS
	dec		TEMP2
	brne	LOOP1MS
	pop		TEMP
	pop		TEMP2
	RET