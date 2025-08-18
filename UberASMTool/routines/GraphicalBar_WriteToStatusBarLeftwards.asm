	incsrc "../GraphicalBarDefines.asm"
	incsrc "../StatusBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Same as WriteBarToHUD, but fills leftwards as opposed to
;rightwards.
;
;Note:
; - This is still "left anchored", meaning the address
;   to write your bar on would be the left side where the fill
;   edge is at when full.
; - Does not reverse the order of data in
;   !Scratchram_GraphicalBar_FillByteTbl, it simply writes to the
;   HUD in reverse order.
; - These routines can be used on stripe image for both horizontal
;   (right to left) and vertical (bottom to top).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?WriteBarToHUDLeftwards:
		%UberRoutine(GraphicalBar_CountNumberOfTiles)
		CPX #$FF
		BEQ ?.Done
		LDY #$00
		
		?.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x
			STA [$00],y
			if !StatusBar_UsingCustomProperties != 0
				LDA $06
				STA [$03],y
			endif
		
			?..Next
				INY
				DEX
				BPL ?.Loop
	
		?.Done
			RTL