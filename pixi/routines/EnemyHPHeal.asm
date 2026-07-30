;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Heal sprite.
;
;Sprite regains HP, but not over max.
;
;Reason not being in shared subroutines is
;because none of SMW's sprites ever heal. Thus
;leaving only custom sprites to have this
;mechanic.
;
;Input:
;-$00-$01 is the amount of HP recovered. Only $00
; would be used should two-byte HP was set to 1
; byte.
;Output:
;-Sprite's current HP recovered, capped at max.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?Heal:
	LDA !Freeram_SpriteHP_CurrentHPLow,x
	CLC
	ADC $00
	STA !Freeram_SpriteHP_CurrentHPLow,x
	if !Setting_SpriteHP_TwoByte
		LDA !Freeram_SpriteHP_CurrentHPHi,x
		ADC $01
		STA !Freeram_SpriteHP_CurrentHPHi,x
	endif
	BCS ?.Overflow ;>If exceeding 255 or 65535, cap HP (ADC would set carry if A unsigned overflows).
	LDA !Freeram_SpriteHP_CurrentHPLow,x
	SEC
	SBC !Freeram_SpriteHP_MaxHPLow,x
	if !Setting_SpriteHP_TwoByte
		LDA !Freeram_SpriteHP_CurrentHPHi,x
		SBC !Freeram_SpriteHP_MaxHPHi,x
	endif
	BCS ?.Overflow ;>If HP is greater than max, cap HP (SBC would clear carry if A unsigned underflows (when A - B results in negatives))
	if !Setting_SpriteHP_BarAnimation == 0
		RTL
	else
		BRA ?.BarAnimation
	endif
	
	?.Overflow
		LDA !Freeram_SpriteHP_MaxHPLow,x
		STA !Freeram_SpriteHP_CurrentHPLow,x
		if !Setting_SpriteHP_TwoByte
			LDA !Freeram_SpriteHP_MaxHPHi,x
			STA !Freeram_SpriteHP_CurrentHPHi,x
		endif
	?.BarAnimation
		if !Setting_SpriteHP_BarAnimation
			LDA !Freeram_SpriteHP_MeterState	;\If HP meter is showing total HP...
			CMP.b #!sprite_slots*2				;|
			BEQ ?..AllowAnimation				;|
			CMP.b #(!sprite_slots*2)+1			;|
			BEQ ?.Done							;/
			JSL !SharedSub_SpriteHPGetSlotIndex				;\...Or that the meter is on this sprite...
			TXA												;|
			CMP !Scratchram_SpriteHP_SpriteSlotToDisplay	;|
			BNE ?.Done										;/
			
			?..AllowAnimation ;>...Then apply the animation (delay fill)
				if and(notequal(!Setting_SpriteHP_BarAnimation, 0), notequal(!Setting_SpriteHP_BarChangeDelay, 0))
					LDA.b #!Setting_SpriteHP_BarChangeDelay		;\Show amount healed (transperent part shows how much recovered)
					STA !Freeram_SpriteHP_BarAnimationTimer		;/
				endif
		endif
	?.Done
		RTL