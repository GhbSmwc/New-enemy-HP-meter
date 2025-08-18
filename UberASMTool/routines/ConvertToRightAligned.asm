	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Convert left-aligned to right-aligned.
	;
	;Use this routine after calling SuppressLeadingZeros and before calling
	;WriteStringDigitsToHUD. Note: Be aware that the math of handling the address
	;does NOT account to changing the bank byte (address $XX****), so be aware of
	;having status bar tables that crosses bank borders ($7EFFFF, then $7F0000,
	;as an made-up example, but its unlikely though). This routine basically takes
	;a given RAM address stored in $00-$02, subtract by how many tiles (minus 1), then
	;$00-$02 is now the left tile position.
	;
	;Input:
	; - $00-$02 = 24-bit address location to write to status bar tile number.
	; - If tile properties are edit-able:
	; -- $03-$05 = Same as $00-$02 but tile properties.
	; - X = The number of characters to write, ("123" would have X = 3)
	;Output:
	; - $00-$02 and $03-$05 are subtracted by [(NumberOfCharacters-1)*!StatusbarFormat]
	;   so that the last character is always at a fixed location and as the number
	;   of characters increase, the string would extend leftwards. Therefore,
	;   $00-$02 and $03-$05 before calling this routine contains the ending address
	;   which the last character will be written.
	;
	;Note:
	; - ConvertToRightAligned is designed for [TTTTTTTT, TTTTTTTT,...], [YXPCCCTT, YXPCCCTT,...]
	; - ConvertToRightAlignedFormat2 is designed for [TTTTTTTT, YXPCCCTT, TTTTTTTT, YXPCCCTT...]
	; - This routine is meant to be used when displaying 2 numbers (For example: 123/456). Since
	;   when displaying a single number, using HexDec and removing leading zeroes (turns them
	;   into leading spaces) is automatically right-aligned, using this routine is pointless.
	; - X register is not modified here at all.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?ConvertToRightAligned:
		TXA					;>Transfer X (number of tiles) to A
		DEC					;>Decrement A (since it's 0-based)
		TAY					;>Transfer A status bar leftmost position to Y (Y is how many tiles of offset by, need this later)
		REP #$21				;\-(NumberOfTiles-1)...
		AND #$00FF				;|
		EOR #$FFFF				;|
		INC A					;/
		ADC $00					;>...+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
		STA $00					;>Store difference in $00-$01
		SEP #$20				;\Handle bank byte
	;	LDA $02					;|
	;	SBC #$00				;|
	;	STA $02					;/
		
		if !StatusBar_UsingCustomProperties != 0
			TYA
			REP #$21				;\-(NumberOfTiles-1)
			AND #$00FF				;|
			EOR #$FFFF				;|
			INC A					;/
			ADC $03					;>+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
			STA $03					;>Store difference in $00-$01
			SEP #$20				;\Handle bank byte
	;		LDA $05					;|
	;		SBC #$00				;|
	;		STA $05					;/
		endif
		RTL