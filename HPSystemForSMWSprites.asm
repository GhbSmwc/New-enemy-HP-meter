incsrc "Defines/SharedSubroutineDefs.asm"
incsrc "Defines/SA1StuffDefines.asm"
incsrc "Defines/EnemyHPMeterDefines.asm"
incsrc "Defines/GraphicalBarDefines.asm"

;This patch modifies vanilla SMW sprites to utilizes the HP system. What are modified are:
; - Chargin chucks (all variants) when taking stomp damage
; - Any sprite (vanilla or custom) that have the "takes 5 fireballs to kill" tweaker bit set
; - Big Boo Boss
; - Wendy, Lemmy, Ludwig, Morton, and Roy.
; - Rex.
;For all 1-shot enemies, this is enabled by having both !Setting_SpriteHP_VanillaSprite_OneShotSprites
;and !Setting_SpriteHP_DisplayHPOfSMWSprites set to 1.

;Macros
	macro RemoveFreespaceCodeFromJMLJSL(Addr)
		;Addr is the address of the instruction byte itself.
		if or(equal(read1(<Addr>), $22), equal(read1(<Addr>), $5C)) ;If instruction is JSL/JML
			autoclean read3(<Addr>+1)
		endif
	endmacro
	macro ConvertDamageAmountToHP(DamageCountSpriteTableRAM, DamageAmountToDie)
		?HitCountToHP:
			if !Setting_SpriteHP_DisplayHPOfSMWSprites
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
		if !Setting_SpriteHP_DisplayHPOfSMWSprites
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
		ADC.b #<DamageAmount>			;
		BCS ?.Overflow				;>If exceeding 255...
		CMP.b #<DamageAmountToDie>
		BCC ?.BelowDeathThreshold		;>...Or if exceeding the minimum damage amount to kill, then cap the damage counter
		
		?.Overflow
			LDA.b #<DamageAmountToDie>
		?.BelowDeathThreshold
			STA <DamageCountSpriteTableRAM>,x
	endmacro
	
	macro IntroFill(IntroStateSpriteTableRAM)
		?HandleIntro:
			if !Setting_SpriteHP_DisplayHPOfSMWSprites
				if !Setting_SpriteHP_BarAnimation
					LDA <IntroStateSpriteTableRAM>,x
					BNE ?.IntroDone
					INC <IntroStateSpriteTableRAM>,x
					TXA
					CLC
					ADC.b #!sprite_slots
					STA !Freeram_SpriteHP_MeterState
					LDA #$00
					STA !Freeram_SpriteHP_BarAnimationFill
					if !Setting_SpriteHP_BarChangeDelay
						STA !Freeram_SpriteHP_BarAnimationTimer
					endif
					?.IntroDone
				else
					TXA
					STA !Freeram_SpriteHP_MeterState
				endif
			endif
	endmacro
	macro SetSpriteDefaultHP(SpriteNumb, StartingHP)
		CMP.b #<SpriteNumb>
		BNE ?OtherSprite
		?Override
			LDA.b #<StartingHP>
			STA !Freeram_SpriteHP_CurrentHPLow,x
			STA !Freeram_SpriteHP_MaxHPLow,x
			if !Setting_SpriteHP_TwoByte
				LDA.b #<StartingHP>>>8
				STA !Freeram_SpriteHP_CurrentHPHi,x
				STA !Freeram_SpriteHP_MaxHPHi,x
			endif
			RTL
		?OtherSprite:
	endmacro
	macro HijacksForFallingOffScrn(Addr_Hijack, Label_ToFreespace, String_IndexToUse)
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org <Addr_Hijack>
			autoclean JSL <Label_ToFreespace>
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL(<Addr_Hijack>)
			org <Addr_Hijack>
			LDA.b #$02
			STA !14C8,<String_IndexToUse>
		endif
	endmacro
	macro SpriteHPMeterBlacklist(SpriteNumb)
		CMP.b #<SpriteNumb>
		BEQ .Done
	endmacro
	macro SpriteHPMeterBlacklist_UnlimitedDistance(SpriteNumb)
		CMP.b #<SpriteNumb>
		BNE ?+
		RTS
		?+
	endmacro
	macro SpriteHPMeterBlacklist_Range(SpriteNumbMin, SpriteNumbMax)
		CMP.b #<SpriteNumbMin>
		BCC ?OutOfBlacklistedRange
		CMP.b #<SpriteNumbMax>+1
		BCS ?OutOfBlacklistedRange
		
		?InBlacklistedRange:
		RTS
		
		?OutOfBlacklistedRange:
	endmacro
;Hijacks
	;Chucks
		;Code that runs every frame. Ensures the HP values in the new sprite RAM is in sync (for display).
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Chuck)
				org $02C1F8
				autoclean JML CharginChuckHitCountToHP		;>Had to be JML instead JSL because you cannot PHA : RTL [...] PLA.
			else
				%RemoveFreespaceCodeFromJMLJSL($02C1F8)
				org $02C1F8
				LDA.W !187B,X					;\Then restore the original, overwritten code.
				PHA						;/
			endif
		;Taking a hit from a stomp attack. This is also part of the Chuck's HP jank fix.
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
				org $02C7E8
				autoclean JSL StompCharginChuck
				NOP #2
			else
				%RemoveFreespaceCodeFromJMLJSL($02C7E8)
				org $02C7E8
				INC.W !1528,X
				LDA.W !1528,X
			endif
		;Modify hit count to kill to be the minimum amount of damage to kill (stomping)
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
				org $02C7EF
				db !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount		;>Amount of total damage to kill for chucks
			else
				org $02C7EF
				db 3
			endif
		;Failsafe to prevent a potential bug where a chuck dies and a new sprite spawn on the same slot the dying/despawning chuck
		;is on causes the HP meter to be transfered over.
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
				org $02C20C
				autoclean JSL PreventHPDisplayTransferChuck
				nop
			else
				%RemoveFreespaceCodeFromJMLJSL($02C20C)
				org $02C20C
				LDA #$28					;\Restore overwritten code
				STA.W !163E,X					;/
			endif
	;Fireball hitcount hijacks. This modifies the 5 fireballs to kill (when tweaker RAM $190F's bit 3; %0000X000 is set)
	;to use a damage count system. Chucks are the only sprites that have the tweaker bit being used for the 5 fireballs
	;system, bosses that (silently) takes damage from fireballs handles these in their sprite code, unlike how chucks
	;take damage from fireballs. This also part of the Chuck's HP jank fix.
		if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02A0FC
			autoclean JSL FireballEffect
			NOP #2
		else
			%RemoveFreespaceCodeFromJMLJSL($02A0FC)
			org $02A0FC
			INC.W !1528,X
			LDA.W !1528,X
		endif
		
		if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02A103
			db !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ;>This modifies the Fireball hit counter to be the minimum amount of damage to kill
		else
			org $02A103
			db 5
		endif
	;Rex to display HP
		;This code runs every frame, for this reason: when rex gets insta-killed by, fireballs, quake, etc.
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Rex)
				org $03951A
				autoclean JSL RexStateToHP
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($03951A)
				org $03951A
				LDA !14C8,x
				CMP #$08
			endif
		;Handle rex getting stomped
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Rex)
				org $0395B3
				JSL StompRex
			else
				%RemoveFreespaceCodeFromJMLJSL($0395B3)
				org $0395B3
				INC !C2,x
				LDA !C2,x
			endif
	;Modify how much HP rex has (stomps only). Determines at what counter the Rex will be killed
		if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Rex)
			org $0395B7
			CMP.b #!Setting_SpriteHP_VanillaSprite_Rex_HPAmount
		else
			org $0395B7
			CMP #$02
		endif
	;Modify spinjump kills to display HP when spinjump/yoshi stomp killed (Rex, for example, can be non-fatally damaged, or insta-killed)
		;Most sprites
			if !Setting_ModifySprAndDisplayHPOfSMWSpr
				org $01A93F
				autoclean JSL SpinKillDisplayHP
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($01A93F)
				org $01A93F
				LDA #$08
				STA $1DF9|!addr
			endif
		;Rex
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Rex)
				org $0395EC
				autoclean JSL SpinKillDisplayHP
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($0395EC)
				org $0395EC
				LDA #$08
				STA $1DF9|!addr
			endif
	;Same as above but when stomping enemies regularly (flatten).
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01A9D3
			autoclean JSL StompKill
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01A9D3)
			org $01A9D3
			LDA #$03
			STA !14C8,x
		endif
	;When sprites are falling down screen
	; - kicked/carried sprites hit a 1-shottable enemy
	; - Stomped (e.g. Monty Mole) and falling down the screen
	; - Stunned sprites kicked automatically by player (stunned koopas (except blue) and fish)
	; - Killed via Sliding down a slope or via star power
	;
	;The following hijacks a 5-byte area being:
	;  Addr+0  LDA.b #$02
	;  Addr+2  STA $14C8,x (or STA $14C8,y)
	;
	;NOTE: If your custom sprites uses a vanilla death routine and you don't want a health meter
	;for those sprites, see "ZeroOutHPOfOneShotSprites:" (without quotes and including the colon)
	;on this ASM file.
	
		%HijacksForFallingOffScrn($01A5E3, ShowHPForFallingOffScrnYregister, y)
		%HijacksForFallingOffScrn($01A66B, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A68F, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A6AC, ShowHPForFallingOffScrnYregister, y)
		%HijacksForFallingOffScrn($01A86B, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A9E9, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01B140, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($02945B, ShowHPForFallingOffScrnCapeSpinQuakeNetPunch, x)
		%HijacksForFallingOffScrn($02F29D, ShowHPForFallingOffScrn, x)
	;Make Amazing Hammer bro platform when bonked by player to show HP
		%HijacksForFallingOffScrn($02DBFD, ShowHPForFallingOffScrnYregister, y)
	;Hijack the clear-sprite tables routine (when sprite spawns) to default sprites with a
	;certain amount of HP (most of them to have 1/1 HP). This is needed so that sprites not
	;have 0 HP and not be a zombie-like state (makes the HUD actually say the sprite
	;previously have full HP).
	;
	;Note to self:
	; - $07F722-$07F78A (105 bytes): The entire routine that clears sprite tables:
	; -- $07F779-$07F77E (6 bytes): Hijacked by this patch so all other sprites will have default 1 HP.
	; -- $07F77F-$07F784 (6 bytes): Hijacked by "Takes 5 fireballs to kill" Work-around Patch.
	; -- $07F785-$07F78A (5 bytes): Hijacked by Pixi.
	; - This entire routine runs AFTER its sprite numbers ($9E/$7FAB9E) have been set, and before its
	;   init code runs. Thus I can set HP values differently based on sprite number, as well as the
	;   sprite's init to set HP would override this.
		if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $07F779
			autoclean JSL DefaultHPOnSpawn
			NOP #2
		else
			%RemoveFreespaceCodeFromJMLJSL($07F779)
			org $07F779
			STZ.w !160E,x
			STZ.w !1594,x
		endif
	;Make stomping on Dino Rhino to transform into Dino Torch to show HP going from 2 to 1 HP
	;(Yeah, this code, is in the *general Mario interaction routine* rather than in Dino Rhino's
	;code, unlike Rex when getting spin jumped. Why Nintendo? Why have sprite-specific interactions
	;programmed in a general sprite interaction code?).
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01A981
			autoclean JSL DinoRhino2HPToTorch1HP
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01A981)
			org $01A981
			LDA #$FF
			STA !1540,x
		endif
	;Bosses below (only applies to bosses with a HP system, and not bowser)
		;Big boo boss
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $038233				;\When Big boo boss takes damage from
				autoclean JSL DamageBigBooBoss		;|a thrown sprite.
				NOP #1					;|
			else
				%RemoveFreespaceCodeFromJMLJSL($038233)
				org $038233				;|
				LDA #$28				;|
				STA $1DFC|!addr				;/
			endif
			org $03819B										;\Big Boo's hit counter actually increments
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)		;|when switching state, not the instant the
				NOP #3										;|boo gits hit.
			else											;|
				INC.W !1534,X									;|
			endif											;/
		
			org $0381A2										;\Amount of hits to defeat big boo.
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount
			else
				db 3
			endif
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $0380A2				;\Big boo's "HP" is actually a hit counter
				autoclean JML BigBooBossHitCountToHP	;|that increments (starts at 0) every hit.
			else
				%RemoveFreespaceCodeFromJMLJSL($0380A2)
				org $0380A2				;|This hijacks converts the value to HP,
				CMP #$08				;|and makes it display its health.
				BNE $2E					;/
			endif
		;Wendy and Lemmy
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $03CECB
				autoclean JSL DamageWendyLemmy
				NOP #1
			else
				%RemoveFreespaceCodeFromJMLJSL($03CECB)
				org $03CECB
				LDA #$28
				STA $1DFC|!addr
			endif
		
			org $03CE13
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3					;>Remove delay damage (HP value only decreases when going back into pipe after entering)
			else
				INC.W !1534,X
			endif
			
			org $03CE1A
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount			;>Wendy/Lemmy's HP.
			else
				db $03
			endif
			
			org $03CED4
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount			;>Number of hits (no longer -1) to make sprites vanish
			else
				db $02
			endif
		
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $03CC14
				autoclean JSL WendyLemmyHitCountToHP
				NOP #2
			else
				%RemoveFreespaceCodeFromJMLJSL($03CC14)
				org $03CC14
				JSR.W $03D484
				LDA !14C8,X
			endif
		;Ludwig, Morton, and Roy
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01D3F3
				autoclean JSL FireballDamageLudwigMortonRoy	;>Fireball damage
				NOP #4 ;>This prevents incrementing hit counter past its maximum to prevent displaying negative HP
			else
				%RemoveFreespaceCodeFromJMLJSL($01D3F3)
				org $01D3F3
				LDA #$01
				STA $1DF9|!addr
				INC.W !1626,X
			endif
		
			org $01CFC6
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3						;>Remove delay damage (stomp)
			else
				INC.W !1626,X
			endif
		
			if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01CFCD
				db !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount			;>Set HP value
		
				org $01D3FF
				db !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount			;>Same as above, but fireball.
			else
				org $01CFCD
				db 3						;>Set HP value
		
				org $01D3FF
				db 12						;>Same as above, but fireball.
			endif
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01CDAB
				autoclean JSL LudwigMortonRoyHitCountToHP	;>Convert HP (for display)
				NOP #2
			else
				%RemoveFreespaceCodeFromJMLJSL($01CDAB)
				org $01CDAB
				STZ.W $13FB|!addr
				LDA.W !1602,X
			endif
			;Fireball and stomp jank fix
				if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Bosses)
					org $01D3AB
					autoclean JSL StompDamageLudwigMortonRoy	;>Stomp damage.
				else
					%RemoveFreespaceCodeFromJMLJSL($01D3AB)
					org $01D3AB
					LDA #$28
					STA $1DFC|!addr
				endif
;Freespace code
	freecode
	if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
		CharginChuckHitCountToHP:	;>JML from $02C1F8 (runs every frame)
			.InstantKillToDisplayHP
				if !Setting_SpriteHP_DisplayHPOfSMWSprites
					LDA !Ram_SpriteTable_CharginChuck_InstaKillHaveDisplayedHP,x
					BNE ..No							;>If already in dying phase on the next frame, don't set HP display (only do following code one time).
					LDA !14C8,x							;\If sprite status table is set to any of the kill animation, display HP meter.
					CMP #$02							;|
					BEQ ..Yes							;|
					CMP #$05							;|
					BEQ ..Yes							;/
					BRA ..No
					
					..Yes
						INC !Ram_SpriteTable_CharginChuck_InstaKillHaveDisplayedHP,x
						%IncreaseDamageCounter(!1528, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
					..No
				endif
			.DeathCheck
				LDA !14C8,x
				CMP #$02
				BCC .Restore		;>Do nothing if $00~$01
				CMP #$07
				BCC .ZeroHP		;>No HP on killed states $02~$06
				CMP #$0C
				BCC .ConvertHitCountToHP	;>Other non-killed/transformed states, allow HP display
				BRA .Restore
			
			.ZeroHP
				LDA.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
				STA !1528,x
			.ConvertHitCountToHP
				%ConvertDamageAmountToHP(!1528, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
			.Restore
				LDA !187B,x
				PHA
				JML $02C1FC|!bank		;>Again, PHA : RTL : PLA crashes the game because RTL pulls stack.
		StompCharginChuck:	;>JSL from $02C7E8
			%IncreaseDamageCounter(!1528, !Setting_SpriteHP_VanillaSprite_Chucks_StompDamage, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
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
			%IncreaseDamageCounter(!1528, !Setting_SpriteHP_FireballDamageAmount, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
			if !Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundNumber != $00
				LDA.b #!Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundNumber
				STA !Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundPort
				.Restore
					LDA !1528,x
			endif
			RTL
	endif
	if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Rex)
		RexStateToHP: ;>JSL from $03951A
			.InstantKillToDisplayHP
				LDA !Ram_SpriteTable_Rex_InstaKillHaveDisplayedHP,x
				BNE ..No							;>If already in dying phase on the next frame, don't set HP display (only do following code one time).
				LDA !14C8,x							;\If sprite status table is set to any of the kill animation, display HP meter.
				CMP #$08
				BCC ..Yes
				CMP #$09
				BCS ..Yes
				BRA ..No
				
				..Yes
					INC !Ram_SpriteTable_Rex_InstaKillHaveDisplayedHP,x
					%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)				
				..No
			.SyncToHP
				LDA #$02
				STA !Freeram_SpriteHP_MaxHPLow,x
				%ConvertDamageAmountToHP(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
			.Restore
				LDA !14C8,x
				CMP #$08
				RTL
		StompRex: ;JSL from $0395B3
			%IncreaseDamageCounter(!C2, 1, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
			.Restore
				;INC !C2,x ;>This already incremented by "IncreaseDamageCounter"
				LDA !C2,x
				RTL
	endif
	if !Setting_ModifySprAndDisplayHPOfSMWSpr
		SpinKillDisplayHP:	;>JSL from $01A93F
			.Restore
				LDA #$08
				STA $1DF9|!addr
			.CheckSprite
				LDA !7FAB10,x
				AND.b #%00001000
				BNE ..CustomSprite
				
				..Vanilla
					LDA !9E,x
					if !Setting_SpriteHP_VanillaSprite_Rex
						CMP #$AB
						BEQ ..Rex
					endif
					if !Setting_SpriteHP_VanillaSprite_OneShotSprites
						JSR ZeroOutHPOfOneShotSprites
					endif
				..CustomSprite
					RTL
				if !Setting_SpriteHP_VanillaSprite_Rex
					..Rex
						%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
						RTL
				endif
	endif
	if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		ShowHPForFallingOffScrn:		;>JSL from various
			.Restore
				LDA #$02
				STA !14C8,x
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSprites
			RTL
		ShowHPForFallingOffScrnCapeSpinQuakeNetPunch: ;>JSL from $02945B
			.Restore
				LDA #$02
				STA !14C8,x
			.DisplayOneHPIfNotACarryableSpr
				LDA !1662,x
				AND.b #%10000000
				BNE ..NonCarryable ;>Falls straight down when killed
				LDA !1656,x
				AND.b #%00010000
				BEQ ..NonCarryable ;>Can't be jumped on
				LDA !1656,x
				AND.b #%00100000 ;>Dies when jumped on
				BNE ..NonCarryable
				..Carryable ;Sprite is carryable, when hit by quake/cape spin/net punch, the sprite (such as a shell) doesn't get killed
					RTL
				
				..NonCarryable
					JSR ZeroOutHPOfOneShotSprites
					RTL
		ShowHPForFallingOffScrnYregister:
			.Restore
				LDA #$02
				STA !14C8,y
			.DisplayOneHP
				PHX
				TYX
				JSR ZeroOutHPOfOneShotSprites
				PLX
			RTL
		DefaultHPOnSpawn:
			;I recommend having custom sprites run an init routine to set its starting current and max HP rather
			;than having them here.
			;
			;The good news is that when a sprite is spawned, its sprite number ($9E/$7FAB9E) are set before
			;calling $07F722
			.Restore
				STZ.w !160E,x
				STZ.w !1594,x
			.SetDefault1HP
				LDA #$01
				STA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA #$00
					STA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
				LDA !7FAB10,x
				AND.b #%00001000
				BNE .Done
				LDA !9E,x
				%SetSpriteDefaultHP($6E, 2)		;>Dino Rhino
				%SetSpriteDefaultHP($6F, 1)
					;^Dino Torch (note that Dino torch have a max of 2 HP if transformed from Dino Rhino, otherwise a max of 1 HP if spawned directly)
			.Done
				RTL
		StompKill:	;>JSL from $01A9D3
			.Restore
				LDA #$03
				STA !14C8,x
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSprites
			RTL
		DinoRhino2HPToTorch1HP:
			.Restore
				LDA #$FF
				STA !1540,x
			.SimulateDamage
				LDA #$01
				STA $00
				if !Setting_SpriteHP_TwoByte
					STZ $01
				endif
				JSL !SharedSub_SpriteHPDamage
				RTL
		ZeroOutHPOfOneShotSprites:
			.CheckSprite
				LDA !7FAB10,x
				AND.b #%00001000
				BEQ ..VanillaSMWSpr
				..CustomSpr
					LDA !7FAB9E,x
					;Add your list of custom sprites here to not display HP
					;(It only has to be enemies that run a vanilla kill routine).
					;The syntax is:
					;  %SpriteHPMeterBlacklist(<Enter_Sprite_Number_Here>)
					;
					;If you get branch-out-of-bounds error, use this instead:
					;  %SpriteHPMeterBlacklist_UnlimitedDistance(<Enter_Sprite_Number_Here>)
					;
					;If you want a range (inclusive) of sprite numbers blacklisted, then do this:
					;  %SpriteHPMeterBlacklist_Range(<Enter_Sprite_Number_Min_Here>, <Enter_Sprite_Number_Max_Here>)
					
					
					
					;Do not remove this code here, as it is needed so if a non-blacklisted sprite
					;runs this code, it passes though all the items in the list and proceeds to
					;display the HP meter.
						JMP .DisplayHPMeterOfOneShotSprites ;>Used JMP instead of BRA as a failsafe if you added a long enough list for vanilla sprites.
				..VanillaSMWSpr
					LDA !9E,x
					;This is the same as above, but for vanilla sprite numbers.
					;
					;All other sprites beyond listed here are treated as having 1 HP. Because following
					;have multiple HPs we not to treat them as 1-shot.
						%SpriteHPMeterBlacklist($46)		;>Diggin' chuck
						%SpriteHPMeterBlacklist($AB)		;>Rex
						%SpriteHPMeterBlacklist_Range($91, $98)	;>Sprite numbers $91-$98 are chucks, which already been handled.

			.DisplayHPMeterOfOneShotSprites
				LDA.b #!SpriteHP_MaxHPAndDamageValue		;\Treat as the killing blow deals max damage to the sprite
				STA $00						;|The subroutine does the damage and HP meter switching.
				if !Setting_SpriteHP_TwoByte			;|
					LDA.b #!SpriteHP_MaxHPAndDamageValue>>8	;|
					STA $01					;|
				endif						;|
				JSL !SharedSub_SpriteHPDamage			;/
			.Done
			RTS
	endif
	if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Bosses)
		DamageBigBooBoss:
			%IncreaseDamageCounter(!1534, !Setting_SpriteHP_VanillaSprite_BigBooBoss_ThrownItemDamage, !Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
		BigBooBossHitCountToHP:
			%ConvertDamageAmountToHP(!1534, !Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount)
			%IntroFill(!1594)
			.Restore
				LDA !14C8,x
				CMP #$08
				BNE ..Return0380D4
				JML $0380A6|!bank
				..Return0380D4
					JML $0380D4|!bank
		DamageWendyLemmy:
			%IncreaseDamageCounter(!1534, !Setting_SpriteHP_VanillaSprite_WendyLemmy_StompDamage, !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
		WendyLemmyHitCountToHP:
			%ConvertDamageAmountToHP(!1534, !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount)
			.HandleIntroFill
				if !Setting_SpriteHP_BarAnimation
					LDA !Ram_WendyLemmyIntroFlag
					CMP #$25
					BNE ..NoIntroFill
					LDA #$00
					STA !Ram_WendyLemmyIntroFlag
					TXA
					CLC
					ADC.b #!sprite_slots
					STA !Freeram_SpriteHP_MeterState
					LDA #$00
					STA !Freeram_SpriteHP_BarAnimationFill
					if !Setting_SpriteHP_BarChangeDelay
						STA !Freeram_SpriteHP_BarAnimationTimer
					endif
					..NoIntroFill
				else
					LDA !Ram_WendyLemmyIntroFlag
					CMP #$25
					BNE ..NoIntroFill
					LDA #$00
					STA !Ram_WendyLemmyIntroFlag
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
			%IncreaseDamageCounter(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_FireballDamage, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount)
			if !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_Damage_SoundNumber != $00
				LDA.b #!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_Damage_SoundNumber	;\SFX
				STA !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_Damage_SoundPort		;/
			endif
			RTL
		LudwigMortonRoyHitCountToHP:
			%ConvertDamageAmountToHP(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount)
			%IntroFill(!1510)
			.Restore
				STZ $13FB|!addr
				LDA !1602,x
				RTL
		StompDamageLudwigMortonRoy:
			%IncreaseDamageCounter(!1626, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_StompDamage, !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount)
			.Restore
				LDA #$28
				STA $1DFC|!addr
				RTL
	endif