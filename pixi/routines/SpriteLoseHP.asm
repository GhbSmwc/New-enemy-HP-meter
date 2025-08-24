	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Damage sprite subroutine.
;Input:
; - $00 to $00+!Setting_SpriteHP_TwoByteHP = Amount of damage.
;Output:
; - HP is already subtracted, if damage > currentHP, HP is
;   set to 0.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?LoseHP:
	TXA
	STA !Freeram_SpriteHP_SlotToDisplayHP
	if !Setting_SpriteHP_BarAnimation != 0 && !Setting_SpriteHP_BarChangeDelay != 0
		LDA.b #!Setting_SpriteHP_BarChangeDelay		;\Freeze damage indicator
		STA !Freeram_SpriteHP_BarAnimationTimer,x	;/
	endif
	if !Setting_SpriteHP_TwoByteHP != 0
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
		RTL

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
	RTL