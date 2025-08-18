	incsrc "../NumberDisplayRoutinesDefines.asm"
	incsrc "../NumberDisplayRoutinesDefines.asm"
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;16-bit hex to 4 (or 5)-digit decimal subroutine (using right-2-left
	;division). Example: 12345
	; 12345/10 = Q: 1234 R: 5 \These remainders are decimal digits (holds a value $00-$09; unpacked BCD)
	; 1234/10  = Q: 123  R: 4 |ordered from least significant digits to most.
	; 123/10   = Q: 12   R: 3 |
	; 12/10    = Q: 1    R: 2 |
	; 1/10     = Q: 0    R: 1 /
	;
	;Input:
	; - $00-$01 = the value you want to display
	;Output:
	; - !Scratchram_16bitHexDecOutput to !Scratchram_16bitHexDecOutput+4 = a digit 0-9 per byte table
	;   (used for 1-digit per 8x8 tile):
	; -- !Scratchram_16bitHexDecOutput+$00 = ten thousands
	; -- !Scratchram_16bitHexDecOutput+$01 = thousands
	; -- !Scratchram_16bitHexDecOutput+$02 = hundreds
	; -- !Scratchram_16bitHexDecOutput+$03 = tens
	; -- !Scratchram_16bitHexDecOutput+$04 = ones
	;
	;!Scratchram_16bitHexDecOutput is address $02 for normal ROM and $04 for SA-1.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		?SixteenBitHexDecDivision:
			if !CPUMode == 0
				PHX
				PHY

				LDX #$04	;>5 bytes to write 5 digits.

				?.Loop
				REP #$20	;\Dividend (in 16-bit)
				LDA $00		;|
				STA $4204	;|
				SEP #$20	;/
				LDA.b #10	;\base 10 Divisor
				STA $4206	;/
				JSR ?.Wait	;>wait
				REP #$20	;\quotient so that next loop would output
				LDA $4214	;|the next digit properly, so basically the value
				STA $00		;|in question gets divided by 10 repeatedly. [Value/(10^x)]
				SEP #$20	;/
				LDA $4216	;>Remainder (mod 10 to stay within 0-9 per digit)
				STA $02,x	;>Store tile

				DEX
				BPL ?.Loop

				PLY
				PLX
				RTL

				?.Wait
				JSR ?..Done		;>Waste cycles until the calculation is done
				?..Done
				RTS
			else
				PHX
				PHY

				LDX #$04

				?.Loop
				REP #$20			;>16-bit XY
				LDA.w #10			;>Base 10
				STA $02				;>Divisor (10)
				SEP #$20			;>8-bit XY
				%UberRoutine(MathDiv)		;>divide
				LDA $02				;>Remainder (mod 10 to stay within 0-9 per digit)
				STA.b !Scratchram_16bitHexDecOutput,x	;>Store tile

				DEX
				BPL ?.Loop

				PLY
				PLX
				RTL
			endif