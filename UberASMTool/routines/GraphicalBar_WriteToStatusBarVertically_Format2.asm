	incsrc "../GraphicalBarDefines.asm"
	incsrc "../StatusBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write graphical bar vertically
;Input;
; - $00 to $02: The starting byte address location of the status bar (tile number).
;   This is where top or bottom where the fill starts at.
; -- If you're using SA-1 mode here and using vanilla status bar,
;    the status bar tilemap table is moved to bank $40.
; - !Scratchram_GraphicalBar_LeftEndPiece: Number of pieces in left byte (0-255), also
;   the maximum amount of fill for this byte itself. If 0, it's not included in table.
; - !Scratchram_GraphicalBar_MiddlePiece: Same as above but each middle byte.
; - !Scratchram_GraphicalBar_RightEndPiece: Same as above but for right end.
; - !Scratchram_GraphicalBar_TempLength: The length of the bar (only counts
;   middle bytes)
; - If you are using custom status bar patches that enables editing tile properties in-game,
;   and have set "!StatusBar_UsingCustomProperties" to 1, you have another input:
; -- $03 to $05: Same as $00 to $02 but for tile properties instead of tile numbers.
; -- $06: The tile properties (YXPCCCTT) you want it to be. Note: This does not automatically
;    modify the Y-bit flip flag. You need to flip them yourself for this routine alone for flipped bars.
; - $07: X = $00 for upwards, X = $02 for downwards, don't use any other values.
;Output:
; - [RAMAddressIn00]-(X*32*Format) where X increases from 0 to NumberOfTiles-1 for upwards, [RAMAddressIn00]+(X*32*Format) where X increases from 0 to NumberOfTiles-1 for downwards:
;   the tiles written to the status bar
; - If using SB/OWB+ patch that allows editing YXPCCCTT in-game and have set !StatusBar_UsingCustomProperties
;   to 1:
; -- [RAMAddressIn03]-(X*32*Format) where X increases from 0 to NumberOfTiles-1:
;    the tile properties written:
; - $00 to $02: The address after writing the last tile (as if writing the amount of tiles plus 1), can be used
;   for writing static end tile where the fill ends at.
; - $03 to $05: The address after writing the last tile (as if writing the amount of tiles plus 1), can be used
;   for writing static end tile where the fill ends at.
;
;Note:
; - This only works with status bar having a width of 32 8x8 tiles on each row. So far at the time of writing
;   this is that the Super Status Bar and SMB3 status bar patches are the only status bar patches that offer
;   tile property modification and have more than 1 contiguous row that each have the same number of tiles.
; - Don't use these for stripe image. Stripe already supports vertical mode for writing each tile data 2-bytes
;   apart. Use WriteBarToHUD or WriteBarToHUDLeftwards instead.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?WriteBarToHUDVerticallyFormat2:
	PHB						;\Adjust bank so that 16-bit table addressing works properly
	PHK						;|
	PLB						;/
	%UberRoutine(GraphicalBar_CountNumberOfTiles)	;X = number of tiles, -1
	CPX #$FF					;\If 0-1 = (-1), there is no tile to write.
	BEQ ?.Done					;/(non-existent bar)
	TXY						;>Move to Y (countdown loop)
	LDX #$00					;>X, unlike in WriteBarToHUD, increases, not decreases
	;note to self: indexes cannot be negative and point to addresses byte before the address $xxxxxx
	;in "LDA/STA $XXXXXXX,X/Y". So we have to directly modify the $XXXXXXX.
	;Also, upwards is a "negative direction" but most games displaying vertical health bars increase
	;direction is upwards.
	
	?.Loop
		LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Write each tile.
		STA [$00]					;/
		if !StatusBar_UsingCustomProperties != 0
			LDA $06
			STA [$03]
		endif
		PHX			;>Preserve X
		LDX $07
		REP #$20							;\Go to the row above
		LDA $00								;|
		CLC								;|
		ADC ?.WriteBarToHUDVerticallyUpDownDisplacementFormat2,x	;|
		STA $00								;|
		if !StatusBar_UsingCustomProperties != 0
			LDA $03								;|
			CLC								;|
			ADC ?.WriteBarToHUDVerticallyUpDownDisplacementFormat2,x	;|
			STA $03								;|
		endif
		SEP #$20						;/
		PLX			;>Restore X
		?..Next
			INX
			DEY
			BPL ?.Loop
	
	?.Done
		PLB
		RTL
?.WriteBarToHUDVerticallyUpDownDisplacementFormat2
dw -64			;>RAM $07 = $00
dw 64			;>RAM $07 = $02