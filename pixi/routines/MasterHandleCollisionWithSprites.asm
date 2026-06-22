!Setting_Bobomb_ExplosionApothem = $28
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Master handle collision with sprites.
;
;Handles collision with other main sprites, extended sprites,
;and bounce block sprites.
;
;
;Input:
; - $04-$07 (4 bytes), $0A-$0B (2 bytes): Main sprite clipping (A):
; -- X position: $04 (LowByte), $0A (HighByte)
; -- Y position: $05 (LowByte), $0B (HighByte)
; -- Width: $06
; -- Height: $07
;   Make sure you preserve these values in the supplied subroutine
;   code during a collision.
;
; - $8D-$8F (3 bytes): 24-bit address location of a subroutine
;   to call for each sprite colliding with this main sprite.
;   Same above, make sure the provided subroutine preserve this
;   value during a collision. Warning: Game may glitch or crash if
;   this is an invalid address.
; -- ^The subroutine is called with the following information:
; --- Y register: Current index of a sprite colliding with.
; --- $8A: Type of Sprite:
; ---- $00 = Main sprite
; ---- $01 = Bob-omb explosion
; ---- $02 = Extended
; ---- $03 = Bounce block
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?HandleSpriteCollisions:
	?.MainSprites
		LDY.b #!sprite_slots-1
		?..Loop
			TYA
			CMP $15E9|!Base2
			BNE ?...NotSelf
			
			?...IsSelf
				JMP ?...Next
			
			?...NotSelf
			LDA !14C8,y		;>Sprite state
			CMP #$08		;\No interaction on non-existent sprite and any form of death sprite.
			BCC ?...DeadOrDying	;|
			CMP #$0B		;|
			BCS ?...DeadOrDying	;/
			BRA ?...ValidStates
			
			?...DeadOrDying
				JMP ?...Next
			
			?...ValidStates
				?....BobOmbExplosionCheck
					LDA !9E,y
					CMP #$0D				;\Other than bob-omb
					BNE ?....NonExplosionSprites		;/
					LDA !7FAB10,y				;\Is custom sprite
					BIT.b #%00001000			;|
					BNE ?....NonExplosionSprites		;/
					LDA !1534,y				;\Is exploding
					BNE ?....ExplosionSprite		;/
				?....ExplodePrematurely
					LDA !14C8,y
					CMP #$08
					BNE ?+
					JMP ?...Next
					?+
					;If hit directly with a Bob-omb before it exploded, make it explode immediately
					JSR ?CarryableKickedClipB
					JSL $03B72B|!bank			;>Check for contact
					BCS ?+
					JMP ?...Next
					?+
					LDA #$01				;\Explode early
					STA !1534,y				;|
					LDA #$40				;|
					STA !1540,y				;/>Explosion timer
					LDA #$08				;\Make it a normal routine
					STA !14C8,y				;/
					JMP ?...Next				
				?....ExplosionSprite
					JSR ?BobOmbExplosionClippingB
					JSL $03B72B|!bank
					BCS ?+
					JMP ?...Next
					?+
					?.....ExplosionContact
						LDA #$01
						STA $8A
						JSL ?ExecuteCallBack
						BRA ?...Next
				?....NonExplosionSprites
					JSR ?CarryableKickedClipB
					JSL $03B72B|!bank
					BCC ?...Next
					STZ $8A
					JSL ?ExecuteCallBack
			?...Next
				DEY
				BPL ?..Loop
	?.ExtendedSprites
		LDY.b #10-1
		?..Loop
			LDA $170B|!Base2,y	;>Extended sprite number
			BEQ ?...Next
			CMP #$05			;\Player's fireball
			BEQ ?...Fireball		;/
			CMP #$11			;\Yoshi's fireball after eating
			BEQ ?...Fireball		;/a red shell
			BRA ?...NextSlot		;>Others = next
		
			?...Fireball
				JSR ?ExtSprFireballClipB
				JSL $03B72B|!bank
				BCC ?...Next
			?...Contact
				LDA #$02
				STA $8A
				JSL ?ExecuteCallBack
			?...Next
				DEY
				BPL ?..Loop
	RTL
	?ExecuteCallBack:
		JMP [$8D]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?CarryableKickedClipB:
;Gets the clipping of most "16x16" (actually 14x14?) carryable/kicked sprites
	LDA !14E0,y	;\High byte x pos
	XBA		;/
	LDA !E4,y	;>low byte x pos (LDA $xx,y does not exist).
	REP #$20	;\Add by #$0002 towards the right
	CLC		;|
	ADC #$0002	;|
	SEP #$20	;/
	STA $00		;>Store to low byte x position hitbox B
	XBA		;\Same for high byte
	STA $08		;/

	LDA !14D4,y	;\High byte y pos
	XBA		;/
	LDA !D8,y	;>low byte y pos (LDA $xx,y does not exist).
	REP #$20	;\Add by #$0002 downwards
	CLC		;|
	ADC #$0002	;|
	SEP #$20	;/
	STA $01		;>Store that to y position hitbox B
	XBA		;\Same for high byte
	STA $09		;/

	LDA #$0E	;\#$0E by #$0E (14x14) hitbox
	STA $02		;|
	STA $03		;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?BobOmbExplosionClippingB:
	LDA !E4,y					;\Sprite is 16x16, and our current position is the top-left of that.
	CLC						;|We need to go 8 pixels to the right and 8 down to locate the center
	ADC #$08					;|of that sprite.
	STA $00						;|
	LDA !14E0,y					;|
	ADC #$00					;|
	STA $08						;|
	LDA !D8,y					;|
	CLC						;|
	ADC #$08					;|
	STA $01						;|
	LDA !14D4,y					;|
	ADC #$00					;|
	STA $09						;/
	LDA.b #!Setting_Bobomb_ExplosionApothem		;\As the "apothem" expands, the width expands twice the value of "apothem"
	ASL						;|
	STA $02						;|
	STA $03						;/
	LDA $00						;\As the box expands from center, the top or left gets moved upwards or leftwards by "apothem"
	SEC						;|
	SBC.b #!Setting_Bobomb_ExplosionApothem		;|
	STA $00						;|
	LDA $08						;|
	SBC #$00					;|
	STA $08						;|
	LDA $01						;|
	SEC						;|
	SBC.b #!Setting_Bobomb_ExplosionApothem		;|
	STA $01						;|
	LDA $09						;|
	SBC #$00					;|
	STA $09						;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?ExtSprFireballClipB:
;Gets the clipping of an extended sprite's hitbox into B.
	LDA $171F|!Base2,y	;\X position
	STA $00			;|
	LDA $1733|!Base2,y	;|
	STA $08			;/
	LDA $1715|!Base2,y	;\Y position
	STA $01			;|
	LDA $1729|!Base2,y	;|
	STA $09			;/

	?.DifferentSize		
		LDA $170B|!Base2,y	;\Determine the shape of hitbox
		CMP #$05		;|depending on its extended sprite number
		BEQ ?..PlayerFireball	;|
		CMP #$11		;|
		BEQ ?..YoshiFireball	;|
		BRA ?.done		;/

	?..PlayerFireball
		LDA #$08
		BRA ?..SetSize

	?..YoshiFireball
		LDA #$10

	?..SetSize
		STA $02
		STA $03

	?.done
		RTS