	incsrc "../EnemyHPMeterDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This essentially takes the value of !Freeram_SpriteHP_MeterState, and modulo by
;!sprite_slots, which can be used to detect if what sprite slot index number the meter is
;on is on the same slot number as the currently processed sprite.
;
;Output:
; - !Scratchram_SpriteHP_SpriteSlotToDisplay: Sprite slot index number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?GetHPMeterSlotIndexNumber:
		LDA #$FF
		CMP !Freeram_SpriteHP_MeterState
		BEQ ?.NonIntroFillMode
		LDA !Freeram_SpriteHP_MeterState
		CMP.b #!SprSize
		BCC ?.NonIntroFillMode
		?.IntroFillMode
			SEC
			SBC.b #!SprSize
		?.NonIntroFillMode
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL