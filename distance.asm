;.include "led_distance.asm"

; === interrupt service routines
ADCCaddr_sra:
	ldi	r23,0x01			; set the flag	
	reti					; ADIF cleared here

; === initialization (reset) ===

; === main program ===
show_dist:

	WAIT_MS	1000
	clr	r23					; reset r23 flag

	sbi	ADCSR,ADSC			; AD start conversion
	WB0	r23,0				; wait as long as flag reset
							;>flag set in the interrupt service routine
	
	in	a0,ADCL				; read low byte first
	in	a1,ADCH				; read high byte second

	mov b0, a1

	; === Charger le dividende : 1515 = 0x05EB ===
    ldi   a1, high(1515)
    ldi   a0, low(1515)

	; === Appeler la division ===
    rcall div21

	;ldi a0, low(c)
	;ldi a1, high(c)

	rcall LCD_kill

; === NOUVEAU : mets à jour les LEDs =========================
    rcall update_leds_by_distance   ; <<< appel sûr

	rcall LCD_init

	PRINTF	LCD				; print formatted
;.db	CR,CR,"ADC=",FHEX2,a,"=",FDEC2,a,"    ",0
.db CR,CR,"Dist=",FDEC2,c," cm   ",0

	ret			; jump back to main

div21:	MOV2	c1,c0, a1,a0	; c will contain the result
	clr	d0						; d will contain the remainder
	ldi	w,16					; load bit counter
_d21:	ROL3	d0,c1,c0		; shift carry into result c
	sub	d0,b0					; subtract b from remainder
	brcc	PC+2			
	add	d0,b0					; restore if remainder became negative
	DJNZ	w,_d21				; Decrement and Jump if bit-count Not Zero
	ROL2	c1,c0				; last shift (carry into result c)
	COM2	c1,c0				; complement result
	ret