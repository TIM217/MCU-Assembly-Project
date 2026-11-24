; WS2812b4_WR0	; macro ; arg: void; used: void
; purpose: write an active-high zero-pulse to PD1
.macro	WS2812b4_WR0
	clr u
	sbi PORTC, 1
	out PORTC, u
	nop
	nop
.endm

; WS2812b4_WR1	; macro ; arg: void; used: void
; purpose: write an active-high one-pulse to PD1
.macro	WS2812b4_WR1
	sbi PORTC, 1
	nop
	nop
	cbi PORTC, 1
.endm

; ws2812b4_init		; arg: void; used: r16 (w)
; purpose: initialize AVR to support ws2812
ws2812b4_init:
	OUTI	DDRC,0x02
ret

ws2812b4_byte3wr:

	ldi w,8
ws2b3_starta0:
	sbrc a0,7
	rjmp	ws2b3w1
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta0
ws2b3w1:
	WS2812b4_WR1
ws2b3_nexta0:
	lsl a0
	dec	w
	brne ws2b3_starta0

	ldi w,8
ws2b3_starta1:
	sbrc a1,7
	rjmp	ws2b3w1a1
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta1
ws2b3w1a1:
	WS2812b4_WR1
ws2b3_nexta1:
	lsl a1
	dec	w
	brne ws2b3_starta1

	ldi w,8
ws2b3_starta2:
	sbrc a2,7
	rjmp	ws2b3w1a2
	WS2812b4_WR0			; write a zero
	rjmp	ws2b3_nexta2
ws2b3w1a2:
	WS2812b4_WR1
ws2b3_nexta2:
	lsl a2
	dec	w
	brne ws2b3_starta2
	
ret

; ws2812b4_reset	; arg: void; used: r16 (w)
; purpose: reset pulse, configuration becomes effective
ws2812b4_reset:
	WAIT_US	50 	; 50 us are required, NO smaller works
ret

turn_off:
	clr a0
	clr a1
	clr a2
	rcall full_led
	ldi  r22, 64
	ldi zl,low(0x0400)
	ldi zh,high(0x0400)
	rcall led_loop
ret

full_led:
	ldi zl,low(0x0400)
	ldi zh,high(0x0400)
	ldi  r22, 64      ; 64 LEDs

small_loop:
	st	z+,a0
	st	z+,a1
	st  z+,a2
	dec r22
	brne small_loop
ret

write_strip:	

    ldi  r22, 8      ; 64 LEDs

mini_loop:
	st	z+,a0
	st	z+,a1
	st  z+,a2
	dec r22
	brne mini_loop

ret

led_loop:

	ld a0, z+
	ld a1, z+
	ld a2, z+

	cli
	rcall ws2812b4_byte3wr
	sei

	dec r22
	brne led_loop
	rcall ws2812b4_reset

ret

;---------------------------------------------------------------
; update_leds_by_distance  – 10 paliers de 5 cm (0?50 cm)
; Entrée : r18 = distance (0–255)  ? 1 pas = 1 cm
; Effet  : 64 WS2812B, dégradé Bleu ? Rouge
;---------------------------------------------------------------
update_leds_by_distance:
    ; === Sauvegarde des registres que l'on va modifier ============
    push r16            ; w
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22

	rcall turn_off

	ldi zl,low(0x0400)
	ldi zh,high(0x0400)

    ; ---- Choix de la couleur -------------------------------------
    mov  r18, c0        ; r18 = mesure 0..255

    ; -------- test des seuils du plus grand vers le plus petit --
    ldi  r19, 45
    cp   r18, r19
    brsh _color_red1            ; 45–50 cm

	ldi  r19, 40
    cp   r18, r19
    brsh _color_orangered       ; 45–50 cm

    ldi  r19, 35
    cp   r18, r19
    brsh _color_deeprose       ; 35–40 cm

    ldi  r19, 30
    cp   r18, r19
    brsh _color_rose           ; 30–35 cm

    ldi  r19, 25
    cp   r18, r19
    brsh _color_pink           ; 25–30 cm

    ldi  r19, 20
    cp   r18, r19
    brsh _color_purple        ; 20–25 cm

    ldi  r19, 15
    cp   r18, r19
    brsh _color_violet         ; 15–20 cm

    ldi  r19, 0
    cp   r18, r19
    brsh _color_blue         ; 10–15 cm

; ???????????????????????????????????????????????????????????????????????????
;  DÉFINITION COMPLÈTE DES COULEURS (GRB, 4 bits par composante)
;  a0 = G, a1 = R, a2 = B
; ???????????????????????????????????????????????????????????????????????????

_color_red1:                    ; R=F
    clr  a0
    ldi  a1, 0x0F
    clr  a2
	rcall write_strip

_color_orangered:              ; R=F  B=2  G=2
    ldi  a0, 0x02
    ldi  a1, 0x0F
    ldi  a2, 0x02
    rcall write_strip

_color_deeprose:               ; R=F  B=6  G=4
    ldi  a0, 0x04
    ldi  a1, 0x0F
    ldi  a2, 0x06
    rcall write_strip

_color_rose:                   ; R=F  B=8  G=4
    ldi  a0, 0x04
    ldi  a1, 0x0F
    ldi  a2, 0x08
    rcall write_strip

_color_pink:                   ; R=F  B=C  G=2
    ldi  a0, 0x02
    ldi  a1, 0x0F
    ldi  a2, 0x0C
    rcall write_strip

_color_purple:                 ; R=B  B=F
    clr  a0
    ldi  a1, 0x0B
    ldi  a2, 0x0F
    rcall write_strip

_color_violet:                 ; R=7  B=F
    clr  a0
    ldi  a1, 0x07
    ldi  a2, 0x0F
    rcall write_strip

_color_blue:
    clr  a0
    clr  a1
    ldi  a2, 0x0F
    rcall write_strip

	ldi  r22, 0x40

	ldi zl,low(0x0400)
	ldi zh,high(0x0400)

	rcall led_loop

	pop  r22
    pop  r21
    pop  r20
    pop  r19
    pop  r18
    pop  r17
    pop  r16

ret


display_leds_temperature:
    ; ---- Sauvegarde des registres sources ----------------------------------
    push  a0                 ; LSB
    push  a1                 ; MSB

    ; ---- Sauvegarde générique des registres de travail ---------------------
    push  r16
    push  r17
    push  r18
    push  r19
    push  r20
    push  r21
    push  r22

; ---------------------------------------------------------------------------
;  TEST DES PLAGES 25,0 °C ? 30,0 °C par pas de 0,5 °C
;  Échelle : température × 16  (30,0 °C = 0x01E0)
;  a0 = LSB, a1 = MSB
; ---------------------------------------------------------------------------

    ldi   r21, 0x01           ; MSB = 0x01 pour toutes les bornes

    ; ---- v ? 29,5 °C  (0x01D8) --------------------------------------------
    ldi   r20, 0xD8           ; LSB = 0xD8
    cp    a0, r20
    cpc   a1, r21
    brsh  _color_red         ; 29,5 – 30,0 °C

    ; ---- v ? 29,0 °C  (0x01D0) --------------------------------------------
    ldi   r22, 0xD0
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_red_orange           ; 29,0 – 29,5 °C

    ; ---- v ? 28,5 °C  (0x01C8) --------------------------------------------
    ldi   r22, 0xC8
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_orange         ; 28,5 – 29,0 °C

    ; ---- v ? 28,0 °C  (0x01C0) --------------------------------------------
    ldi   r22, 0xC0
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_yellow_orange  ; 28,0 – 28,5 °C

    ; ---- v ? 27,5 °C  (0x01B8) --------------------------------------------
    ldi   r22, 0xB8
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_yellow         ; 27,5 – 28,0 °C

    ; ---- v ? 27,0 °C  (0x01B0) --------------------------------------------
    ldi   r22, 0xB0
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_yellow_bright           ; 27,0 – 27,5 °C

    ; ---- v ? 26,5 °C  (0x01A8) --------------------------------------------
    ldi   r22, 0xA8
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_yellow_pale         ; 26,5 – 27,0 °C

    ; ---- v ? 26,0 °C  (0x01A0) --------------------------------------------
    ldi   r22, 0xA0
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_yellow_sopale           ; 26,0 – 26,5 °C

    ; ---- v ? 25,5 °C  (0x0198) --------------------------------------------
    ldi   r22, 0x98
    cp    a0, r22
    cpc   a1, r21
    brsh  _color_white         ; 25,5 – 26,0 °C

	rjmp _color_bleu_sky

; ???????????????????????????????????????????????????????????????????????????
;  DÉFINITION COMPLÈTE DES COULEURS (GRB, 4 bits par composante)
;  a0 = G, a1 = R, a2 = B
; ???????????????????????????????????????????????????????????????????????????

_color_red:                   ; #FF0000
    clr   a0                  ; G = 0
    ldi   a1, 0x0F            ; R = F
    clr   a2                  ; B = 0
    rjmp write_temp

_color_red_orange:            ; #FF4500
    ldi   a0, 0x04            ; G = 4
    ldi   a1, 0x0F            ; R = F
    clr   a2                  ; B = 0
    rcall write_strip

_color_orange:                ; #FF7F00
    ldi   a0, 0x07            ; G = 7
    ldi   a1, 0x0F            ; R = F
    clr   a2
    rjmp write_temp

_color_yellow_orange:         ; #FFA500
    ldi   a0, 0x0A            ; G = A
    ldi   a1, 0x0F            ; R = F
    clr   a2
    rjmp write_temp

_color_yellow:                ; #FFCC33
    ldi   a0, 0x0C            ; G = C
    ldi   a1, 0x0F            ; R = F
    ldi   a2, 0x03            ; B = 3
    rjmp write_temp

_color_yellow_bright:         ; #FFEE66
    ldi   a0, 0x0E            ; G = E
    ldi   a1, 0x0F            ; R = F
    ldi   a2, 0x06            ; B = 6
    rjmp write_temp

_color_yellow_pale:           ; #FFFF99
    ldi   a0, 0x0F            ; G = F
    ldi   a1, 0x0F            ; R = F
    ldi   a2, 0x09            ; B = 9
    rjmp write_temp

_color_yellow_sopale:         ; #FFFFCC
    ldi   a0, 0x0F            ; G = F
    ldi   a1, 0x0F            ; R = F
    ldi   a2, 0x0C            ; B = C
    rjmp write_temp

_color_white:                 ; #FFFFFF
    ldi   a0, 0x0F            ; G = F
    ldi   a1, 0x0F            ; R = F
    ldi   a2, 0x0F            ; B = F
    rjmp write_temp

_color_bleu_sky:              ; #6699FF
    ldi   a0, 0x09            ; G = 9
    ldi   a1, 0x06            ; R = 6
    ldi   a2, 0x0F            ; B = F

write_temp:
	rcall full_led

	ldi  r22, 0x40

	ldi zl,low(0x0400)
	ldi zh,high(0x0400)

	rcall led_loop

    ; ---- Restauration ------------------------------------------------------
    pop   r22
    pop   r21
    pop   r20
    pop   r19
    pop   r18
    pop   r17
    pop   r16
    pop   a1                  ; MSB
    pop   a0                  ; LSB
    ret