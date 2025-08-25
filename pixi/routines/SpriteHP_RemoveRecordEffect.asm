incsrc "../GraphicalBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This subroutine sets the graphical bar animation
;fill value to its current HP fill amount. Effectively
;removing the transparent effect of taking damage.
;
;Output:
; - $00 = Amount of fill in the bar of the sprite's
;   current HP.
;Overwritten:
; - !Scratchram_SpriteHP_SpriteSlotToDisplay: Current
;   sprite slot to show HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	LDA.b #!Setting_SpriteHP_GraphicalBar_LeftPieces
	STA !Scratchram_GraphicalBar_LeftEndPiece
	LDA.b #!Setting_SpriteHP_GraphicalBar_MiddlePieces
	STA !Scratchram_GraphicalBar_MiddlePiece
	LDA.b #!Setting_SpriteHP_GraphicalBar_RightPieces
	STA !Scratchram_GraphicalBar_RightEndPiece
	LDA.b #!Setting_SpriteHP_GraphicalBarMiddleLength
	STA !Scratchram_GraphicalBar_TempLength
	PHX
	%SpriteHPMeter_GetSlotIndexOfMeterState()
	LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
	LDA !Freeram_SpriteHP_CurrentHPLow,x
	STA !Scratchram_GraphicalBar_FillByteTbl
	LDA !Freeram_SpriteHP_MaxHPLow,x
	STA !Scratchram_GraphicalBar_FillByteTbl+2
	if !Setting_SpriteHP_TwoByte
		LDA !Freeram_SpriteHP_CurrentHPHi,x
		STA !Scratchram_GraphicalBar_FillByteTbl+1
		LDA !Freeram_SpriteHP_MaxHPHi,x
		STA !Scratchram_GraphicalBar_FillByteTbl+3
	else
		LDA #$00
		STA !Scratchram_GraphicalBar_FillByteTbl+1
		STA !Scratchram_GraphicalBar_FillByteTbl+3
	endif
	if !Setting_SpriteHP_BarFillRoundDirection == 0
		%GraphicalBar_CalculatePercentage()
	elseif !Setting_SpriteHP_BarFillRoundDirection == 1
		%GraphicalBar_CalculatePercentageRoundDown()
	elseif !Setting_SpriteHP_BarFillRoundDirection == 2
		%GraphicalBar_CalculatePercentageRoundUp()
	endif
	;$00~$01 = percentage
	if !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 1
		%GraphicalBar_RoundAwayEmpty()
	elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 2
		%GraphicalBar_RoundAwayFull()
	elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 3
		%GraphicalBar_RoundAwayEmptyFull()
	endif
	PLX
	RTL
	