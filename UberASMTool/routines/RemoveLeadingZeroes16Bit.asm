incsrc "../GraphicalBarDefines.asm"
incsrc "../PlayerHPDefines.asm"
incsrc "../StatusBarDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Leading zeroes remover.
;Writes $FC on all leading zeroes (except the 1s place),
;Therefore, numbers will have leading spaces instead.
;
;Example: 00123 ([$00, $00, $01, $02, $03]) becomes
; __123 ([$FC, $FC, $01, $02, $03])
;
;Call this routine after using: [ThirtyTwoBitHexDecDivision]
;or [SixteenBitHexDecDivision].
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;16-bit version, use after [SixteenBitHexDecDivision]
		?RemoveLeadingZeroes16Bit:
		LDX #$00				;>Start at the leftmost digit
		
		?.Loop
		LDA !Scratchram_16bitHexDecOutput,x	;\if current digit non-zero, don't omit trailing zeros for the rest of the number string.
		BNE ?.NonZero				;/
		LDA #!StatusBarBlankTile		;\blank tile to replace leading zero
		STA !Scratchram_16bitHexDecOutput,x	;/
		INX					;>next digit
		CPX.b #$04				;>last digit to check. So that it can display a single 0.
		BCC ?.Loop				;>if not done yet, continue looping.
		
		?.NonZero
		RTL