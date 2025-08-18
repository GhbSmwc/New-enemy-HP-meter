	incsrc "../NumberDisplayRoutinesDefines.asm"
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Convert 16-bit number to OWB digits.
	;Usage with other routines:
	;	JSL SixteenBitHexDecDivision
	;	JSL RemoveLeadingZeroes16Bit		;>Omit this if you want to display leading zeroes
	;	JSL SixteenBitHexDecDivisionToOWB
	;
	;Input:
	; - !Scratchram_16bitHexDecOutput (5 bytes): The characters to convert
	;Output:
	; - !Scratchram_16bitHexDecOutput (5 bytes): The converted characters.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		?SixteenBitHexDecDivisionToOWB:
		LDX #$04
		
		?.Loop
		LDA !Scratchram_16bitHexDecOutput,x
		CMP #!StatusBarBlankTile
		BEQ ?..Blank
		
		?..Digit
		CLC
		ADC #$22
		BRA ?..Write
		
		?..Blank
		LDA #!OverWorldBorderBlankTile
		
		?..Write
		STA !Scratchram_16bitHexDecOutput,x
		DEX
		BPL ?.Loop
		RTL