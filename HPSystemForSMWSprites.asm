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


;Note to self (at the time of writing this)
; - In SA-1, assuming default settings, RAM $87 is a backup of the sprite number, $9E,x ($3200,x)
;   defined as "!sprite_num_cache". This is because it needs to remap the addresses used without
;   the code needing to be relocated. See "SA1-Pack-140/more_sprites/more_sprites.asm".
; - A similar thing with RAM $B4, defined as "!sprite_num_pointer"

	!sprite_num_cache = $87
	!sprite_num_pointer = $B4

;Don't touch unless you know what you're doing
	!DefaultHPTableSize = "db"
	if !Setting_SpriteHP_TwoByte
		!DefaultHPTableSize = "dw"
	endif

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
	macro DealFixedDamage(DamageAmount)
		if !Setting_SpriteHP_DisplayHPOfSMWSprites
			if !Setting_SpriteHP_TwoByte
				REP #$20
				if <DamageAmount> != 0
					LDA.w #<DamageAmount>
					STA $00
				else
					STZ $00
				endif
				SEP #$20
			else
				if <DamageAmount> != 0
					LDA.b #<DamageAmount>
					STA $00
				else
					STZ $00
				endif
			endif
			JSL !SharedSub_SpriteHPDamage ;>This would display HP
		else
			if <DamageAmount> != 0
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				SEC
				SBC.b <DamageAmount>
				STA !Freeram_SpriteHP_CurrentHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA !Freeram_SpriteHP_CurrentHPHi,x
					SBC.b <DamageAmount>>>8
					STA !Freeram_SpriteHP_CurrentHPHi,x
				endif
				BCC ?UnderFlow
				
				?UnderFlow:
					LDA #$00
					STA !Freeram_SpriteHP_CurrentHPLow,x
					if !Setting_SpriteHP_TwoByte
						STA !Freeram_SpriteHP_CurrentHPHi,x
					endif
			endif
		endif
	endmacro
	macro IncreaseDamageCounter(DamageCountSpriteTableRAM, DamageAmount, DamageAmountToDie)
		?Damage:
		if !Setting_SpriteHP_DisplayHPOfSMWSprites
			%DealFixedDamage(<DamageAmount>)
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
	macro JSLRTS(JumpTo, RTLOfSameBank)
		;This allows calling subroutines ending with an RTS from a different bank
		;without crashing the game.
		;JumpTo = Address to call subroutine
		;RTLOfSameBank = Address of an RTL in the same bank as the call subroutine.
		PHK				;\Set up a 24-bit return address to make an RTL jump
		PEA.w ?ReturnAddr-1		;/to where "?ReturnAddr"
		PEA.w <RTLOfSameBank>-1		;>Set up a 16-bit return address to make RTS jump to an RTL
		JML <JumpTo>
		
		?ReturnAddr:
	endmacro
;Hijacks
	;Chucks
		;Code that runs every frame. Ensures the HP values in the new sprite RAM is in sync (for display).
			if and(and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Chuck), equal(!Ram_SpriteTable_CharginChuck_InstaKillHaveDisplayedHP, 0))
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
				if !Setting_SpriteHP_Modify5FireballsSystem == 0
					autoclean JSL StompCharginChuck
				else
					autoclean JML StompCharginChuck
				endif
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
			if !Setting_SpriteHP_Modify5FireballsSystem == 0
				autoclean JSL FireballEffect
			else
				autoclean JML FireballEffect
			endif
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
	;Fireball turns enemy into coin. In normal cases, the meter should disappear since it is no longer an enemy.
	;However, for total HP mode, we need to make sure that the damage animation plays out properly.
		!Setting_FreezeTotalHPBarAnimationDelayFromFireballs = and(and(and(notequal(!Setting_ModifySprAndDisplayHPOfSMWSpr, 0), notequal(!Setting_SpriteHP_BarAnimation, 0)), notequal(!Setting_SpriteHP_BarChangeDelay, 0)), notequal(!Setting_SpriteHP_TotalHPMode, 0))
		if !Setting_FreezeTotalHPBarAnimationDelayFromFireballs
			org $02A12D
			autoclean JSL TotalHPFireballTurnEnemyIntoCoin
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($02A12D)
			org $02A12D
			LDA #$08
			STA !14C8,x
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
				RexStompHijack:
					if !Setting_SpriteHP_VanillaSprite_Rex == 1
						autoclean JSL StompRex
						CMP.b #!Setting_SpriteHP_VanillaSprite_Rex_HPAmount
						BCC .SmushRex		;>NOTE: I changed from a BNE to a BCC, in case if it accumulated more damage beyond the threshold.
						
						org $0395C1		;Instead of <BranchOpcode> $XX, I can do <BranchOpcode> <Label> followed by org $xxxxxx : Label 
						.SmushRex
					else
						autoclean JML StompRex
					endif
			else
				%RemoveFreespaceCodeFromJMLJSL($0395B3)
				org $0395B3
				RexStompRestore:
					INC !C2,x
					LDA !C2,x
					CMP #$02
					BNE .SmushRex
					
					org $0395C1		;Instead of <BranchOpcode> $XX, I can do <BranchOpcode> <Label> followed by org $xxxxxx : Label 
					.SmushRex
			endif
	;Modify spinjump kills to display HP when spinjump/yoshi stomp killed (Rex, for example, can be non-fatally damaged, or insta-killed)
		;Most sprites (within general mario-interact-sprites routine - JSR $01A83B)
			if !Setting_ModifySprAndDisplayHPOfSMWSpr
				org $01A935
				autoclean JSL SpinjumpKillDisplayHP
				NOP #2
			else
				%RemoveFreespaceCodeFromJMLJSL($01A935)
				org $01A935
				JSR.w $019ACB
				JSL $07FC3B|!bank
			endif
		;Rex
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Rex)
				org $0395EC
				autoclean JSL SpinjumpKillDisplayHP
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
	;Show HP meter when enemies merely get stunned when jumped on (Goomba, Bob-omb, Buzzy Beetle, and Mecha Koopa).
	;Again, this is mario-interact-sprites routine. EDIT: This also triggers when kicking carried sprites.
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
			org $01AA14
			autoclean JSL StunnedKoopaShowHP
		else
			%RemoveFreespaceCodeFromJMLJSL($01AA14)
			org $01AA14
			if !Setting_SpriteHP_Koopas_ClassicBehavior != 0
				LDA #$FF
			else
				LDA #$02
			endif
			if !sa1 == 0
				LDY $9E,x
			else
				LDY !sprite_num_cache
			endif
		endif
	;Optional feature if user wished to have stunned koopas not leave their shells
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, notequal(!Setting_SpriteHP_Koopas_ClassicBehavior, 0))
			org $0196C5
			BNE $04
		else
			org $0196C5
			BNE $1A
		endif
	;Shell and shell-less koopa HP meter switcher. A koopa and an empty shell are the same sprite (but with a different state).
	;A shell-less koopa being seperated from their shell is a seperate sprite spawned in the level. When entering an empty shell,
	;they simply just get deleted.
		;When koopas exit their shells, switch the HP meter to them and not the shell itself
			if and(and(!Setting_ModifySprAndDisplayHPOfSMWSpr, equal(!Setting_SpriteHP_Koopas_ClassicBehavior, 0)), notequal(!Setting_SpriteHP_VanillaSprite_OneShotSprites, 0))
				org $0196F6
				autoclean JSL TransferHPFromKoopaToShelllessKoopa
				NOP
			else
				if notequal(read3($0196F6+1), $07F7D2)
					%RemoveFreespaceCodeFromJMLJSL($0196F6)
				endif
				org $0196F6
				JSL $07F7D2|!bank
			endif
		;When shell-less koopas enter their shells, switch the HP meter to them.
			if and(and(!Setting_ModifySprAndDisplayHPOfSMWSpr, equal(!Setting_SpriteHP_Koopas_ClassicBehavior, 0)), notequal(!Setting_SpriteHP_VanillaSprite_OneShotSprites, 0))
				org $018ACC
				autoclean JSL TransferHPFromShelllessKoopaToKoopa
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($018ACC)
				org $018ACC
				LDY !1594,x
				LDA.b #$10
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
	;To be replaced with at that location:
	;  Addr+0  JSL PatchCode
	;  Addr+4  NOP
	;
	;NOTES:
	; - If your custom sprites uses a vanilla death routine and you don't want a health meter
	;   for those sprites, see "ZeroOutHPOfOneShotSprites:" (without quotes and including the colon)
	;   on this ASM file.
	; - Reznor is not included here and is handled differently because trying to hijack at $039ACC
	;   results in a full HP meter due to a call to clear and load sprite tables at $039AEE aftwards.
	
		%HijacksForFallingOffScrn($01A5E3, ShowHPForFallingOffScrnYregister, y)
		%HijacksForFallingOffScrn($01A66B, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A68F, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A6AC, ShowHPForFallingOffScrnYregister, y)
		%HijacksForFallingOffScrn($01A86B, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01A9E9, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($01B140, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($02945B, ShowHPForFallingOffScrnCapeSpinQuakeNetPunch, x)
		%HijacksForFallingOffScrn($02F29D, ShowHPForFallingOffScrn, x)
		%HijacksForFallingOffScrn($028168, ShowHPForFallingOffScrnYregister, y) ;>Display HP for sprites blown up by bob-omb explosions
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
	;When sprite changes into another sprite (become a different sprite number) when jumped on
	;Covers winged enemies and Dino Rhino.
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
				org $01A99B
				autoclean JSL TransformWhenStomped
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($01A99B)
				org $01A99B
				if !sa1 == 0
					STA $9E,x
				else
					STA.b (!sprite_num_pointer)
				endif
				LDA !15F6,x
			endif
		;Super Koopa (sprite $73). One with feather (flashing cape), becomes a shell-less blue koopa when jumped, thus
		;having 2 HP, the other dies instantly (1 HP). RAM $1534 is 0 for no feather (1HP), otherwise 1 (2 HP)
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
				org $018531
				autoclean JSL FeatherSuperKoopaInit
			else
				%RemoveFreespaceCodeFromJMLJSL($018531)
				org $018531
				LDA !E4,x
				AND.b #$10
			endif
		;Parachute enemies. NOTE: Unlike the Dino Rhino, which is treated as a 2HP enemy based on it turning
		;into a dino torch, Parachute enemies however is treated as 1HP and taking no damage when becomming
		;an equivalent enemy. This is because they automatically turn into the equivalent enemy when touching
		;the ground (if parachute counts as 1 extra HP, they'd appear to take 1 damage when landing).
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
				org $01A98E
				autoclean JSL ParachuteEnemies
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($01A98E)
				org $01A98E
				LDA.b #$80
				STA !1540,x
			endif
	;Enemies that don't get killed at all by stomps, but get changes state. The meter will just simply display
	;without damage
		;Wigglers
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
				org $02F26B
				autoclean JSL StompWigglerShowHP
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($02F26B)
				org $02F26B
				LDA #$03
				STA $1DF9|!addr
			endif
		;Dry bones and Bony Beetle. NOTE: They seemingly process offscreen when they are in their crumbled state,
		;causing the HP meter to continue to display even far offscreen.
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
				org $01E5FE
				autoclean JSL StompDryBonesBonyBeetle
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($01E5FE)
				org $01E5FE
				LDA #$FF
				STA !1540,x
			endif
	;Pokey. Notes:
	; - We actually need to check how many segments the Pokey has, because there is a glitch that
	;   if you throw a sprite into the top-most part of Pokey, it will spawn a Pokey Head but not actually remove
	;   that segment.
	; - When the last segment (head) is killed, the meter disappears immidiately because the sprite is programmed
	;   to always spawn a segment when hit, including its head. When viewing frame-by-frame when the last segment
	;   (head) is killed the main pokey sprite disappears ($14C8,x == $00) for 1 frame before spawning a segment
	;   sprite.
			PokeyInitHijack:
				if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, notequal(!Setting_SpriteHP_VanillaSprite_Pokey, 0))
					org $018554
					autoclean JML PokeyInitHP
				else
					%RemoveFreespaceCodeFromJMLJSL($018554)
					org $018554
					STA !C2,x
					BRA .FaceMario
					
					org $01857C
					.FaceMario
				endif
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, notequal(!Setting_SpriteHP_VanillaSprite_Pokey, 0))
				org $02B80D
				autoclean JSL PokeyLostSegment
				NOP
			else
				%RemoveFreespaceCodeFromJMLJSL($02B80D)
				org $02B80D
				LDA.w $02B829,y
				STA $0D
			endif
		if and(!Setting_SpriteHP_RemoveOrApplyPatch, notequal(!Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundNumber, 0))
			org $02B7DB
			autoclean JSL PokeyThrownSprSfx
		else
			%RemoveFreespaceCodeFromJMLJSL($02B7DB)
			org $02B7DB
			LDA.w !D8,y
			SEC
		endif
	;Reznor. Note that when killed, it calls the "InitSpriteTables" subroutine at $xxxxxx.
	;Thus resulting in the meter jumping to 0 back to 1. I had to hijack at $039AF2 to force it to be zero
		ReznorHijack:
			if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
				org $039872
				autoclean JML ReznorIntroFill
			else
				%RemoveFreespaceCodeFromJMLJSL($039872)
				org $039872
				CPX #$07
				BNE .NotBaseSprite
				
				org $03987E
				.NotBaseSprite
			endif
		if and(and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses), notequal(!Setting_SpriteHP_TotalHPMode, 0))
			org $0398E1
			autoclean JSL ReznorDefeatedClearHPMeter
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($0398E1)
			org $0398E1
			LDA #$FF
			STA $1493|!addr
		endif
		if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_Bosses)
			org $039ABB
			autoclean JSL ReznorDead
			NOP
		else
			%RemoveFreespaceCodeFromJMLJSL($039ABB)
			org $039ABB
			LDA #$03
			STA $1DF9|!addr
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
	if and(and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck), equal(!Setting_SpriteHP_VanillaSprite_OneShotSprites, 0))
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
						if !Setting_SpriteHP_Modify5FireballsSystem == 0
							%IncreaseDamageCounter(!1528, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
						else
							%DealFixedDamage(!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount) ;>Make it show that its HP went to 0.
						endif
					..No
				endif
			.DeathCheck
				if !Setting_SpriteHP_Modify5FireballsSystem == 0
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
				endif
			.Restore
				LDA !187B,x
				PHA
				JML $02C1FC|!bank		;>Again, PHA : RTL : PLA crashes the game because RTL pulls stack.
	endif
	if and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_VanillaSprite_Chuck)
		StompCharginChuck:	;>JSL/JML from $02C7E8
			if !Setting_SpriteHP_Modify5FireballsSystem == 0
				%IncreaseDamageCounter(!1528, !Setting_SpriteHP_VanillaSprite_Chucks_StompDamage, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
				RTL
			else
				%DealFixedDamage(!Setting_SpriteHP_VanillaSprite_Chucks_StompDamage)
				
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				if !Setting_SpriteHP_TwoByte
					ORA !Freeram_SpriteHP_CurrentHPHi,x
				endif
				BEQ .SpriteDead
				.SpriteAlive
					JML $02C7F6|!bank
				.SpriteDead
					JML $02C7F2|!bank
			endif
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
		FireballEffect:	;>JSL/JML from $02A0FC
			if !Setting_SpriteHP_Modify5FireballsSystem == 0
				%IncreaseDamageCounter(!1528, !Setting_SpriteHP_FireballDamageAmount, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
			else
				%DealFixedDamage(!Setting_SpriteHP_FireballDamageAmount)
			endif
			if !Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundNumber != $00
				LDA.b #!Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundNumber
				STA !Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundPort
			endif
			if !Setting_SpriteHP_Modify5FireballsSystem == 0
				.Restore
					LDA !1528,x
					RTL
			else
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				if !Setting_SpriteHP_TwoByte
					ORA !Freeram_SpriteHP_CurrentHPHi,x
				endif
				BEQ .SpriteDead
				.SpriteAlive
					JML $02A143|!bank
				.SpriteDead
					JML $02A106|!bank
			endif
			
	endif
	if !Setting_FreezeTotalHPBarAnimationDelayFromFireballs
		TotalHPFireballTurnEnemyIntoCoin: ;>JSL from $02A12D
			LDA !Freeram_SpriteHP_MeterState
			CMP.b #!sprite_slots*2
			BEQ .BarAnimationForTotalHP
			CMP.b #(!sprite_slots*2)+1
			BEQ .BarAnimationForTotalHP
			BRA .Restore
			
			.BarAnimationForTotalHP
				LDA.b #!Setting_SpriteHP_BarChangeDelay
				STA !Freeram_SpriteHP_BarAnimationTimer
			.Restore
				LDA #$08
				STA !14C8,x
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
					if !Setting_SpriteHP_VanillaSprite_Rex == 1
						%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)				
					else
						%DealFixedDamage(!Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
					endif
				..No
			.SyncToHP
				if !Setting_SpriteHP_VanillaSprite_Rex == 1
					LDA.b #!Setting_SpriteHP_VanillaSprite_Rex_HPAmount
					STA !Freeram_SpriteHP_MaxHPLow,x
					%ConvertDamageAmountToHP(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
				endif
			.Restore
				LDA !14C8,x
				CMP #$08
				RTL
		StompRex: ;>JSL from $0395B3
			if !Setting_SpriteHP_VanillaSprite_Rex == 1
				%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_StompDamage, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
				.Restore
					;INC !C2,x ;>This already incremented by "IncreaseDamageCounter"
					LDA !C2,x
					RTL
			else
				%DealFixedDamage(!Setting_SpriteHP_VanillaSprite_Rex_StompDamage)
				INC !C2,x	;>Advance the Rex state
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				if !Setting_SpriteHP_TwoByte
					ORA !Freeram_SpriteHP_CurrentHPHi,x
				endif
				BNE .Smushed
				JML $0395BB|!bank
				.Smushed
					JML $0395C1|!bank
			endif
	endif
	if !Setting_ModifySprAndDisplayHPOfSMWSpr
		SpinjumpKillDisplayHP:	;>JSL from $01A93F
			.CheckSprite
				JSR IsKoopaShellEmpty
				BCS .Done
				if !Setting_SpriteHP_UsingCustomSprites
					LDA !7FAB10,x
					AND.b #%00001000
					BNE ..CustomSprite
				endif
				..Vanilla
					LDA !9E,x
					if !Setting_SpriteHP_VanillaSprite_Rex
						CMP #$AB
						BEQ ..Rex
					endif
					if !Setting_SpriteHP_VanillaSprite_OneShotSprites
						JSR ZeroOutHPOfOneShotSprites
					endif
				if !Setting_SpriteHP_UsingCustomSprites
					..CustomSprite
				endif
				if !Setting_SpriteHP_VanillaSprite_Rex
					BRA .Done
					..Rex
						%IncreaseDamageCounter(!C2, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount, !Setting_SpriteHP_VanillaSprite_Rex_HPAmount)
						RTL
				endif
			.Done
			.Restore
				!Eval_Addr_019ACB #= $019ACB|!bank
				!Eval_Addr_01A7E3 #= $01A7E3|!bank
				%JSLRTS(!Eval_Addr_019ACB, !Eval_Addr_01A7E3)
				;^Asar gets confused if you enter these values directly into the macro because
				; if entered without order of operations (without parenthesis), you get depreciation
				; warnings, with parenthesis, it thinks the opcode using the arguments are using
				; indirect mode (which results in invalid opcodes).
			RTL
	endif
	if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		ShowHPForFallingOffScrn:		;>JSL from various
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSprites
			.Restore
				LDA #$02
				STA !14C8,x
			RTL
		ShowHPForFallingOffScrnCapeSpinQuakeNetPunch: ;>JSL from $02945B
			JSR IsKoopaShellEmpty
			BCS .Done
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
				
				%DealFixedDamage(0)	;>Display HP (no damage) of flipped but not killed sprites
				BRA .Done
				..NonCarryable
					JSR ZeroOutHPOfOneShotSprites
			.Done
			.Restore
				LDA #$02
				STA !14C8,x
				RTL
		ShowHPForFallingOffScrnYregister:
			.DisplayOneHP
				PHX
				TYX
				JSR ZeroOutHPOfOneShotSprites
				PLX
			.Restore
				LDA #$02
				STA !14C8,y
			RTL
		IsKoopaShellEmpty:
			;Checks if the sprite is an empty shell.
			;Output:
			; - Carry: 0 = no, 1 = yes
			;NOTE: This subroutine should be called before setting $14C8.
			LDA #$00
			STA $40FFFF
			.CheckIfSpriteCustom
				;Is a custom sprite?
				if !Setting_SpriteHP_UsingCustomSprites
					LDA !7FAB10,x
					AND.b #%00001000
					BNE .No
				endif
			.CheckVanillaSpriteNumber
				;Is vanilla sprite number $04-$07?
				LDA !9E,x
				CMP #$04
				BCC .No
				CMP.b #$07+1
				BCS .No
			.CheckStatus
				;Is a carryable/kicked/carried/falling off screen (briefly) sprite?
				LDA !14C8,x
				CMP #$02
				BEQ ..Maybe ;>When cape-spinned the very frame $14C8 is set to #$02
				CMP #$09
				BCC .No
				CMP.b #$0B+1
				BCS .No
				..Maybe
			.CheckIfKoopaInside
				;Is in a status that have no koopa inside the stunned shell?
				;Note that I did not check RAM $C2 (result of $1540|$1558) because
				;it hasn't been updated yet.
				LDA !1540,x
				ORA !1558,x
				BNE .No
			.Yes
				SEC
				RTS
			.No
				CLC
				RTS
	endif
	if !Setting_SpriteHP_RemoveOrApplyPatch
		DefaultHPOnSpawn:	;>JSL from $07F779
			;This code makes the routine that clears the sprite table during a spawn to set their HP values by
			;default.
			;
			;Note that this is also used during an enemy spawn ambush system, each newly spawned enemy
			;must deduct the amount of HP in a RAM defined "!Freeram_SpriteHP_TotalHPOfUnloadedSprites" so it
			;can track how much total HP left properly. Should the meter increases or decreases when they spawn,
			;that means their spawn HP isn't set up correctly. Note that it will break for enemies that spawn
			;with configurable amount of HP (thus editing the ambush system or the spawning indicator is needed).
			;
			;The good news is that when a sprite is spawned, its sprite number ($9E/$7FAB9E) are set before
			;calling $07F722
			.Restore
				STZ.w !160E,x
				STZ.w !1594,x
			.SetDefault1HP
				PHP
				;^Here, we need to preserve the carry flag, as pixi hijacks the sprite table clearing and
				;loading sprite routine, and then later checks the carry flag. After this routine ends,
				;we need to PLP before any RTLs here.
				PHB
				PHK
				PLB
				PHY
				if !Setting_SpriteHP_UsingCustomSprites
					..CheckIfSpriteIsCustom
						LDA !7FAB10,x
						AND.b #%00001000
						BEQ ..SetVanillaSpriteDefaultHP
						
					..SetCustomSpriteDefaultHP
						LDA !7FAB9E,x
						BRA ..SetHP
				endif
				..SetVanillaSpriteDefaultHP
					LDA !9E,x
				..SetHP
					if !Setting_SpriteHP_TwoByte
						REP #$30 ;>We need 16-bit indexing because when doubling, values $80+ will exceed $FF, and sprite numbers goes all the way to $C8 or $BF.
						AND #$00FF
						ASL
					endif
					TAY
					LDA .DefaultSMWSprHP,y
					if !Setting_SpriteHP_TwoByte
						SEP #$30
					endif
					STA !Freeram_SpriteHP_CurrentHPLow,x
					STA !Freeram_SpriteHP_MaxHPLow,x
					if !Setting_SpriteHP_TwoByte
						XBA
						STA !Freeram_SpriteHP_CurrentHPHi,x
						STA !Freeram_SpriteHP_MaxHPHi,x
					endif
			.Done
				PLY
				PLB
				PLP
				RTL
			;Default HP values for sprites and custom sprites. These are values that their current and max HP are set when they first spawn initalized
			;(before their init code executes)
			;
			;Any sprite with a max HP of 0 are consitered "blacklisted" and the meter will not display HP for that (when instantly killed).
			;If !Setting_SpriteHP_TwoByte == 0, then only enter values 0-255, else 0-65535 is allowed. Values
			;at and above 256 or 65536 will be modulo'ed by those values. A value without a prefix ("%" = binary, "$" = hex) means decimal.
			
			;These are default HP table values for vanilla SMW sprites, for sprite numbers $00-$C8.
				.DefaultSMWSprHP
					!DefaultHPTableSize 00001 ; <- $00 - Green shell-less Koopa
					!DefaultHPTableSize 00001 ; <- $01 - Red shell-less Koopa
					!DefaultHPTableSize 00001 ; <- $02 - Blue shell-less Koopa
					!DefaultHPTableSize 00001 ; <- $03 - Yellow shell-less Koopa
					!DefaultHPTableSize 00001 ; <- $04 - Green Koopa (including the shell)
					!DefaultHPTableSize 00001 ; <- $05 - Red Koopa (including the shell)
					!DefaultHPTableSize 00001 ; <- $06 - Blue Koopa (including the shell)
					!DefaultHPTableSize 00001 ; <- $07 - Yellow Koopa (including the shell)
					!DefaultHPTableSize 00002 ; <- $08 - Green winged Koopa, flying
					!DefaultHPTableSize 00002 ; <- $09 - Green winged Koopa, bouncing
					!DefaultHPTableSize 00002 ; <- $0A - Red winged Koopa, vertical
					!DefaultHPTableSize 00002 ; <- $0B - Red winged Koopa, horizontal
					!DefaultHPTableSize 00002 ; <- $0C - Yellow winged Koopa
					!DefaultHPTableSize 00001 ; <- $0D - Bob-Omb
					!DefaultHPTableSize 00001 ; <- $0E - Keyhole
					!DefaultHPTableSize 00001 ; <- $0F - Goomba
					!DefaultHPTableSize 00002 ; <- $10 - Winged Goomba
					!DefaultHPTableSize 00001 ; <- $11 - Buzzy Beetle
					!DefaultHPTableSize 00001 ; <- $12 - Unused
					!DefaultHPTableSize 00001 ; <- $13 - Spiny
					!DefaultHPTableSize 00001 ; <- $14 - Falling Spiny
					!DefaultHPTableSize 00001 ; <- $15 - Fish, horizontal
					!DefaultHPTableSize 00001 ; <- $16 - Fish, vertical
					!DefaultHPTableSize 00001 ; <- $17 - Fish, flying (spawned by sprite D1)
					!DefaultHPTableSize 00001 ; <- $18 - Fish, jumping
					!DefaultHPTableSize 00001 ; <- $19 - Display text from level message 1
					!DefaultHPTableSize 00001 ; <- $1A - Classic Piranha Plant
					!DefaultHPTableSize 00001 ; <- $1B - Bouncing Football
					!DefaultHPTableSize 00001 ; <- $1C - Bullet Bill
					!DefaultHPTableSize 00001 ; <- $1D - Hopping flame
					!DefaultHPTableSize 00001 ; <- $1E - Lakitu
					!DefaultHPTableSize 00001 ; <- $1F - Magikoopa
					!DefaultHPTableSize 00000 ; <- $20 - Magikoopa's magic
					!DefaultHPTableSize 00000 ; <- $21 - Moving coin
					!DefaultHPTableSize 00001 ; <- $22 - Green vertical net Koopa
					!DefaultHPTableSize 00001 ; <- $23 - Red vertical net Koopa
					!DefaultHPTableSize 00001 ; <- $24 - Green horizontal net Koopa
					!DefaultHPTableSize 00001 ; <- $25 - Red horizontal net Koopa
					!DefaultHPTableSize 00001 ; <- $26 - Thwomp
					!DefaultHPTableSize 00001 ; <- $27 - Thwimp
					!DefaultHPTableSize 00001 ; <- $28 - Big Boo
					!DefaultHPTableSize 00001 ; <- $29 - Koopa Kid
					!DefaultHPTableSize 00001 ; <- $2A - Upside-down Piranha Plant
					!DefaultHPTableSize 00001 ; <- $2B - Sumo Brother's lightning
					!DefaultHPTableSize 00000 ; <- $2C - Yoshi egg
					!DefaultHPTableSize 00000 ; <- $2D - Baby Yoshi
					!DefaultHPTableSize 00001 ; <- $2E - Spike Top
					!DefaultHPTableSize 00000 ; <- $2F - Portable springboard
					!DefaultHPTableSize 00001 ; <- $30 - Dry Bones that throws bones
					!DefaultHPTableSize 00001 ; <- $31 - Bony Beetle
					!DefaultHPTableSize 00001 ; <- $32 - Dry Bones that stays on ledges
					!DefaultHPTableSize 00001 ; <- $33 - Podoboo/vertical fireball
					!DefaultHPTableSize 00000 ; <- $34 - Boss fireball
					!DefaultHPTableSize 00000 ; <- $35 - Yoshi
					!DefaultHPTableSize 00000 ; <- $36 - Unused
					!DefaultHPTableSize 00001 ; <- $37 - Boo
					!DefaultHPTableSize 00001 ; <- $38 - Eerie (straight)
					!DefaultHPTableSize 00001 ; <- $39 - Eerie (wave)
					!DefaultHPTableSize 00001 ; <- $3A - Urchin (fixed distance)
					!DefaultHPTableSize 00001 ; <- $3B - Urchin (wall detect)
					!DefaultHPTableSize 00001 ; <- $3C - Urchin (wall follow)
					!DefaultHPTableSize 00001 ; <- $3D - Rip Van Fish
					!DefaultHPTableSize 00000 ; <- $3E - P-switch
					!DefaultHPTableSize 00001 ; <- $3F - Para-Goomba
					!DefaultHPTableSize 00001 ; <- $40 - Para-Bomb
					!DefaultHPTableSize 00000 ; <- $41 - Dolphin (long jump)
					!DefaultHPTableSize 00000 ; <- $42 - Dolphin (short jump)
					!DefaultHPTableSize 00000 ; <- $43 - Dolphin (vertical)
					!DefaultHPTableSize 00001 ; <- $44 - Torpedo Ted
					!DefaultHPTableSize 00000 ; <- $45 - Directional coins
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $46 - Diggin' Chuck
					!DefaultHPTableSize 00001 ; <- $47 - Swimming/jumping fish
					!DefaultHPTableSize 00001 ; <- $48 - Diggin' Chuck's rock
					!DefaultHPTableSize 00001 ; <- $49 - Growing/shrinking pipe
					!DefaultHPTableSize 00000 ; <- $4A - Goal Sphere
					!DefaultHPTableSize 00001 ; <- $4B - Pipe-dwelling Lakitu
					!DefaultHPTableSize 00001 ; <- $4C - Exploding block
					!DefaultHPTableSize 00001 ; <- $4D - Monty Mole (ground-dwelling)
					!DefaultHPTableSize 00001 ; <- $4E - Monty Mole (ledge-dwelling)
					!DefaultHPTableSize 00001 ; <- $4F - Jumping Piranha Plant
					!DefaultHPTableSize 00001 ; <- $50 - Jumping Piranha Plant (fireballs)
					!DefaultHPTableSize 00001 ; <- $51 - Ninji
					!DefaultHPTableSize 00000 ; <- $52 - Moving Ghost House hole (note: changed to $0185B7 in LM v2.53+)
					!DefaultHPTableSize 00000 ; <- $53 - Throwblock
					!DefaultHPTableSize 00000 ; <- $54 - Revolving door for climbing net
					!DefaultHPTableSize 00000 ; <- $55 - Checkerboard platform (horizontal)
					!DefaultHPTableSize 00000 ; <- $56 - Flying rock platform (horizontal)
					!DefaultHPTableSize 00000 ; <- $57 - Checkerboard platform (vertical)
					!DefaultHPTableSize 00000 ; <- $58 - Flying rock platform (vertical)
					!DefaultHPTableSize 00000 ; <- $59 - Turnblock bridge (horz/vert)
					!DefaultHPTableSize 00000 ; <- $5A - Turnblock bridge (horz only)
					!DefaultHPTableSize 00000 ; <- $5B - Floating brown platform
					!DefaultHPTableSize 00000 ; <- $5C - Floating checkerboard platform
					!DefaultHPTableSize 00000 ; <- $5D - Small orange floating platform
					!DefaultHPTableSize 00000 ; <- $5E - Large orange floating platform
					!DefaultHPTableSize 00000 ; <- $5F - Swinging brown platform
					!DefaultHPTableSize 00000 ; <- $60 - Flat switch palace switch
					!DefaultHPTableSize 00000 ; <- $61 - Skull raft
					!DefaultHPTableSize 00000 ; <- $62 - Brown line-guided platform
					!DefaultHPTableSize 00000 ; <- $63 - Brown/checkered line-guided platform
					!DefaultHPTableSize 00000 ; <- $64 - Line-guided rope mechanism
					!DefaultHPTableSize 00001 ; <- $65 - Chainsaw (line-guided)
					!DefaultHPTableSize 00001 ; <- $66 - Upside-down chainsaw (line-guided)
					!DefaultHPTableSize 00001 ; <- $67 - Grinder (line-guided)
					!DefaultHPTableSize 00001 ; <- $68 - Fuzzy (line-guided)
					!DefaultHPTableSize 00001 ; <- $69 - Unused
					!DefaultHPTableSize 00000 ; <- $6A - Coin game cloud
					!DefaultHPTableSize 00000 ; <- $6B - Wall springboard (left wall)
					!DefaultHPTableSize 00000 ; <- $6C - Wall springboard (right wall)
					!DefaultHPTableSize 00000 ; <- $6D - Invisible solid block
					!DefaultHPTableSize 00002 ; <- $6E - Dino-Rhino
					!DefaultHPTableSize 00001 ; <- $6F - Dino-Torch
					!DefaultHPTableSize 00001 ; <- $70 - Pokey
					!DefaultHPTableSize 00001 ; <- $71 - Super Koopa (red cape)
					!DefaultHPTableSize 00001 ; <- $72 - Super Koopa (yellow cape)
					!DefaultHPTableSize 00001 ; <- $73 - Super Koopa (ground/feather)
					!DefaultHPTableSize 00000 ; <- $74 - Mushroom
					!DefaultHPTableSize 00000 ; <- $75 - Flower
					!DefaultHPTableSize 00000 ; <- $76 - Star
					!DefaultHPTableSize 00000 ; <- $77 - Feather
					!DefaultHPTableSize 00000 ; <- $78 - 1up mushroom
					!DefaultHPTableSize 00000 ; <- $79 - Growing vine
					!DefaultHPTableSize 00000 ; <- $7A - Firework
					!DefaultHPTableSize 00000 ; <- $7B - Goal tape
					!DefaultHPTableSize 00000 ; <- $7C - Peach
					!DefaultHPTableSize 00000 ; <- $7D - P-Balloon
					!DefaultHPTableSize 00000 ; <- $7E - Flying red coin
					!DefaultHPTableSize 00000 ; <- $7F - Flying golden mushroom
					!DefaultHPTableSize 00000 ; <- $80 - Key
					!DefaultHPTableSize 00000 ; <- $81 - Changing item
					!DefaultHPTableSize 00000 ; <- $82 - Bonus game sprite
					!DefaultHPTableSize 00000 ; <- $83 - Flying question block (left)
					!DefaultHPTableSize 00000 ; <- $84 - Flying question block (back and forth)
					!DefaultHPTableSize 00001 ; <- $85 - Unused
					!DefaultHPTableSize 00001 ; <- $86 - Wiggler
					!DefaultHPTableSize 00000 ; <- $87 - Lakitu's cloud
					!DefaultHPTableSize 00000 ; <- $88 - Winged cage
					!DefaultHPTableSize 00000 ; <- $89 - Layer 3 Smash
					!DefaultHPTableSize 00000 ; <- $8A - Yoshi's House bird
					!DefaultHPTableSize 00000 ; <- $8B - Puff of smoke from Yoshi's House
					!DefaultHPTableSize 00000 ; <- $8C - Side exit enable
					!DefaultHPTableSize 00000 ; <- $8D - Ghost house exit sign and door
					!DefaultHPTableSize 00000 ; <- $8E - Invisible "Warp Hole"
					!DefaultHPTableSize 00000 ; <- $8F - Scale platforms
					!DefaultHPTableSize 00001 ; <- $90 - Large green gas bubble
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $91 - Chargin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $92 - Splittin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $93 - Bouncin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $94 - Whistlin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $95 - Clappin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $96 - Chargin' Chuck (unused)
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $97 - Puntin' Chuck
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount ; <- $98 - Pitchin' Chuck
					!DefaultHPTableSize 00001 ; <- $99 - Volcano Lotus
					!DefaultHPTableSize 00001 ; <- $9A - Sumo Brother
					!DefaultHPTableSize 00001 ; <- $9B - Hammer Bro.
					!DefaultHPTableSize 00000 ; <- $9C - Hammer Bro. platform
					!DefaultHPTableSize 00000 ; <- $9D - Bubble
					!DefaultHPTableSize 00000 ; <- $9E - Ball 'n' Chain
					!DefaultHPTableSize 00001 ; <- $9F - Banzai Bill
					!DefaultHPTableSize 00001 ; <- $A0 - Bowser
					!DefaultHPTableSize 00001 ; <- $A1 - Bowser's bowling ball
					!DefaultHPTableSize 00001 ; <- $A2 - MechaKoopa
					!DefaultHPTableSize 00000 ; <- $A3 - Rotating gray platform
					!DefaultHPTableSize 00001 ; <- $A4 - Floating spike ball
					!DefaultHPTableSize 00001 ; <- $A5 - Sparky/Fuzzy (wall follow)
					!DefaultHPTableSize 00001 ; <- $A6 - Hothead
					!DefaultHPTableSize 00001 ; <- $A7 - Iggy's ball
					!DefaultHPTableSize 00001 ; <- $A8 - Blargg
					!DefaultHPTableSize 00001 ; <- $A9 - Reznor
					!DefaultHPTableSize 00001 ; <- $AA - Fishbone
					!DefaultHPTableSize !Setting_SpriteHP_VanillaSprite_Rex_HPAmount ; <- $AB - Rex
					!DefaultHPTableSize 00000 ; <- $AC - Wooden spike (down)
					!DefaultHPTableSize 00000 ; <- $AD - Wooden spike (up)
					!DefaultHPTableSize 00001 ; <- $AE - Fishin' Boo
					!DefaultHPTableSize 00001 ; <- $AF - Boo Block
					!DefaultHPTableSize 00001 ; <- $B0 - Reflecting stream of Boo Buddies
					!DefaultHPTableSize 00000 ; <- $B1 - Creating/eating block
					!DefaultHPTableSize 00001 ; <- $B2 - Falling spike
					!DefaultHPTableSize 00000 ; <- $B3 - Bowser statue fireball
					!DefaultHPTableSize 00001 ; <- $B4 - Grinder (ground)
					!DefaultHPTableSize 00001 ; <- $B5 - Falling Podoboo (unused)
					!DefaultHPTableSize 00001 ; <- $B6 - Reflecting Podoboo
					!DefaultHPTableSize 00000 ; <- $B7 - Carrot Top Lift (up-right)
					!DefaultHPTableSize 00000 ; <- $B8 - Carrot Top Lift (up-left)
					!DefaultHPTableSize 00000 ; <- $B9 - Info Box
					!DefaultHPTableSize 00000 ; <- $BA - Timed Lift
					!DefaultHPTableSize 00000 ; <- $BB - Moving castle block
					!DefaultHPTableSize 00001 ; <- $BC - Bowser statue
					!DefaultHPTableSize 00001 ; <- $BD - Sliding Blue Koopa
					!DefaultHPTableSize 00001 ; <- $BE - Swooper
					!DefaultHPTableSize 00001 ; <- $BF - Mega Mole
					!DefaultHPTableSize 00000 ; <- $C0 - Sinking gray platform on lava
					!DefaultHPTableSize 00000 ; <- $C1 - Flying gray turnblocks
					!DefaultHPTableSize 00001 ; <- $C2 - Blurp
					!DefaultHPTableSize 00001 ; <- $C3 - Porcu-Puffer
					!DefaultHPTableSize 00000 ; <- $C4 - Falling gray platform
					!DefaultHPTableSize 00003 ; <- $C5 - Big Boo BossBig Boo Boss
					!DefaultHPTableSize 00000 ; <- $C6 - Spotlight/disco ball
					!DefaultHPTableSize 00000 ; <- $C7 - Invisible mushroom
					!DefaultHPTableSize 00000 ; <- $C8 - Light switch


			
			;These are default HP table values for custom sprites. Here, valid custom sprite numbers are $00-$BF. Same rules as above.
				if !Setting_SpriteHP_UsingCustomSprites
					.DefaultCustSprHP
					;                    +$00   +$01   +$02   +$03   +$04   +$05   +$06   +$07   +$08   +$09   +$0A   +$0B   +$0C   +$0E   +$0E   +$0F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $00-$0F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $10-$1F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $20-$2F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $30-$3F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $40-$4F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $50-$5F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $60-$6F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $70-$7F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $80-$8F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $90-$9F
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $A0-$AF
					!DefaultHPTableSize 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001, 00001 ; <- $B0-$BF
				endif
	endif
	if and(!Setting_ModifySprAndDisplayHPOfSMWSpr, !Setting_SpriteHP_VanillaSprite_OneShotSprites)
		StompKill:	;>JSL from $01A9D3
			.Restore
				LDA #$03
				STA !14C8,x
			.DisplayOneHP
				JSR ZeroOutHPOfOneShotSprites
			RTL
		TransformWhenStomped: 	;>JSL from $01A99B
			;For Winged Koopas at $08-$0C and a winged Galoomba $10
			;This also executes when Dino Rhino turns into Dino Torch
			.ShowHP
				PHA
				%DealFixedDamage(1)
				PLA
			.Restore
				;Restore has to be done towards end due to A being needed.
				if !sa1 == 0
					STA $9E,x
				else
					STA.b (!sprite_num_pointer)
				endif
				LDA !15F6,x
				RTL
		FeatherSuperKoopaInit:
			.Default1HP
				LDA #$01
				STA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA #$00
					STA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
			.Restore
				LDA !E4,x	;\Restore code
				AND.b #$10	;/(Even block X position = Feather, and 2 HP)
			.SetHP
				BNE ..NonFeathered
				
				..Feathered
					PHA
					LDA #$02
					STA !Freeram_SpriteHP_CurrentHPLow,x
					STA !Freeram_SpriteHP_MaxHPLow,x
					PLA
				..NonFeathered
				RTL
		ParachuteEnemies:
			.Restore
				LDA #$80
				STA !1540,x
			.ShowHP
				BRA DealNoDamage
			
		StompWigglerShowHP: ;>JSL from $02F26B
			.Restore
				LDA #$03
				STA $1DF9|!addr
			.ShowHP
				BRA DealNoDamage	;>Wiggler takes no damage, but still display HP.
		StompDryBonesBonyBeetle: ;>JSL from $01E5FE
			.Restore
				LDA #$FF
				STA !1540,x
				;They crumble, but it's better to assume no damage, much like Super Paper Mario
		DealNoDamage:
			%DealFixedDamage(0)
				RTL
		ZeroOutHPOfOneShotSprites:
			;For sprites that should not have HP (blacklisted), simply check if max HP == 0.
			;This code runs when sprites are instantly-killed via vanilla routines.
			;
			;Note: Make sure that $14C8 is not set to #$02 prior to calling this subroutine.
			LDA !Freeram_SpriteHP_MaxHPLow,x
			if !Setting_SpriteHP_TwoByte
				ORA !Freeram_SpriteHP_MaxHPHi,x
			endif
			BEQ .Done
			JSR IsKoopaShellEmpty
			BCS .Done
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
		StunnedKoopaShowHP: ;>JSL from $01AA14
			LDA !14C8,x			;\If enemy is stunned or already dying, don't force HP bar to this enemy.
			CMP #$08			;|
			BNE .Restore			;/
			.Display
				%DealFixedDamage(0)
			.Restore
				;We need the value of Y after this is done.
				if !Setting_SpriteHP_Koopas_ClassicBehavior != 0
					LDA #$FF
				else
					LDA #$02
				endif
				if !sa1 == 0
					LDY $9E,x
				else
					LDY !sprite_num_cache
				endif
				RTL
		if !Setting_SpriteHP_Koopas_ClassicBehavior == 0
			TransferHPFromKoopaToShelllessKoopa: ;>JSL from $0196F6
				;$15E9 = The index of the in-shell koopa/empty shell. $15E9 is also at this value.
				;X and Y = The index of newly spawned sprite - shell-less koopa
				.Restore
					JSL $07F7D2|!bank
				.SwitchMeter
					LDX $15E9|!addr
					JSL !SharedSub_SpriteHPGetSlotIndex
					TXA
					CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
					BNE .Done									;>If HP meter isn't on the enemy that the player just jumped on or is stunned in their shells and unstun themselves, skip
					TYA											;\Switch meter to the shell-less koopa (note that since these enemies have 1HP, we don't need bar animation)
					STA !Freeram_SpriteHP_MeterState			;/
					..TransferHPValues
						;This prevents an issue where if the player jumps on a winged koopa, then jumped on the now-transformed koopa, it wouldn't have its max HP reduced, causing the bar
						;to go from 50% to 100% because it went from 1/2HP to 1/1HP. This is done by transfering HP from the shell to the spawned shell-less koopa and making the shell to have 1/1HP
						JSR TransferHPBetweenKoopaAndShell
					
				.Done
					RTL
			TransferHPFromShelllessKoopaToKoopa: ;>JSL from $018ACC
				;X = Index of the shell-less koopa entering an empty shell. $15E9 is also at this value.
				;Y = Index of the shell the koopa is entering
				.SwitchMeter
					JSL !SharedSub_SpriteHPGetSlotIndex
					LDY !1594,x
					TXA
					CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
					BNE ..TransferHPValues						;>If the HP meter isn't on the shell-less koopa, skip (just transfer HP values)
					TYA											;\Switch meter to the shell (which will turn into a regular koopa)
					STA !Freeram_SpriteHP_MeterState			;/
					..TransferHPValues
						JSR TransferHPBetweenKoopaAndShell
				.Restore
					LDY !1594,x
					LDA.b #$10
					RTL
			TransferHPBetweenKoopaAndShell:
				;Input:
				; - Y: Sprite that the current sprite is interacting with or a newly spawned sprite to transfer HP to.
				LDX $15E9|!addr
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				TYX
				STA !Freeram_SpriteHP_CurrentHPLow,x
				LDX $15E9|!addr
				LDA !Freeram_SpriteHP_MaxHPLow,x
				TYX
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDX $15E9|!addr
					LDA !Freeram_SpriteHP_CurrentHPHi,x
					TYX
					STA !Freeram_SpriteHP_CurrentHPHi,x
					LDX $15E9|!addr
					LDA !Freeram_SpriteHP_MaxHPHi,x
					TYX
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
				LDX $15E9|!addr
				LDA #$01
				STA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA #$00
					STA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
				RTS
		endif
	endif
	if !Setting_ModifySprAndDisplayHPOfSMWSpr
		PokeyInitHP_YoshiHPTable:
			db $03, $05, $05		;>HP amounts based on riding yoshi. Indexed by $187A.
		PokeyInitHP: ;>JML from $018554
			.Restore ;>Y = Riding yoshi flag (for indexing) - #$00 = No, #$01-#$02 = Yes
				STA !C2,x
			.IndexHPBasedOnRidingYoshi
				PHB ;\We are indexing via Y, which cannot have a base address of 24-bits (LDA $xxxxxx,y does not exists)
				PHK ;|Thus we need to adjust the data bank so it reads the table at the correct address.
				PLB ;/
				LDA PokeyInitHP_YoshiHPTable,y
				STA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA #$00
					STA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
				PLB ;>Restore data bank.
			.BackToSMW
				JML $01857C|!bank
		PokeyLostSegment: ;>JSL from $02B80D
			PHY
			REP #$20
			LDA $00 ;>Prevent sprite flickering bug
			PHA
			SEP #$20
			%DealFixedDamage(0)
			;We are just calling the subroutine for 2 things: Switch HP meter, and meter animation.
			;We then adjust the HP based on the value of $C2, which tracks the pokey segments.
			;Like I said, because of a bug that causes pokey to not lose a segment but still spawn
			;a segment sprite when a thrown sprite hits the very top of the sprite, this would've
			;caused a desync between HP (HP decreases) and number of segments remaining (no segment
			;lost).
			.CountSegmentBits
				LDY #$00
				LDA !C2,x
				..Loop
					LSR
					BCC ...Next
					INY
					...Next
						CMP #$00		;>We compare A, not Y, thus CMP #$00 isn't redundant
						BNE ..Loop
				TYA
				STA !Freeram_SpriteHP_CurrentHPLow,x
			REP #$20
			PLA
			STA $00
			SEP #$20
			PLY
			.Restore
				LDA.w $02B829,y
				STA $0D
				RTL
	endif
	if and(!Setting_SpriteHP_RemoveOrApplyPatch, notequal(!Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundNumber, 0))
		PokeyThrownSprSfx: ;JSL from $02B7DB
			LDA.b #!Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundNumber
			STA !Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundPort
			.Restore
				LDA.w !D8,y
				SEC
				RTL
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
		ReznorIntroFill: ;>JML from $039872
			.IntroFill
				if !Setting_SpriteHP_TotalHPMode == 0
					JSL !SharedSub_SpriteHPIntroEffect
				else
					JSL !SharedSub_SpritesTotalHPIntroEffect
				endif
			.NoUnloadedSprites
				if !Setting_SpriteHP_TotalHPMode
					LDA #$00
					if !Setting_SpriteHP_TotalHPMode == 2
						STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites ;>There is never additional enemies during a Reznor fight yet to spawn.
					endif
					if !Setting_SpriteHP_TwoByte
						if !Setting_SpriteHP_TotalHPMode == 2
							STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1 ;\Rid high bytes
						endif
						STA !Freeram_SpriteHP_TotalMaxHP+1               ;/
					endif
					LDA #$04
					STA !Freeram_SpriteHP_TotalMaxHP
				endif
			.Restore
				CPX #$07
				BNE ..CODE_03987E
				JML $039876|!bank
				..CODE_03987E
					JML $03987E|!bank
		
		ReznorDead: ;>JSL from $039ABB
			PHX
			%DealFixedDamage(!SpriteHP_MaxHPAndDamageValue)
			PLX
			.Restore
				LDA #$03
				STA $1DF9|!addr
				RTL
		if !Setting_SpriteHP_TotalHPMode
			ReznorDefeatedClearHPMeter: ;>JSL from $0398E1
				LDA #$FF
				STA !Freeram_SpriteHP_MeterState
				.Restore
					LDA #$FF
					STA $1493|!addr
					RTL
		endif
	endif