incsrc "Defines/SA1StuffDefines.asm"
incsrc "Defines/EnemyHPMeterDefines.asm"
incsrc "Defines/GraphicalBarDefines.asm"

;This patch modifies vanilla SMW sprites to utilizes the HP system. What are modified are:
; - Chargin chucks (all variants) when taking stomp damage
; - Any sprite (vanilla or custom) that have the "takes 5 fireballs to kill" tweaker bit set
; - Big Boo Boss
; - Ludwig, Morton, and Roy.

;Macro
	macro ConvertDamageAmountToHP(HitCountSpriteTableRAM, DamageAmountToDie)
		?HitCountToHP:
			LDA.b #<DamageAmountToDie>                                      ;>The amount of damage that would kill the sprite
			STA !Freeram_SpriteHP_MaxHPLow,x                                ;>This also means its maximum health is this value.
			SEC                                                             ;\RemainingHP = DamageAmountToDie - DamageCount
			SBC <HitCountSpriteTableRAM>,x                                  ;/
			BCS ?.NotMoreThanEnoughDamage                                   ;>Failsafe, if DamageCount is greater than DamageAmountToDie, remaining HP cannot go negative, so...
			?.MoreThanEnough
				LDA #$00                                                ;>...Set it to 0.
			?.NotMoreThanEnoughDamage
				STA !Freeram_SpriteHP_CurrentHPLow,x                    ;>otherwise just write the non-negative difference as HP.
			if !Setting_SpriteHP_TwoByte != 0
				LDA #$00                                                ;\Rid high bytes.
				STA !Freeram_SpriteHP_CurrentHPHi,x                     ;|(So far, there is never a sprite that stores a 16-bit damage counter)
				STA !Freeram_SpriteHP_MaxHPHi,x                         ;/
			endif
	endmacro
	
	macro IncreaseDamageCounter(HitCountSpriteTableRAM, DamageAmount, DamageAmountToDie)
		?Damage:
		JSL SwitchHPDisplay
		LDA <HitCountSpriteTableRAM>,x
		CLC
		ADC.b #<DamageAmount>
		BCS ?.Overflow
		CMP.b #<DamageAmountToDie>
		BCC ?.BelowDeathThreshold
		
		?.Overflow
			LDA.b #<DamageAmountToDie>
		?.BelowDeathThreshold
			STA <HitCountSpriteTableRAM>,x
	endmacro
	
	macro IntroFill(IntroStateSpriteTableRAM)
		?HandleIntro:
			if !Setting_SpriteHP_BarAnimation
				LDA <IntroStateSpriteTableRAM>,x
				BNE ?.IntroDone
				INC <IntroStateSpriteTableRAM>,x
				TXA
				CLC
				ADC.b #!sprite_slots
				STA !Freeram_SpriteHP_MeterState
				LDA #$00
				STA !Freeram_SpriteHP_BarAnimationFill,x
				if !Setting_SpriteHP_BarChangeDelay
					STA !Freeram_SpriteHP_BarAnimationTimer,x
				endif
				?.IntroDone
			else
				TXA
				STA !Freeram_SpriteHP_MeterState
			endif
	endmacro

;Hijacks

	;Code that runs every frame for chucks
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C1F8
			autoclean JML CharginChuckHitCountToHP		;>Had to be JML instead JSL because you cannot PHA : RTL [...] PLA.
		else
			if read1($02C1F8) == $5C			;>Check if this instruction is replaced with a JML hijack
				autoclean read3($02C1F8+1)		;>If so, then first remove freespace code...
			endif
			org $02C1F8
			LDA.W !187B,X					;\Then restore the original, overwritten code.
			PHA						;/
		endif
	;Chucks taking a hit from a stomp attack
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C7E8
			autoclean JSL StompCharginChuck
			NOP #2
		else
			if read1($02C7E8) == $22
				autoclean read3($02C7E8+1)
			endif
			org $02C7E8
			INC.W !1528,X
			LDA.W !1528,X
		endif
	;Modify hit count to kill to be the minimum amount of damage to kill
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C7EF
			db !Setting_SpriteHP_VanillaSprite_ChuckHPAmount		;>Amount of total damage to kill for chucks
		else
			org $02C7EF
			db 3
		endif
	;Failsafe to prevent a potential bug where a chuck dies and a new sprite spawn on the same slot the dying/despawning chuck
	;is on causes the HP meter to be transfered over.
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C20C
			autoclean JSL PreventHPDisplayTransferChuck
			nop
		else
			if read1($02C20C) == $22
				autoclean read3($02C20C+1)
			endif
			org $02C20C
			LDA #$28					;\Restore overwritten code
			STA.W !163E,X					;/
		endif
	;Fireball hitcount hijacks. This modifies the 5 fireballs to kill (when tweaker RAM $190F's bit 3; %0000X000 is set)
	;to use a damage count system. Chucks are the only sprites that have the tweaker bit being used for the 5 fireballs
	;system, bosses that (silently) takes damage from fireballs handles these in their sprite code, unlike how chucks
	;take damage from fireballs.
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02A0FC
			autoclean JSL FireballEffect
			NOP #2
		else
			if read1($02A0FC) == $22
				autoclean read3($02A0FC+1)
			endif
			org $02A0FC
			INC.W !1528,X
			LDA.W !1528,X
		endif
		
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02A103
			db !Setting_SpriteHP_VanillaSprite_ChuckHPAmount
		else
			org $02A103
			db 5
		endif
	;Bosses below (only applies to bosses with a HP system, and not bowser)
		;Big boo boss
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $038233				;\When Big boo boss takes damage from
				autoclean JSL DamageBigBooBoss		;|a thrown sprite.
				NOP #1					;|
			else
				if read1($038233) == $22		;|
					autoclean read3($038233+1)	;|
				endif					;|
				org $038233				;|
				LDA #$28				;|
				STA $1DFC|!addr				;/
			endif
			org $03819B										;\Big Boo's hit counter actually increments
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)	;|when switching state, not the instant the
				NOP #3										;|boo gits hit.
			else											;|
				INC.W !1534,X									;|
			endif											;/
		
			org $0381A2										;\Amount of hits to defeat big boo.
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_BigBooBossHPAmount
			else
				db 3
			endif
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $0380A2				;\Big boo's "HP" is actually a hit counter
				autoclean JML BigBooBossHitCountToHP	;|that increments (starts at 0) every hit.
			else
				if read1($0380A2) == $5C		;|This hijacks converts the value to HP,
					autoclean read3($0380A2+1)	;|and makes it display its health.
				endif					;|
				org $0380A2				;|
				CMP #$08				;|
				BNE $2E					;/
			endif
		;Wendy and Lemmy
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $03CECB
				autoclean JSL DamageWendyLemmy
				NOP #1
			else
				if read1($03CECB) == $22
					autoclean read3($03CECB+1)
				endif
				org $03CECB
				LDA #$28
				STA $1DFC|!addr
			endif
		
			org $03CE13
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3					;>Remove delay damage (HP value only decreases when going back into pope after entering)
			else
				INC.W !1534,X
			endif
			
			org $03CE1A
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmyHPAmount			;>Wendy/Lemmy's HP.
			else
				db $03
			endif
			
			org $03CED4
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmyHPAmount			;>Number of hits (no longer -1) to make sprites vanish
			else
				db $02
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $03CC14
				autoclean JSL WendyLemmyHitCountToHP
				NOP #2
			else
				if read1($03CC14) == $22
					autoclean read3($03CC14+1)
				endif
				org $03CC14
				JSR.W $03D484
				LDA !14C8,X
			endif
		;Ludwig, Morton, and Roy
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01D3F3
				autoclean JSL FireballDamageLudwigMortonRoy	;>Fireball damage
				NOP #4 ;>This prevents incrementing hit counter past its maximum to prevent displaying negative HP
			else
				if read1($01D3F3) == $22
					autoclean read3($01D3F3+1)
				endif
				org $01D3F3
				LDA #$01
				STA $1DF9|!addr
				INC.W !1626,X
			endif
		
			org $01CFC6
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3						;>Remove delay damage (stomp)
			else
				INC.W !1626,X
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01CFCD
				db !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount			;>Set HP value
		
				org $01D3FF
				db !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount			;>Same as above, but fireball.
			else
				org $01CFCD
				db 3						;>Set HP value
		
				org $01D3FF
				db 12						;>Same as above, but fireball.
			endif
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01CDAB
				autoclean JSL LudwigMortonRoyHitCountToHP	;>Convert HP
				NOP #2
			else
				if read1($01CDAB) == $22
					autoclean read3($01CDAB+1)
				endif
				org $01CDAB
				STZ.W $13FB|!addr
				LDA.W !1602,X
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01D3AB
				autoclean JSL StompDamageLudwigMortonRoy	;>Stomp damage.
			else
				if read1($01D3AB) == $22
					autoclean read3($01D3AB+1)
				endif
				org $01D3AB
				LDA #$28
				STA $1DFC|!addr
			endif
;Freespace code
	freecode
	if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
		CharginChuckHitCountToHP:	;>JML from $02C1F8
			LDA !14C8,x
			CMP #$02
			BCC .Restore		;>Do nothing if $00~$01
			CMP #$07
			BCC .ZeroHP		;>No HP on killed states $02~$06
			CMP #$0C
			BCC .ConvertHitCountToHP	;>Other non-killed/transformed states, allow HP display
			BRA .Restore
			
			.ZeroHP
				LDA.b #!Setting_SpriteHP_VanillaSprite_ChuckHPAmount
				STA !1528,x
			.ConvertHitCountToHP
				%ConvertDamageAmountToHP(!1528, !Setting_SpriteHP_VanillaSprite_ChuckHPAmount)
				
				if !Setting_SpriteHP_BarAnimation
					JSL GetHPMeterSlotIndexNumber
					TXA
					CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
					BEQ ..OnCurrentSprite
					if !Setting_SpriteHP_BarFillRoundDirection == 0
						JSL RemoveRecord
					elseif !Setting_SpriteHP_BarFillRoundDirection == 1
						JSL RemoveRecordRoundDown
					elseif !Setting_SpriteHP_BarFillRoundDirection == 2
						JSL RemoveRecordRoundUP
					endif
					if !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 1
						JSL RoundAwayEmpty
					elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 2
						JSL RoundAwayFull
					elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 3
						JSL RoundAwayEmptyFull
					endif
					LDA $00
					STA !Freeram_SpriteHP_BarAnimationFill,x
					..OnCurrentSprite
				endif
			
			.Restore
				LDA !187B,x
				PHA
				JML $02C1FC|!bank		;>Again, PHA : RTL : PLA crashes the game because RTL pulls stack.
		StompCharginChuck:	;>JSL from $02C7E8
			%IncreaseDamageCounter(!1528, !Setting_SpriteHP_VanillaSprite_Chuck_StompDamage, !Setting_SpriteHP_VanillaSprite_ChuckHPAmount)
			RTL
		PreventHPDisplayTransferChuck:
			.Restore
				LDA #$28
				STA !163E,x
			.HideDisplay
				LDA !14C8,x
				BNE ..NotDead
				LDA #$FF
				STA !Freeram_SpriteHP_MeterState
				
				..NotDead
			RTL
		FireballEffect:	;>JSL from $02A0FC
			%IncreaseDamageCounter(!1528, !Setting_SpriteHP_FireballDamageAmount, !Setting_SpriteHP_VanillaSprite_ChuckHPAmount)
			if !Setting_SpriteHP_VanillaSprite_ChuckFireDamage_SoundNumber != $00
				LDA.b #!Setting_SpriteHP_VanillaSprite_ChuckFireDamage_SoundNumber
				STA !Setting_SpriteHP_VanillaSprite_ChuckFireDamage_SoundPort
				.Restore
					LDA !1528,x
			endif
			RTL
	endif
		
	if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
		DamageBigBooBoss:
			%IncreaseDamageCounter(!1534, !Setting_SpriteHP_VanillaSprite_BigBooBossThrownItemDamage, !Setting_SpriteHP_VanillaSprite_BigBooBossHPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
		BigBooBossHitCountToHP:
			%ConvertDamageAmountToHP(!1534, !Setting_SpriteHP_VanillaSprite_BigBooBossHPAmount)
			%IntroFill(!1594)
			.Restore
				LDA !14C8,x
				CMP #$08
				BNE ..Return0380D4
				JML $0380A6|!bank
				..Return0380D4
					JML $0380D4|!bank
		DamageWendyLemmy:
			%IncreaseDamageCounter(!1534, !Setting_SpriteHP_VanillaSprite_WendyLemmyStompDamage, !Setting_SpriteHP_VanillaSprite_WendyLemmyHPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
		WendyLemmyHitCountToHP:
			%ConvertDamageAmountToHP(!1534, !Setting_SpriteHP_VanillaSprite_WendyLemmyHPAmount)
			.HandleIntroFill
				if !Setting_SpriteHP_BarAnimation
					;%IntroFill(!1FD6) ;>This does not work because Wendy/Lemmy actually delete themselves (or simply reset almost all their sprite tables) each time they go back in the pipe.
					LDA !Freeram_WendyLemmyIntroFlag
					CMP #$25
					BNE ..NoIntroFill
					LDA #$00
					STA !Freeram_WendyLemmyIntroFlag
					TXA
					CLC
					ADC.b #!sprite_slots
					STA !Freeram_SpriteHP_MeterState
					LDA #$00
					STA !Freeram_SpriteHP_BarAnimationFill,x
					if !Setting_SpriteHP_BarChangeDelay
						STA !Freeram_SpriteHP_BarAnimationTimer,x
					endif
					..NoIntroFill
				else
					;%IntroFill(!1FD6) ;>This does not work because Wendy/Lemmy actually delete themselves (or simply reset almost all their sprite tables) each time they go back in the pipe.
					LDA !Freeram_WendyLemmyIntroFlag
					CMP #$25
					BNE ..NoIntroFill
					LDA #$00
					STA !Freeram_WendyLemmyIntroFlag
					TXA
					STA !Freeram_SpriteHP_MeterState
					
					..NoIntroFill
				endif
			.Restore
				PHK				;\JSL-RTS trick.
				PER $0006
				PEA $827E
				JML $03D484|!bank		;>Graphics routines, had to do the JSL-RTS trick because freespace code may be in different banks.
				LDA !14C8,x
			RTL
		FireballDamageLudwigMortonRoy:
			;Thankfully, there is no delay damage for fireball damage, since the developers
			;programmed damage that makes the boss "flinch" or "stun" would apply damage AFTER
			;the boss "un-stun" itself.
			%IncreaseDamageCounter(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyFireballDamage, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount)
			if !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyDamage_SoundNumber != $00
				LDA.b #!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyDamage_SoundNumber	;\SFX
				STA !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyDamage_SoundPort		;/
			endif
			RTL
		LudwigMortonRoyHitCountToHP:
			%ConvertDamageAmountToHP(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount)
			%IntroFill(!1510)
			.Restore
				STZ $13FB|!addr
				LDA !1602,x
				RTL
		StompDamageLudwigMortonRoy:
			%IncreaseDamageCounter(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyStompDamage, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
	endif
;Various subroutines below
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;This essentially takes the value of !Freeram_SpriteHP_MeterState, and modulo by
	;!sprite_slots, which can be used to detect if what sprite slot index number the meter is
	;on is on the same slot number as the currently processed sprite.
	;
	;Output:
	; - !Scratchram_SpriteHP_SpriteSlotToDisplay: Sprite slot index number
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	GetHPMeterSlotIndexNumber:
		LDA #$FF
		CMP !Freeram_SpriteHP_MeterState
		BEQ .NonIntroFillMode
		LDA !Freeram_SpriteHP_MeterState
		CMP.b #!sprite_slots
		BCC .NonIntroFillMode
		.IntroFillMode
			SEC
			SBC.b #!sprite_slots
		.NonIntroFillMode
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL
		
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Switch HP display
	;Input:
	; - X: current sprite slot
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	SwitchHPDisplay:
		TXA
		STA !Freeram_SpriteHP_MeterState
		if and(!Setting_SpriteHP_BarAnimation, notequal(!Setting_SpriteHP_BarChangeDelay, 0))
			LDA.b #!Setting_SpriteHP_BarChangeDelay
			STA !Freeram_SpriteHP_BarAnimationTimer,x
		endif
		RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Remove record effect, lesser-RAM-based and shorter edition
	;
	;Unlike the provicded custom sprite, which calls a subroutine
	;("%SpriteHP_RemoveRecordEffect()") to figure out the amount of fill in the bar of its
	;current HP for $00 to set !Freeram_SpriteHP_BarAnimationFill, this uses precalculated
	;total pieces in the bar to reduce code duplicates in both this patch and pixi routines.
	;These aformentioned subroutines have lots of dependencies with other grapical bar
	;routines and other math routines.
	;
	;This is at the cost of certain customizability, such as variable-length bar that allows
	;dynamic calculations with variable bar in-game.
	;
	;Input:
	; - X = Current sprite slot
	; - !Freeram_SpriteHP_MaxHPLow = sprite current HP (for display)
	;Output:
	; - $00~$01: Amount of fill in the bar at the sprite's current HP
	; - Y: $00 if not rounded to empty or full, $01 if rounded to empty, $02 if rounded to
	;   full.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	if !Setting_SpriteHP_BarFillRoundDirection == 0
		RemoveRecord:
			LDA !Freeram_SpriteHP_MaxHPLow,x
			STA !Scratchram_GraphicalBar_FillByteTbl+2
			LDA #$00
			STA !Scratchram_GraphicalBar_FillByteTbl+3
			JSL RemoveRecordRoundDown
				; - $00~$03: Amount of fill in the bar (rounded down)
				; - $04~$05: Remainder ranging from 0 to MaxHeath-1 to be used for rounding
				; - Y: Round to zero flag: $00 = no $01 = yes.
			REP #$20
			LDA !Scratchram_GraphicalBar_FillByteTbl
			LSR
			BCC .ExactHalf
				;^Reason 1/2 point must be rounded up, is so to truly check if remainder is greater or equal to half of MaxQuantity, to round the pieces filled up,
				; when MaxQuantity is odd. e.g. 1 Quantity * 62 pieces / 5 MaxQuantity = Q:12 R:2, which is 12 and 2/5, or 12.4. The 1/2 point of 5 is EXACTLY 2.5,
				; not 2 (LSR divides A by 2 and round down, thus resulting 2). This means that the lowest remainder integer to trigger a round-up of the amount of
				; pieces filled would be 3.
			INC
			.ExactHalf
				CMP $04						;>Half of denominator compares with remainder
				BEQ .RoundQuotient				;>Half equal remainder, round up
				BCS .NoRoundQuotient				;>Half greater than remainder (remainder being smaller), keep the already-floored quotient as is
				
				.RoundQuotient
				LDA $00						;\Round up an integer
				INC						;/
				STA $08						;>move towards $08 because 16bit*16bit multiplication uses $00 to $07
				
			.RoundToFullCheck
				LDA.w #!Setting_SpriteHP_GraphicalBar_TotalPieces	;>Amount of pieces in the bar
				LDY #$00
				CMP $08							;>Compare with quotient (rounded)
				BNE ..FillAmountTransferBack
				LDY #$02						;>Rounded up fill equals maximum fill, which means it rounded up to maxpieces
				
				..FillAmountTransferBack
					LDA $08
					STA $00
					BRA .Done
			.NoRoundQuotient
				LDY #$00					;>Default that the meter didn't round towards empty/full.
				LDA $00						;\if the rounded down (result from fraction part is less than .5) quotient value ISN't zero,
				BNE .Done					;/(exactly 1 piece filled or more) don't even consider setting Y to #$01.
				LDA $04						;\if BOTH rounded down quotient and the remainder are zero, the bar is TRUELY completely empty
				BEQ .Done					;/and don't set Y to #$01.
				
				LDY #$01					;>indicate that the value was rounded down towards empty
				
				.Done
				SEP #$20
			RTL
	endif
	RemoveRecordRoundDown:
		;Output:
		; - $00~$03: Amount of fill in the bar (rounded down)
		; - $04~$05: Remainder ranging from 0 to MaxHeath-1 to be used for rounding
		; - Y: Round to zero flag: $00 = nom $01 = yes.
		LDA !Freeram_SpriteHP_CurrentHPLow,x
		STA $00
		LDA #$00
		STA $01
		REP #$20
		LDA.w #!Setting_SpriteHP_GraphicalBar_TotalPieces
		STA $02
		SEP #$20
		JSL MathMul16_16				;>CurrentHP * TotalPiecesInBar...
		REP #$20
		LDA $04
		STA $00
		LDA $06
		STA $02
		LDA !Freeram_SpriteHP_MaxHPLow,x
		STA $04
		if !Setting_SpriteHP_TwoByte
			LDA !Freeram_SpriteHP_MaxHPHi,x
			STA $05
		else
			STZ $05
		endif
		SEP #$20
		JSL MathDiv32_16				;>Divided by Max HP. Quotient (at the moment): Fill amount (rounded down), Remainder: A value from 0 to MaxHeath-1 to determine a rounding operation
		REP #$20
		LDY #$00
		LDA $00
		ORA $02
		BNE .NotRoundedToZero
		LDA $04
		BEQ .NotRoundedToZero
		
		.RoundedToZero
			LDY #$01
		.NotRoundedToZero
		SEP #$20
		RTL
	if !Setting_SpriteHP_BarFillRoundDirection == 2
		RemoveRecordRoundUP
			JSL RemoveRecordRoundDown
			REP #$20
			LDA $04				;\If remainder is zero, (meaning exactly an integer), don't increment
			BEQ .NoRoundUp			;/
			.RoundUp
				LDY #$00
				INC $00							;>Otherwise if there is a remainder (between Quotient and Quotient+1), use Quotient+1
				LDA.w #!Setting_SpriteHP_GraphicalBar_TotalPieces
				CMP $00
				BNE .NoRoundToMax					;>If fill at max, after rounding, flag it as rounded to max.
				LDY #$02
			.NoRoundToMax
			.NoRoundUp
			SEP #$20
			RTL
	endif

	;Math routines
		if !sa1 == 0
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; 16bit * 16bit unsigned Multiplication
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; Argusment
			; $00-$01 : Multiplicand
			; $02-$03 : Multiplier
			; Return values
			; $04-$07 : Product
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			MathMul16_16:	REP #$20
					LDY $00
					STY $4202
					LDY $02
					STY $4203
					STZ $06
					LDY $03
					LDA $4216
					STY $4203
					STA $04
					LDA $05
					REP #$11
					ADC $4216
					LDY $01
					STY $4202
					SEP #$10
					CLC
					LDY $03
					ADC $4216
					STY $4203
					STA $05
					LDA $06
					CLC
					ADC $4216
					STA $06
					SEP #$20
					RTL
		else
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; 16bit * 16bit unsigned Multiplication SA-1 version
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; Argusment
			; $00-$01 : Multiplicand
			; $02-$03 : Multiplier
			; Return values
			; $04-$07 : Product
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
			MathMul16_16:	STZ $2250
					REP #$20
					LDA $00
					STA $2251
					ASL A
					LDA $02
					STA $2253
					BCS +
					LDA.w #$0000
			+		BIT $02
					BPL +
					CLC
					ADC $00
			+		CLC
					ADC $2308
					STA $06
					LDA $2306
					STA $04
					SEP #$20
					RTL
		endif
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; Unsigned 32bit / 16bit Division
		; By Akaginite (ID:8691), fixed the overflow
		; bitshift by GreenHammerBro (ID:18802)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; Arguments
		; $00-$03 : Dividend
		; $04-$05 : Divisor
		; Return values
		; $00-$03 : Quotient
		; $04-$05 : Remainder
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
		MathDiv32_16:	REP #$20
				ASL $00
				ROL $02
				LDY #$1F
				LDA.w #$0000
		-		ROL A
				BCS +
				CMP $04
				BCC ++
		+		SBC $04
				SEC
		++		ROL $00
				ROL $02
				DEY
				BPL -
				STA $04
				SEP #$20
				RTL
	;Rounding
		RoundAwayEmpty:
			CPY #$01
			BNE .No
			.AwayFromZero
				INC $00
			.No
			RTL
		RoundAwayFull:
			CPY #$02
			BNE .No
			.AwayFromFull
				DEC $00
			.No
			RTL
		RoundAwayEmptyFull:
			CPY #$01
			BEQ RoundAwayEmpty_AwayFromZero
			CPY #$02
			BEQ RoundAwayFull_AwayFromFull
			RTL