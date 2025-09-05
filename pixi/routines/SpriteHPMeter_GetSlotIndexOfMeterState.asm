	incsrc "../EnemyHPMeterDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This essentially takes the value of !Freeram_SpriteHP_MeterState, and modulo by
;!sprite_slots, which can be used to detect if what sprite slot index number the meter is
;on is on the same slot number as the currently processed sprite.
;
;Output:
; - !Scratchram_SpriteHP_SpriteSlotToDisplay: Sprite slot index number. $FF means invalid.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?GetHPMeterSlotIndexNumber:
		LDA !Freeram_SpriteHP_MeterState
		CMP.b #!SprSize
		BCC ?.Normal				;0 to 11 or 0 to 21
		CMP.b #(!SprSize*2)
		BCC ?.IntroFillMode			;12 to 23 or 22 to 43
		LDA #$FF
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL
		?.IntroFillMode
			SEC
			SBC.b #!SprSize
		?.Normal
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL