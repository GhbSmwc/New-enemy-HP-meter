incsrc "Defines/SharedSubroutineDefs.asm"
incsrc "Defines/SA1StuffDefines.asm"
incsrc "Defines/EnemyHPMeterDefines.asm"
incsrc "Defines/GraphicalBarDefines.asm"

;This patch modifies vanilla SMW sprites to utilizes the HP system. What are modified are:
; - Chargin chucks (all variants) when taking stomp damage
; - Any sprite (vanilla or custom) that have the "takes 5 fireballs to kill" tweaker bit set
; - Big Boo Boss
; - Wendy, Lemmy, Ludwig, Morton, and Roy.

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

;Hijacks

	;Code that runs every frame for chucks
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C1F8
			autoclean JML CharginChuckHitCountToHP		;>Had to be JML instead JSL because you cannot PHA : RTL [...] PLA.
		else
			%RemoveFreespaceCodeFromJMLJSL($02C1F8)
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
			%RemoveFreespaceCodeFromJMLJSL($02C7E8)
			org $02C7E8
			INC.W !1528,X
			LDA.W !1528,X
		endif
	;Modify hit count to kill to be the minimum amount of damage to kill
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02C7EF
			db !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount		;>Amount of total damage to kill for chucks
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
			%RemoveFreespaceCodeFromJMLJSL($02C20C)
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
			%RemoveFreespaceCodeFromJMLJSL($02A0FC)
			org $02A0FC
			INC.W !1528,X
			LDA.W !1528,X
		endif
		
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
			org $02A103
			db !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
		else
			org $02A103
			db 5
		endif
	;Rex to display HP
		;This code runs every frame, for this reason: when rex gets insta-killed by, fireballs, quake, etc.
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Rex)
			org $03951A
			autoclean JSL RexStateToHP
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($03951A)
			org $03951A
			LDA !14C8,x
			CMP #$08
		endif
		
		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_Rex)
			org $0395B3
			JSL StompRex
		else
			%RemoveFreespaceCodeFromJMLJSL($0395B3)
			org $0395B3
			INC !C2,x
			LDA !C2,x
		endif
	;Modify how much HP rex has (stomps only)
		if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Rex)
			org $0395B7
			CMP.b #!Setting_SpriteHP_VanillaSprite_Rex_HPAmount
		else
			org $0395B7
			CMP #$02
		endif
	;Modify spinjump kills to display HP when spinjump/yoshi stomp killed (Rex, for example, can be non-fatally damaged, or insta-killed)
		;Most sprites
			if !Setting_SpriteHP_DisplayHPOfSMWSprites
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
			if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_Rex)
				org $0395EC
				autoclean JSL SpinKillDisplayHP
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($0395EC)
				org $0395EC
				LDA #$08
				STA $1DF9|!addr
			endif
	;Modify when enemies are killed by sliding down a slope or touched a player with a super star power
		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01A86B
			autoclean JSL ShowHPForFallingOffScrn
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01A86B)
			org $01A86B
			LDA #$02
			STA !14C8,x
		endif
	;Same as above but when stomping enemies regularly (flatten).
		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01A9D3
			autoclean JSL StompKill
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01A9D3)
			org $01A9D3
			LDA #$03
			STA !14C8,x
		endif
	;Kicking stunned shelless koopas and out-of-water fish
		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01B140
			autoclean JSL ShowHPForFallingOffScrn
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01B140)
			LDA #$02
			STA !14C8,x
		endif
	;When kicked/carried sprites hit a 1-shottable enemy
		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01A5E3
			autoclean JSL ShowHPForFallingOffScrnYregister
			NOP
			
			org $01A66B
			autoclean JSL ShowHPForFallingOffScrn
			NOP
			
			org $01A68F
			autoclean JSL ShowHPForFallingOffScrn
			NOP
			
			org $01A6AC
			autoclean JSL ShowHPForFallingOffScrnYregister
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($01A5E3)
			org $01A5E3
			LDA #$02
			STA !14C8,y
			
			%RemoveFreespaceCodeFromJMLJSL($01A66B)
			org $01A66B
			LDA #$02
			STA !14C8,x
			
			%RemoveFreespaceCodeFromJMLJSL($01A68F)
			org $01A68F
			LDA #$02
			STA !14C8,x
			
			%RemoveFreespaceCodeFromJMLJSL($01A6AC)
			org $01A6AC
			LDA #$02
			STA !14C8,y
		endif

		if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		else
		endif
		
	;Bosses below (only applies to bosses with a HP system, and not bowser)
		;Big boo boss
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)	;|when switching state, not the instant the
				NOP #3										;|boo gits hit.
			else											;|
				INC.W !1534,X									;|
			endif											;/
		
			org $0381A2										;\Amount of hits to defeat big boo.
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount
			else
				db 3
			endif
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $0380A2				;\Big boo's "HP" is actually a hit counter
				autoclean JML BigBooBossHitCountToHP	;|that increments (starts at 0) every hit.
			else
				%RemoveFreespaceCodeFromJMLJSL($0380A2)
				org $0380A2				;|This hijacks converts the value to HP,
				CMP #$08				;|and makes it display its health.
				BNE $2E					;/
			endif
		;Wendy and Lemmy
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3					;>Remove delay damage (HP value only decreases when going back into pipe after entering)
			else
				INC.W !1534,X
			endif
			
			org $03CE1A
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount			;>Wendy/Lemmy's HP.
			else
				db $03
			endif
			
			org $03CED4
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				db !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount			;>Number of hits (no longer -1) to make sprites vanish
			else
				db $02
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				NOP #3						;>Remove delay damage (stomp)
			else
				INC.W !1626,X
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $01CDAB
				autoclean JSL LudwigMortonRoyHitCountToHP	;>Convert HP
				NOP #2
			else
				%RemoveFreespaceCodeFromJMLJSL($01CDAB)
				org $01CDAB
				STZ.W $13FB|!addr
				LDA.W !1602,X
			endif
		
			if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
	if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Chuck)
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
	if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Rex)
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
	if !Setting_SpriteHP_DisplayHPOfSMWSprites
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
						JSR ZeroOutHPOfOneShotSMWSprites
					endif
				..CustomSprite
					RTL
				if !Setting_SpriteHP_VanillaSprite_Rex
					..Rex
						%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
						RTL
				endif
	endif
	if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		ShowHPForFallingOffScrn:		;>JSL from $01A86B, $01B140
			.Restore
				LDA #$02
				STA !14C8,x
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSMWSprites
			RTL
	endif
	if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		ShowHPForFallingOffScrnYregister:
			.Restore
				LDA #$02
				STA !14C8,y
			.DisplayOneHP
				PHX
				TYX
				JSR ZeroOutHPOfOneShotSMWSprites
				PLX
			RTL
	endif
	if and(!Setting_SpriteHP_DisplayHPOfSMWSprites, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		StompKill:	;>JSL from $01A9D3
			.Restore
				LDA #$03
				STA !14C8,x
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSMWSprites
			RTL
	endif
	if !Setting_SpriteHP_VanillaSprite_OneShotSprites
		ZeroOutHPOfOneShotSMWSprites:
			.CheckSprite
				;All other sprites beyond listed here are treated as having 1 HP. Because following
				;have multiple HPs.
				LDA !9E,x
				CMP #$46				;\Diggin chuck
				BEQ .Done				;/
				CMP #$AB				;\Rex
				BEQ .Done				;/
				CMP #$91				;\Sprite numbers $91-$98 are chucks
				BCC ..OutOfChucksSprNumRange		;|
				CMP #$99				;|
				BCS ..OutOfChucksSprNumRange		;/
				BRA .Done
				
				..OutOfChucksSprNumRange
				
			LDA #$01				;\For 1HP sprites that lacked a health system
			STA $00					;|fudge the data to act as if they do have
			STA !Freeram_SpriteHP_CurrentHPLow,x	;|a health system.
			STA !Freeram_SpriteHP_MaxHPLow,x	;|
			if !Setting_SpriteHP_TwoByte		;|
				LDA #$00			;|
				STA $01				;|
				STA !Freeram_SpriteHP_MaxHPHi,x	;|
			endif					;|
			JSL !SharedSub_SpriteHPDamage		;/
			.Done
			RTS
	endif
	if and(!Setting_SpriteHP_ModifySMWSprites, !Setting_SpriteHP_VanillaSprite_Bosses)
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
				if !Setting_SpriteHP_DisplayHPOfSMWSprites
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