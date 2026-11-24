; === File inclusions ========================================================
.include "macros.asm"		; include macro definitions
.include "definitions.asm"	; include register/constant definitions

; === Interrupt vector table =================================================
.org	0
	jmp	reset
.org 	ADCCaddr
	jmp	ADCCaddr_sra

; --- dans un .equ commun -------------------------------------
.equ  SWITCH0   = 0        ; PD0 = bit du bouton (entrée + pull-up)

; === SRAM variables =========================================================
.dseg
mode_prev:  .byte 1
; --- Pointeur vers la prochaine note de Ambiance -------------
amb_ptr_lo: .byte 1
amb_ptr_hi: .byte 1
.cseg

; === Reset ==============================================================
reset:
	LDSP    RAMEND        ; Load Stack Pointer with top of RAM

	rcall   LCD_init      ; Put LCD in 4?bit, 2?line, clear mode
	rcall   encoder_init  ; Enable INT0/1 & prepare state vars
	rcall   wire1_init    ; Initialise 1?Wire bus on the data pin
	rcall   ws2812b4_init ; Prepare WS2812B timing routine

	OUTI    DDRB, 0xFF    ; PORTB ? WS2812B data (all set outputs)
	OUTI    DDRD, 0x00    ; PORTD inputs (push buttons, etc.)
	sbi     DDRE, SPEAKER ; as output for audio click

	clr     r1           
	ldi     b0, 0        
	ldi     b3, 0

	OUTI    DDRC, 0xFF    ; PORTC used by LCD (E, RS, D4?D7…)
	OUTI    ADMUX, 0x63   ; ADC6, Vref=Vcc, left?adjust result
	OUTI    ADCSR, (1<<ADEN)|(1<<ADIE)|6 ; Enable ADC + interrupt

	ldi r16, low(2*ambiance)      ; adresse du début du LUT
	sts amb_ptr_lo, r16
	ldi r16, high(2*ambiance)
	sts amb_ptr_hi, r16

	sei                     ; Enable global interrupts

	rjmp    main           

; === Library modules ========================================================	
.include "lcd.asm"			; include the LCD routines
.include "printf.asm"		; include formatted printing routines
.include "encoder.asm"		; include rotary encoder routines
.include "wire1.asm"	    ; include Dallas 1-wire(R) routines
.include "temperature.asm"
.include "distance.asm"
.include "leds.asm"
.include "sound.asm"

; === Main ========================================================
main:
    rcall encoder
    CYCLIC b3, 0, 1

    lds     b2, mode_prev     ; charger ancien mode
    cp      b3, b2            ; comparer avec le mode actuel
    breq    skip_mode        ; si inchangé, ne fait rien

    sts     mode_prev, b3    ; sinon, met à jour
    rcall   mode             ; et appelle affichage
skip_mode:
    rjmp main

;  mode  —  Sélection du mode à éxécuter
mode:
	sbic PINE, ENCOD_I
	rjmp PC+2
	rjmp mode
	rcall kill_led
    cpi     b3, 0
    breq    dista
	rcall kill_led
    cpi     b3, 1
    breq    temp
	rcall kill_led
    cpi     b3, 2
    _BREQ    son
    ret

; ==== MODE 0: DISTANCE ====
dista:
	_CPI e0, 1
	breq PC+2
	rcall ambiance_sound
	rcall encoder
    CYCLIC b3, 0, 2

    lds     b2, mode_prev
    cp      b3, b2
    brne    exit_mode
	
	PRINTF	LCD
	.db	CR,CR,"Distance         ",0		
	sbic PINE, ENCOD_I
	rjmp dista
	rcall loop_dista
	ret

loop_dista:

    rcall show_dist           
	sbic PINE, ENCOD_I
	rjmp loop_dista
	rjmp mode

exit_mode:
    sts  mode_prev, b3
    rjmp mode        

; ==== MODE 1: TEMPERATURE ====
temp:
	_CPI e0, 1
	breq PC+2
	rcall ambiance_sound
	rcall encoder
    CYCLIC b3, 0, 2

    lds     b2, mode_prev
    cp      b3, b2
    brne    exit_mode
	
	PRINTF	LCD
	.db	CR,CR,"Temperature        ",0	
	sbic PINE, ENCOD_I
	rjmp temp
	rcall loop_temp
	ret

loop_temp:
	rcall show_temp          
	sbic PINE, ENCOD_I
	rjmp loop_temp
	rjmp mode

; ==== MODE 2: AMBIANCE sound ====
son:
	_CPI e0, 1
	breq PC+2
	rcall ambiance_sound
	rcall encoder
    CYCLIC b3, 0, 2

    lds     b2, mode_prev
    cp      b3, b2
    brne    exit_mode
	
	PRINTF	LCD
	.db	CR,CR,"Ambiance         ",0		
	sbic PINE, ENCOD_I
	rjmp son
	rcall loop_son
	ret

loop_son:
    rcall ambiance_off           
	sbis PINE, ENCOD_I
	rjmp loop_son
	rjmp mode

;  kill_led  —  Effacer le LCD & éteindre toutes les leds de la matrice
kill_led:
	rcall LCD_kill
	rcall turn_off
	rcall LCD_init
ret

ambiance_off:

PRINTF	LCD
.db	CR,CR,"On    /    Off",0

	sbis PIND,0
	cbi DDRE, SPEAKER
	sbis PIND,1
	sbi DDRE, SPEAKER
ret 	


; =============================================================
; Ambiance 
; =============================================================
ambiance:
    .db  do2, mi2, so2, si2      ; Cmaj7
    .db  la2, do3, mi3, so3      ; Am7
    .db  re2, fa2, la2, do3      ; Dm7
    .db  so2, si2, re3, fa3      ; G7

    .db  fa2, la2, do3, mi3      ; Fmaj7
    .db  mi2, so2, do3, mi3      ; C/E (1re renversement)
    .db  re2, so2, do3, so2      ; Gsus4/D
    .db  do2, mi2, so2, la2      ; C6

    .db  0                       ; fin – la routine reboucle

; =============================================================
.equ NOTE_DUR = 80        ; 20 × 2,5 ms ? 50 ms

ambiance_sound:
        ; ----- 1. Charger le pointeur courant ----------------
        lds     zl, amb_ptr_lo
        lds     zh, amb_ptr_hi

        ; ----- 2. Lire la note --------------------------------
        lpm                         ; r0 ? NOTE
        tst     r0
        brne    play_note          ; ?0 ? vraie note

        ; ----- 3. Fin de table ? repartir du début ------------
        ldi     zl, low(2*ambiance)
        ldi     zh, high(2*ambiance)
        lpm                         ; relire la première note

play_note:
        mov     a0, r0              ; NOTE ? a0 (argument `sound`)

        ; ----- 4. Avancer le pointeur et le stocker -----------
        adiw    zl, 1
        sts     amb_ptr_lo, zl
        sts     amb_ptr_hi, zh

        ; ----- 5. Jouer la note -------------------------------
        ldi     b0, NOTE_DUR        ; durée fixe
        rcall   sound
        ret

end:	rjmp	end
