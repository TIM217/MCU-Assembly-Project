; === main program ===
show_temp:

	rcall	wire1_reset			; send a reset pulse
	CA	wire1_write, skipROM	; skip ROM identification
	CA	wire1_write, convertT	; initiate temp conversion
	WAIT_MS	750					; wait 750 msec
	
	rcall	lcd_home			; place cursor to home position
	rcall	wire1_reset			; send a reset pulse
	CA	wire1_write, skipROM
	CA	wire1_write, readScratchpad	
	rcall	wire1_read			; read temperature LSB
	mov	c0,a0
	rcall	wire1_read			; read temperature MSB
	mov	a1,a0
	mov	a0,c0

	rcall LCD_kill

	rcall display_leds_temperature

	rcall LCD_init

	PRINTF	LCD
.db	"Temp=",FFRAC2+FSIGN,a,4,$42,"C ",CR,CR,0

ret