	incsrc "../GraphicalBarDefines.asm"
	incsrc "../StatusBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This routine directly writes the tile to the status bar or
;overworld border plus, filling left to right.
;
;Note: This only writes up to 128 (64 if using super status
;bar and OWB+ format) tiles. But it is unlikely you would ever
;need that much tiles, considering that the screen is 32 ($20)
;8x8 tiles wide.
;
;Input:
; - $00 to $02: The starting byte address location of the status bar (tile number).
;   This is the leftmost tile to position.
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
;    modify the X-bit flip flag. You need to flip them yourself for this routine alone for flipped bars.
;Output:
; - [RAMAddressIn00] to [RAMAddressIn00 + ((NumberOfTiles-1)*TileFormat]: the status bar/OWB+
;   RAM write range.
; - If using SB/OWB+ patch that allows editing YXPCCCTT in-game and have set !StatusBar_UsingCustomProperties
;   to 1:
; -- [RAMAddressIn03] to [RAMAddressIn03 + ((NumberOfTiles-1)*TileFormat]: same as above but YXPCCCTT
;Note:
; - These routines can be used on stripe image for both horizontal (left to right) and vertical (top to
;   bottom)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?WriteBarToHUDFormat2:
		%UberRoutine(GraphicalBar_CountNumberOfTiles)
		CPX #$FF				;\If 0-1 = (-1), there is no tile to write.
		BEQ ?.Done				;/(non-existent bar)
		TXA					;\Have Y = X*2 due to SSB/OWB+ patch formated for 2 contiguous bytes per tile.
		ASL					;|
		TAY					;/
		
		?.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Write each tile.
			STA [$00],y					;/
			if !StatusBar_UsingCustomProperties != 0
				LDA $06
				STA [$03],y
			endif
			
			?..Next
				DEX
				DEY #2
				BPL ?.Loop
		
		?.Done
			RTL