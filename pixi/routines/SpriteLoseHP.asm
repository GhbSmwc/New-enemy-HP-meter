	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Damage sprite subroutine.
;Input:
; - $00 to $00+!Setting_SpriteHP_TwoByte = Amount of damage.
;Output:
; - HP is already subtracted, if damage > currentHP, HP is
;   set to 0.
;
;Note that this DOES NOT handle death sequence, only
;subtracts HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?LoseHP:
	PHY
	if !Setting_SpriteHP_BarAnimation == 0
		TXA
		STA !Freeram_SpriteHP_MeterState
	else
		LDA $00
		PHA
		if !Setting_SpriteHP_TwoByte != 0
			LDA $01
			PHA
		endif
		%SpriteHPMeter_GetSlotIndexOfMeterState()
		TXA
		CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
		BEQ ?.SameSpriteSlot
		STA !Freeram_SpriteHP_MeterState
		?.Different
			%SpriteHP_RemoveRecordEffect()		;>Get fill amount of current HP *before* the damage (and not before even that) to properly show how much fill loss when switching slots.
			LDA $00
			STA !Freeram_SpriteHP_BarAnimationFill,x
		?.SameSpriteSlot
		if !Setting_SpriteHP_TwoByte != 0
			PLA
			STA $01
		endif
		PLA
		STA $00
	endif
	if !Setting_SpriteHP_BarAnimation != 0 && !Setting_SpriteHP_BarChangeDelay != 0
		LDA.b #!Setting_SpriteHP_BarChangeDelay		;\Freeze damage indicator (this makes the bar animation hangs before decreasing towards current HP fill amount)
		STA !Freeram_SpriteHP_BarAnimationTimer,x	;/
	endif
	if !Setting_SpriteHP_TwoByte != 0
		LDA !Freeram_SpriteHP_CurrentHPHi,x	;>HP high byte
		XBA					;>Transfer to A's high byte
		LDA !Freeram_SpriteHP_CurrentHPLow,x	;>HP low byte in A's low byte
		REP #$20				;>Make A read also the high byte.
		SEC					;\Subtract by damage.
		SBC $00					;/
		SEP #$20				;>8-bit A (low byte)
		BCS ?.NonNegHP				;>if HP value didn't underflow, set HP to subtracted value.
		LDA #$00				;\Set HP to 0
		STA !Freeram_SpriteHP_CurrentHPLow,x	;|
		STA !Freeram_SpriteHP_CurrentHPHi,x	;/
		BRA ?.Done

		?.NonNegHP
			STA !Freeram_SpriteHP_CurrentHPLow,x	;>Low byte subtracted HP
			XBA					;>Switch to high byte
			STA !Freeram_SpriteHP_CurrentHPHi,x	;>High byte subtracted HP
	else
		LDA !Freeram_SpriteHP_CurrentHPLow,x	;\if HP subtracted by damage didn't underflow (carry set), write HP
		SEC					;|
		SBC $00					;|
		BCS ?.NonNegHP				;/
		LDA #$00				;>otherwise if underflow (carry clear; borrow needed), set HP to 0.
		
		?.NonNegHP
		STA !Freeram_SpriteHP_CurrentHPLow,x
	endif
	?.Done
	PLY
	RTL