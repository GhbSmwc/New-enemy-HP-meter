incsrc "Defines/SubroutineDefs.asm"
incsrc "Defines/SA1StuffDefines.asm"
incsrc "Defines/EnemyHPMeterDefines.asm"
incsrc "Defines/GraphicalBarDefines.asm"

;This patch modifies vanilla SMW sprites to utilizes the HP system. What are modified are:
; - Chargin chucks (all variants) when taking stomp damage
; - Any sprite (vanilla or custom) that have the "takes 5 fireballs to kill" tweaker bit set
; - Big Boo Boss
; - Wendy, Lemmy, Ludwig, Morton, and Roy.

;Macro
	macro ConvertDamageAmountToHP(DamageCountSpriteTableRAM, DamageAmountToDie)
		?HitCountToHP:
			if !Setting_SpriteHP_NoDisplaySMWSpriteHP == 0
				LDA.b #<DamageAmountToDie>                                      ;>The amount of damage that would kill the sprite
				STA !Freeram_SpriteHP_MaxHPLow,x                                ;>This also means its maximum health is this value.
				SEC                                                             ;\RemainingHP = DamageAmountToDie - DamageCount
				SBC <DamageCountSpriteTableRAM>,x                                  ;/
				BCS ?.NotMoreThanEnoughDamage                                   ;>Failsafe, if DamageCount is greater than DamageAmountToDie, remaining HP cannot go negative, so...
				?.MoreThanEnough
					LDA #$00                                                ;>...Set it to 0.
				?.NotMoreThanEnoughDamage
					STA !Freeram_SpriteHP_CurrentHPLow,x                    ;>otherwise just write the non-negative difference as HP.
				if !Setting_SpriteHP_TwoByte
					LDA #$00                                                ;\Rid high bytes.
					STA !Freeram_SpriteHP_CurrentHPHi,x                     ;|(So far, there is never a sprite that stores a 16-bit damage counter)
					STA !Freeram_SpriteHP_MaxHPHi,x                         ;/
				endif
			endif
	endmacro
	
	macro IncreaseDamageCounter(DamageCountSpriteTableRAM, DamageAmount, DamageAmountToDie)
		?Damage:
		if !Setting_SpriteHP_NoDisplaySMWSpriteHP == 0
			if !Setting_SpriteHP_TwoByte
				REP #$20
				LDA.w #<DamageAmount>
				STA $00
				SEP #$20
			else
				LDA.b #<DamageAmount>
				STA $00
			endif
			JSL !SharedSub_SpriteHPDamage
		endif
		LDA <DamageCountSpriteTableRAM>,x
		CLC
		ADC.b #<DamageAmount>
		BCS ?.Overflow
		CMP.b #<DamageAmountToDie>
		BCC ?.BelowDeathThreshold
		
		?.Overflow
			LDA.b #<DamageAmountToDie>
		?.BelowDeathThreshold
			STA <DamageCountSpriteTableRAM>,x
	endmacro
	
	macro IntroFill(IntroStateSpriteTableRAM)
		?HandleIntro:
			if !Setting_SpriteHP_NoDisplaySMWSpriteHP == 0
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
				NOP #3					;>Remove delay damage (HP value only decreases when going back into pipe after entering)
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
		CharginChuckHitCountToHP:	;>JML from $02C1F8 (runs every frame)
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
					JSL !SharedSub_SpriteHPGetSlotIndex
					TXA
					CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
					BEQ ..OnCurrentSprite
					JSL !SharedSub_SpriteHPRemoveRecordEffect
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
				if !Setting_SpriteHP_NoDisplaySMWSpriteHP == 0
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