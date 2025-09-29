;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sprite Template
;;
;; Description: It's just a 16x16 custom sprite use for testing with the HP meter patch.
;;
;; NOTE: To make sure it does not use default interaction with other sprites, such as
;; fireball disappearing with or without killing/damaging the sprite, make sure $167A
;; bit 1 (i bit, Invincible to star/cape/fire/bouncing bricks) is set. This allows only
;; custom code to handle fireball and the new damage routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	;This stuff was here due to pixi have the SA-1 values in defines being renamed, so a transfer
	;was needed:
		!sa1 = !SA1		;>case sensitive.
		!sprite_slots = !SprSize
	incsrc "../SubroutineDefs.asm"
	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
	
	;Defines here for settings and values. A value without any prefixes (such as "$" or "%") are decimal.
	;If you want hex, use "$".
	
	!Setting_StompBounceBack	= 1	;>bounce player away when stomping: 0 = false, 1 = true.
	!Setting_DamagePlayer		= 1	;>0 = harmless, 1 = damage player on contact (besides stomping)
	
	!Setting_Heal_Cooldown			= 120		;>Heal cooldown, in frames (1/60th of a second). Up to 4.25 seconds (255 frames) of cooldown allowed.
	!Setting_Heal_SfxNumber			= $0A		;\sound effects played when healing.
	!Setting_Heal_SfxPort			= $1DF9|!Base2	;/
	!Setting_Damage_SfxNumber		= $28		;\Sound effect played when taking damage
	!Setting_Damage_SfxPort			= $1DFC|!Base2	;/
	;These below here are recovery and damages.
	;Make sure these numbers are not greater than SizeLimit, where SizeLimit is...
	; - 255 if you have !Setting_SpriteHP_TwoByte set to 0
	; - 65535 if !Setting_SpriteHP_TwoByte set to 1.
		!Setting_Heal_HPAmount		= 3	;>amount of HP recovered periodically (0 = no heal). The periods are on the following define.
		!Setting_StartingHP		= 100	;>Amount of HP the enemy has.
		!Setting_Damage_Stomp		= 5	;>Amount of damage from stomping.
		!Setting_Damage_PlayerFireball	= 3	;>Amount of damage from player's fireball.
		!Setting_Damage_YoshiFireball	= 25	;>Amount of damage from yoshi's fireball.
		!Setting_Damage_BounceBlock	= 15	;>Amount of damage from bounce blocks.
		!Setting_Damage_KickedSprite	= 6	;>Amount of damage from other sprites (shell, for example)
		!Setting_Damage_CapeSpin	= 4	;>Amount of damage from cape spin.
		!Setting_Damage_BobOmbExplosion	= 50	;>Amount of damage from Bob Omb explosions.
	
	
	!IntroFill		= 1		;>Boss intro fill (meter automatically switches to this sprite when it spawns): 0 = nom 1 = yes.

	;symbolic names for ram addresses
		!SPRITE_Y_SPEED		= !AA
		!SPRITE_X_SPEED		= !B6
		!SPRITE_STATE		= !C2
		!SPRITE_STATUS		= !14C8
		!InvulnerabilityTimer	= !1540		;>flashing animation + invulnerability timer.
		!SPR_OBJ_STATUS		= !1588
		!SPR_HealCooldown	= !1558
	;Misc
		!Setting_HPValueToShowCracked	= !Setting_StartingHP/2		;>HP to get below to start showing alternative graphics
		!Setting_TileNumber_EnoughHP			= $00
		!Setting_TileNumber_LowHP			= $02			;>16x16 tile to use when HP is below !Setting_HPValueToShowCracked.
		!Setting_Bobomb_ExplosionApothem		= $28			;>Explosion "apothem" (the length from the center of a square, which is the center of the Bob-omb sprite) to the midpoint of edges.
	
;Don't touch
	macro SpriteDamage()
		JSL !SharedSub_SpriteHPDamage
		if !Setting_Heal_HPAmount
			LDA.b #!Setting_Heal_Cooldown
			STA !SPR_HealCooldown,x
		endif
	endmacro
	
	macro SetHealCooldown()
		if !Setting_Heal_HPAmount
			LDA.b #!Setting_Heal_Cooldown
			STA !SPR_HealCooldown,x
		endif
	endmacro
	
	macro PlaySoundEffect(SoundNumber, SoundPort)
		if <SoundNumber> != $00
			LDA #<SoundNumber>
			STA <SoundPort>
		endif
	endmacro
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite init JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print "INIT ",pc
	Mainlabel:
	.StartWithFullHP
	LDA.b #!Setting_StartingHP		;\Full HP (low byte)
	STA !Freeram_SpriteHP_CurrentHPLow,x	;|
	STA !Freeram_SpriteHP_MaxHPLow,x	;/
	if !Setting_SpriteHP_TwoByte
		LDA.b #!Setting_StartingHP>>8		;\Full HP (High byte)
		STA !Freeram_SpriteHP_CurrentHPHi,x	;|
		STA !Freeram_SpriteHP_MaxHPHi,x		;/
	endif
	if !IntroFill
		JSL !SharedSub_SpriteHPIntroEffect
	endif
	RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sprite code JSL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SPRITE_CODE_START
	PLB
	RTL


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; main
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FootYpos:
	dw $0018,$0028,$0028
	if !Setting_StompBounceBack
		BouncePlayerAway:
			db $E0,$20 ;>Same as chargin chuck.
	endif

MainReturn:
	RTS
SPRITE_CODE_START:
	.BlinkIfInvulnerable
		LDA !InvulnerabilityTimer,x	;\Blink during invulnerability period (placed before
		BEQ ..NoBlink			;|$9D freeze check so it still shows during freeze)
		LDA $14				;|
		AND.b #%00000010		;|\2 frames show and 2 frames of no-show
		BNE ..NoGFX			;|/
		..NoBlink
			JSR SUB_GFX
		..NoGFX

	.FreezeCheck
		LDA $9D				;\Don't do anything during freeze.
		BNE MainReturn			;/
		LDA #$00
		%SubOffScreen()
	if !Setting_Heal_HPAmount
		.Healing
			LDA !Freeram_SpriteHP_CurrentHPLow,x			;\CMP is like SBC. if currentHP - MaxHP results an unsigned underflow (which causes a barrow; carry clear)
			CMP !Freeram_SpriteHP_MaxHPLow,x			;|then allow healing
			if !Setting_SpriteHP_TwoByte != 0
				LDA !Freeram_SpriteHP_CurrentHPHi,x
				SBC !Freeram_SpriteHP_MaxHPHi,x
			endif
			BCS ..FullHealth				;/>If HP is full, don't do healing effect.
			LDA !SPR_HealCooldown,x
			BNE ..HealDone
			LDA.b #!Setting_Heal_Cooldown
			STA !SPR_HealCooldown,x
			REP #$20					;\heal sprite
			LDA.w #!Setting_Heal_HPAmount			;|
			STA $00						;|
			SEP #$20					;|
			JSR Heal					;/
			if and(!Setting_SpriteHP_BarAnimation, notequal(!Setting_SpriteHP_BarChangeDelay, 0))
				LDA.b #!Setting_SpriteHP_BarChangeDelay
				STA !Freeram_SpriteHP_BarAnimationTimer
			endif
			if !Setting_Heal_SfxNumber != 0
				LDA #!Setting_Heal_SfxNumber
				STA !Setting_Heal_SfxPort
			endif
			BRA ..HealDone
			..FullHealth
				%SetHealCooldown()
			..HealDone
	endif
	JSR MainSpriteClipA		;>Get hitbox A of main sprite
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Mario contact (mainly jumping on this sprite)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithMario
		JSL $03B664|!bank			;>Get clipping with player (B).
		JSL $03B72B|!bank			;>Check contact
		BCS ..Contact
		JMP .NoContact			;>No interaction if not contacting.
		..Contact
	;------------------------------------------------------------------------------
	;Player touching sprite
	;------------------------------------------------------------------------------
	.Contact
		LDA !InvulnerabilityTimer,x	;\Don't drain-damage every frame during touch
		BEQ ..Contact
		JMP .NoContact			;/
		..Contact
		REP #$20
		LDA $00		;\Protect hitbox data
		PHA		;/
		SEP #$20
	
		LDA !14D4,x	;\Sprite Y positon 16-bit into $00-$01
		XBA		;|
		LDA !D8,x	;|
		REP #$20	;|
		STA $00		;/
		LDA $187A|!Base2	;\Positon of the player's bottommost hitbox depending on riding yoshi
		ASL			;|>Index times 2 because the positions are 2-bytes.
		TAY			;/
		LDA $96			;\The position where bottom hitbox feet is
		CLC			;|above the sprite (move down TOWARDS the sprite's Y pos).
		ADC FootYpos,y		;/
		CMP $00			;>Compare with sprite's y pos
		SEP #$20
		BMI ..MarioStomps	;>If mario is above, go to damage sprite

		..SpriteDamageMario
		if !Setting_DamagePlayer != 0
			LDA $187A|!addr
			BNE ...LoseYoshiInstead
			
			...DamageMario
				JSL $00F5B7|!bank		;>Hurt player by touching below/sides
				BRA ..Restore
			...LoseYoshiInstead
				%LoseYoshi()
		endif
		BRA ..Restore

		..MarioStomps
			LDA.b #10			;\Set timer to prevent multi-hit rapid stomping drain HP
			STA !InvulnerabilityTimer,x	;/(happens very easily when hitting sprites on top two corners).
			JSR ConsecutiveStomps
			REP #$20
			LDA.w #!Setting_Damage_Stomp		;\Amount of damage
			STA $00					;/
			SEP #$20
			JSL !SharedSub_SpriteHPDamage				;>Lose HP (handles bar animation and other effects). Note that this alone only subtracts HP, does not handle death sequence.
			%SetHealCooldown()
			LDA !Freeram_SpriteHP_CurrentHPLow,x	;\If HP != 0, don't kill
			if !Setting_SpriteHP_TwoByte
				ORA !Freeram_SpriteHP_CurrentHPHi,x	;|
			endif
			BNE ...NoDeath				;/
			JSR SpinjumpKillSprite			;>Kill sprite
			BRA ...SkipBouncePlayerAwayAndSfx

			...NoDeath
				if !Setting_StompBounceBack != 0
					LDY #$00
					LDA !E4,x		;\SpriteXPos - MarioXPos
					SEC			;|
					SBC $94			;|
					LDA !14E0,x		;|
					SBC $95			;/
					BPL ....MarioRight	;>mario is on the right side of the sprite
					....MarioLeft
						INY
					....MarioRight
					LDA BouncePlayerAway,y
					STA $7B
				endif
				%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)

			...SkipBouncePlayerAwayAndSfx
				LDA $15			;\Bounce at very different y speeds depending on holding jump or not.
				BPL ....NotHoldingJump	;/
				LDA #$A8
				BRA ....SetYSpd

				....NotHoldingJump
					LDA #$D0		;

				....SetYSpd
					STA $7D			;>Player shoots up

		..Restore
			REP #$20
			PLA		;\Restore hitbox
			STA $00		;/
			SEP #$20

	.NoContact
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;Extended sprite (Mario and Yoshi's fireball Contact)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.HitboxWithExtSpr
			LDY.b #10-1			;>There are 10 slots, numbered from 0 to 9.

			..Loop
				LDA $170B|!Base2,y	;>Extended sprite number
;				BEQ ...NextSlot		;>next if not-existent
				BNE +
				JMP ...NextSlot
				+
				CMP #$05		;\Player's fireball
				BEQ ...Fireball		;/
				CMP #$11		;\Yoshi's fireball after eating
				BEQ ...Fireball		;/a red shell
				BRA ...NextSlot		;>Others = next

				...Fireball
					JSR ExtSprFireballClipB	;>Get contact with current fireball ext spr slot.
					JSL $03B72B|!bank		;>Check contact between A and B.
					BCC ...NextSlot		;>No contact, check other extended sprite.
				...Contact
					;------------------------------------------------------------------------------
					;here is where the contact happens. Make sure that it goes to [...NextSlot]
					;so that in case if 2 fireballs contacts at the same frame, each will run this.
					;Y = current extended sprite slot.
					;------------------------------------------------------------------------------
					JSR CheckDamageIfZeroHPOrInvul
					BCC ...ExitLoop					;

					REP #$20
					LDA $00			;\Preserve $00 (used for contact checking, about to be used
					PHA			;/for damage value)
					SEP #$20

					LDA $170B|!Base2,y	;>Extended sprite number (do not clear it before reaching here)
					CMP #$05		;\Player's fireball
					BEQ ....PlayerFireball	;/
					CMP #$11		;\Yoshi's fireball
					BEQ ....YoshiFireball	;/
					JMP ...NextSlot

					....PlayerFireball
						REP #$20				;\Damage from player's fireball
						LDA.w #!Setting_Damage_PlayerFireball	;|
						STA $00					;|
						SEP #$20				;|
						BRA ....Damage				;/

					....YoshiFireball
						REP #$20				;\Damage from yoshi's fireball
						LDA.w #!Setting_Damage_YoshiFireball	;|
						STA $00					;|
						SEP #$20				;/

					....Damage
						LDA.b #10				;\Just to show the blinking and in case if projectile penetrates.
						STA !InvulnerabilityTimer,x		;/
						JSL !SharedSub_SpriteHPDamage				;>Lose HP
						%SetHealCooldown()
						LDA !Freeram_SpriteHP_CurrentHPLow,x		;\If HP != 0, don't kill
						if !Setting_SpriteHP_TwoByte
							ORA !Freeram_SpriteHP_CurrentHPHi,x		;|
						endif
						BNE .....NoDeath			;/
						JSR SpinjumpKillSprite			;>Make sprite die (sets !14C8,x and uses whats marked * to prevent executing multiple times).
						BRA .....SkipSfx

						.....NoDeath
							%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)

						.....SkipSfx
							REP #$20
							PLA			;\Restore hitbox data.
							STA $00			;/
							SEP #$20
							LDA #$01		;\Turn fireball into smoke the same way it interacts with enemies and solid blocks in vanilla.
							STA $170B|!Base2,y	;|
							LDA #$0F		;|
							STA $176F|!Base2,y	;/

				...NextSlot
					DEY			;>Next slot
					BMI ...ExitLoop		;\Loop until out of 0-9 (inclusive) range
					JMP ..Loop		;/
					...ExitLoop

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Bounce blocks
	;
	;Note to self: thankfully, they are mostly 16x16
	;shaped.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.HitboxWithBounceBlocks
		LDY.b #$04-1	;>There are 4 slots, numbered from 0 to 3.

		..Loop
			LDA $1699|!Base2,y	;\Non-existent bounce block = next slot
			BEQ ...NextSlot		;/

			CMP #$07		;\A spinning turn block does not hurt foes.
			BEQ ...NextSlot		;/

			...SpriteHit
				JSR BounceSprClipB	;>Get bounce sprite clipping into B.
				JSL $03B72B|!bank		;>Check contact between A and B.
				BCC ...NextSlot		;>No contact, check other extended sprite.
			...Contact
				;------------------------------------------------------------------------------
				;here is where the contact happens. Make sure that it goes to [...NextSlot]
				;so that in case if 2 bounce contacts at the same frame, each will run this.
				;Y = current bounce sprite slot.
				;------------------------------------------------------------------------------
				LDA !InvulnerabilityTimer,x		;\Prevent damaging sprite multiple frames
				BEQ ....RunBounceBlockDmg		;|during touching a bounce sprite.
				JMP .SkipBounceBlkDmg			;/

				....RunBounceBlockDmg	
					LDA.b #15			;\Prevent another damage on next frame
					STA !InvulnerabilityTimer,x	;/

					REP #$20
					LDA $00				;\Preserve hitbox data
					PHA				;/
					LDA.w #!Setting_Damage_BounceBlock	;\Damage from bounce blocks
					STA $00					;/
					SEP #$20
					JSL !SharedSub_SpriteHPDamage			;>Lose HP
					%SetHealCooldown()
					LDA !Freeram_SpriteHP_CurrentHPLow,x	;\If HP != 0, don't kill
					if !Setting_SpriteHP_TwoByte
						ORA !Freeram_SpriteHP_CurrentHPHi,x	;|
					endif
					BNE ....NoDeath			;/
					JSR SpinjumpKillSprite	;>Make sprite die
					BRA ....SkipSfx

				....NoDeath
					%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)
				....SkipSfx
					REP #$20
					PLA			;\Restore hitbox data
					STA $00			;/
					SEP #$20
				
			...NextSlot
				DEY			;>Next slot
				BPL ..Loop		;>Loop if there is another slot to run, otherwise terminate

	.SkipBounceBlkDmg
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;Other (normal/main) sprites.
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithOtherSpr
		LDY.b #!sprite_slots-1		;There are 12 slots in LoROM (ranging from 0 to 11), or 22 in SA-1 (ranging from 0 to 21).

		..Loop
			TYA			;\Don't interact with its own slot/self.
			CMP $15E9|!Base2	;|
			BNE +
			JMP ...NextSlot		;/>branch distance limit.

			+
			LDA !14C8,y		;>Sprite state
			CMP #$08		;\No interaction on non-existent sprite and any form of death sprite.
			BCC ...No
			CMP #$0B
			BCS ...No
			BRA ...ValidStates
			...No
				JMP ...NextSlot		;>Powerup from goal as well as invalid states.
			...ValidStates
				JSR MainSpriteClipA		;>Get hitbox A of main sprite
				....BobOmbExplosionCheck
					LDA !9E,y
					CMP #$0D				;\Other than bob-omb
					BNE ....NonExplosionSprites		;/
					LDA !7FAB10,y				;\Is custom sprite
					BIT.b #%00001000			;|
					BNE ....NonExplosionSprites		;/
					LDA !1534,y				;\Is exploding
					BNE ....ExplosionSprite			;/
				....ExplodePrematurely
					LDA !14C8,y
					CMP #$08
					BNE +
					JMP ...NextSlot
					+
					;If hit directly with a Bob-omb before it exploded, make it explode immediately
					JSR CarryableKickedClipB
					JSL $03B72B|!bank			;>Check for contact
					BCS +
					JMP ...NextSlot
					+
					LDA #$01				;\Explode early
					STA !1534,y				;|
					LDA #$40				;|
					STA !1540,y				;/>Explosion timer
					LDA #$08				;\Make it a normal routine
					STA !14C8,y				;/
					JMP ...NextSlot				
				....ExplosionSprite
					LDA.b #!Setting_Bobomb_ExplosionApothem
					STA $8B
					%GetBobOmbClippingB()
					JSL $03B72B|!bank
					BCS +
					JMP ...NextSlot
					+
					.....ExplosionContact
						JSR CheckDamageIfZeroHPOrInvul
						BCS +
						JMP ...NextSlot
						+
						......Damage
							LDA.b #90				;>invulnerability timer must be long enough to avoid multiple hits from the same explosion.
							STA !InvulnerabilityTimer,x
							if !Setting_SpriteHP_TwoByte
								REP #$20
								LDA.w #!Setting_Damage_BobOmbExplosion
								STA $00
								SEP #$20
							else
								LDA.b #!Setting_Damage_BobOmbExplosion
								STA $00
							endif
							JSL !SharedSub_SpriteHPDamage			;>Lose HP
							%SetHealCooldown()
							LDA !Freeram_SpriteHP_CurrentHPLow,x	;\If HP != 0, don't kill
							if !Setting_SpriteHP_TwoByte
								ORA !Freeram_SpriteHP_CurrentHPHi,x	;|
							endif
							BNE ......NoDeath			;/
							
							......Death
								JSR SpinjumpKillSprite
								BRA ...NextSlot
							......NoDeath
								%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)
							
				....NonExplosionSprites
					JSR CarryableKickedClipB		;>You may need to change this if you have sprites other than "16x16" dimension.
				....CheckContact
					JSL $03B72B|!bank			;>If sprite B hits this sprite
					BCC ...NextSlot
			...Contact
				;------------------------------------------------------------------------------
				;here is where the contact happens. Make sure that it goes to [...NextSlot] so
				;that in case if 2 bounce contacts at the same frame, each will run this. 
				;
				;Y = current bounce sprite slot.
				;------------------------------------------------------------------------------
				JSR CheckDamageIfZeroHPOrInvul
				BCC ...ExitLoop				;/
			
				;Accepts states #$08 to #$0B here. My following example only includes carryable/kicked to damage.
				LDA !14C8,y			;\only allow kicked/carryable sprites
				CMP #$09			;|
				BEQ ....CarryableKickedSpdChk	;|
				CMP #$0A			;|
				BEQ ....CarryableKickedSpdChk	;/
				BRA ...NextSlot			;>check next slot
			
				....CarryableKickedSpdChk
					.....XSpeed
						LDA !B6,y		;\If X speed already positive, don't flip
						BPL ......Positive	;/
						EOR #$FF		;\Invert speed (absolute value)
						INC			;/

						......Positive
							CMP #$08		;\If absolute speed bigger than #$08, hurt boss
							BCS ...Damage		;/if not, check other speed

					.....YSpeed
						LDA !AA,y		;\If Y speed already positive, don't flip
						BPL ......Positive	;/
						EOR #$FF		;\Invert speed (absolute value)
						INC			;/

						......Positive
							CMP #$08		;\If absolute speed less than #$08 on both, 
							BCC ...NextSlot		;/no damage/interaction

			...Damage
				LDA.b #10			;\flashing animation
				STA !InvulnerabilityTimer,x	;/
				if !Setting_SpriteHP_TwoByte
					REP #$20
					LDA.w #!Setting_Damage_KickedSprite	;\The damage
					STA $00					;/
					SEP #$20
				else
					LDA.b #!Setting_Damage_KickedSprite
					STA $00
				endif
				JSL !SharedSub_SpriteHPDamage			;>Lose HP
				%SetHealCooldown()
				LDA !Freeram_SpriteHP_CurrentHPLow,x	;\If HP != 0, don't kill
				if !Setting_SpriteHP_TwoByte
					ORA !Freeram_SpriteHP_CurrentHPHi,x	;|
				endif
				BNE ....NoDeath			;/
				JSR SpinjumpKillSprite
				BRA ....SkipSfx

				....NoDeath
					%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)
				....SkipSfx
					LDA #$02			;\Kill sprite (falling down screen).
					STA !14C8,y			;/
					LDA #$C8			;\Make it jump up before falling.
					STA !AA,y			;/
	
					.....XSpeedDeflect
						LDA !B6,y			;\same speed as smw's
						BMI ......Leftwards
						......Rightwards
							LDA #$F0
							BRA +
						......Leftwards
							LDA #$10
							+
							STA !B6,y

			...NextSlot
				DEY
				BMI ...ExitLoop			;>long way up that branches cannot jump that far.
				JMP ..Loop

			...ExitLoop
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Cape spin
	;
	;Probably the first non-instant-kill damage and not a stun from a
	;cape spin. 
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.HitboxWithCapeSpin
		LDA !InvulnerabilityTimer,x	;\Don't damage multiple frames after the first hit.
		BNE ..NoCapeHit			;/

		JSR CapeClipB		;>Get cape's hitbox
		BCC ..NoCapeHit		;>If cape spin non-existent, don't assume it exist
		JSL $03B72B|!bank	;>Check if cape's hitbox hits this current sprite
		BCC ..NoCapeHit		;>If box A and B not touching, don't assume touching.
		..Contact
			;------------------------------------------------------------------------------
			;here is where the contact happens. Since there is only one cape and not being
			;a slot, a loop isn't necessary and you don't need to go to [...NextSlot] when
			;its done.
			;------------------------------------------------------------------------------
			LDA #$08			;\Make sprite invulnerable the inital hit.
			STA !InvulnerabilityTimer,x	;/
			REP #$20
			LDA $00				;\$00 going to be used as damage instead of hitbox-related
			PHA				;/
			LDA.w #!Setting_Damage_CapeSpin		;\Amount of damage
			STA $00					;/
			SEP #$20
			JSL !SharedSub_SpriteHPDamage		;>Lose HP
			%SetHealCooldown()
			LDA !Freeram_SpriteHP_CurrentHPLow,x	;\If HP != 0, don't kill
			if !Setting_SpriteHP_TwoByte
				ORA !Freeram_SpriteHP_CurrentHPHi,x	;|
			endif
			BNE ...NoDeath			;/
			JSR SpinjumpKillSprite
			BRA ...SkipSfx

			...NoDeath
				%PlaySoundEffect(!Setting_Damage_SfxNumber, !Setting_Damage_SfxPort)

			...SkipSfx
				REP #$20
				PLA				;\Restore hitbox data
				STA $00				;/
				SEP #$20

				..NoCapeHit ;>You must have this in existent though.
				RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GENERIC GRAPHICS ROUTINE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SUB_GFX:
	;JSR GET_DRAW_INFO	; after: Y = index to sprite OAM ($300)
				;  $00 = sprite x position relative to screen boarder 
				;  $01 = sprite y position relative to screen boarder  
				
	%GetDrawInfo()

	LDA $00			; set x position of the tile
	STA $0300|!Base2,y

	LDA $01			; set y position of the tile
	STA $0301|!Base2,y

	if !Setting_SpriteHP_TwoByte
		LDA !Freeram_SpriteHP_CurrentHPHi,x
		XBA
		LDA !Freeram_SpriteHP_CurrentHPLow,x
		REP #$20
		CMP.w #!Setting_HPValueToShowCracked
		SEP #$20
		BCS .HighHP
		;LowHP
		LDA #!Setting_TileNumber_LowHP
		BRA .SetTile
	else
		LDA !Freeram_SpriteHP_CurrentHPLow,x
		CMP.b #!Setting_HPValueToShowCracked
		BCS .HighHP
		LDA #!Setting_TileNumber_LowHP
		BRA .SetTile
	endif
	
	.HighHP:
		LDA #!Setting_TileNumber_EnoughHP
	.SetTile
		STA $0302|!Base2,y

	LDA !15F6,x		; get sprite palette info
	ORA $64			; add in the priority bits from the level settings
	STA $0303|!Base2,y	; set properties

	LDY #$02		; #$02 means the tiles are 16x16
	LDA #$00		; This means we drew one tile
	JSL $01B7B3|!bank
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;My own routines here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckDamageIfZeroHPOrInvul:
	;Carry: Set if damage should be allowed, otherwise clear (don't take damage).
	LDA !Freeram_SpriteHP_CurrentHPLow,x		;\If HP is already 0 and another sprite within the same frame
	if !Setting_SpriteHP_TwoByte
		ORA !Freeram_SpriteHP_CurrentHPHi,x		;|hits this boss, make it ignore the boss (pass through already-dead boss)
	endif
	BEQ .ZeroHP
	LDA !InvulnerabilityTimer,x
	BEQ .NotInvulnerable
	
	.ZeroHP
		CLC
		RTS
	.NotInvulnerable
		SEC
		RTS

MainSpriteClipA:
;Get the main sprite's hitbox in A. NOTE: hitbox is actually 12x12 centered.
	LDA !E4,x	;\X position
	CLC		;|
	ADC #$02	;|
	STA $04		;|
	LDA !14E0,x	;|
	ADC #$00	;|
	STA $0A		;/
	LDA !D8,x	;\Y position
	CLC		;|
	ADC #$02	;|
	STA $05		;|
	LDA !14D4,x	;|
	ADC #$00	;|
	STA $0B		;/
	LDA #$0C	;\Hitbox width and height
	STA $06		;|
	STA $07		;/
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ExtSprFireballClipB:
;Gets the clipping of an extended sprite's hitbox into B.
	LDA $171F|!Base2,y	;\X position
	STA $00			;|
	LDA $1733|!Base2,y	;|
	STA $08			;/
	LDA $1715|!Base2,y	;\Y position
	STA $01			;|
	LDA $1729|!Base2,y	;|
	STA $09			;/

	.DifferentSize		
	LDA $170B|!Base2,y		;\Determine the shape of hitbox
	CMP #$05		;|depending on its extended sprite number
	BEQ ..PlayerFireball	;|
	CMP #$11		;|
	BEQ ..YoshiFireball	;|
	BRA .done		;/

	..PlayerFireball
	LDA #$08
	BRA ..SetSize

	..YoshiFireball
	LDA #$10

	..SetSize
	STA $02
	STA $03

	.done
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BounceSprClipB:
;Gets the clipping of a bounce sprite hitbox into B
	LDA $16A5|!Base2,y	;\X position
	STA $00			;|
	LDA $16AD|!Base2,y	;|
	STA $08			;/
	LDA $16A1|!Base2,y	;\Y position
	STA $01			;|
	LDA $16A9|!Base2,y	;|
	STA $09			;/

	LDA #$10	;\#$10 by #$10 (16x16) hitbox.
	STA $02		;|
	STA $03		;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CarryableKickedClipB:
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
CapeClipB:
;Gets the clipping of a cape spin. I highly recommend using
;"Cape Layer 2 Position Fix" from the patch section to prevent a bug where
;the cape's interaction would "escape from the player" and flies off from
;the player in layer 2 levels during a freeze (setting $7E009D).
;
;output:
;Carry = clear if non-existent (like not doing a cape spin at all).
	LDA $13E8|!Base2	;\If interact flag is off, no hitbox.
	BEQ .NoCapeHitbox	;/
	LDA !15D0,x		;>If current sprite is about to be eaten...
	ORA !154C,x		;>Or if contact is disabled
	ORA !1FE2,x		;>Or if timer of no interaction via cape is running
	BNE .NoCapeHitbox	;>Then mark as no hitbox
	LDA !1632,x		;>Sprite scenery flag
	PHY			;>Preserve Y
	LDA $74			;\If not climbing, skip
	BEQ .NotClimbing	;/
	EOR #$01		;>Invert climbing flag?

	.NotClimbing
	PLY
	EOR $13F9|!Base2	;>Flip player behind layers flag
	BNE .NoCapeHitbox	;>If sprite and mario not on the same side of net, no hitbox.
	;JSL $03B69F|!bank		;>Get contact for current sprite (not needed)

	.GetCapeHitbox
	LDA $13E9|!Base2	;\From the spinning cape's x position, move 2 pixels left...
	SEC			;|
	SBC #$02		;/
	STA $00			;>...And set hitbox x position
	LDA $13EA|!Base2	;\Same thing but high byte x position
	SBC #$00		;|
	STA $08			;/
	LDA #$14		;\Hitbox width (#$14 (20) pixels wide)
	STA $02			;/
	LDA $13EB|!Base2	;\Y position of the top of the cape's hitbox
	STA $01			;|
	LDA $13EC|!Base2	;|
	STA $09			;/
	LDA #$10		;\Hitbox height (#$10 (16) pixels tall)
	STA $03			;/
	SEC			;>Set carry.
	RTS

	.NoCapeHitbox
	CLC			;>Clear carry.
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StompSounds:
	db $00,$13,$14,$15,$16,$17,$18,$19 ;>The SFX for each pitch.

ConsecutiveStomps:
;A routine that each time you jump on an enemy without touching the ground
;displays (increasing) points as well as increasing the consecutive stomps
;counter ($1697).
	PHY
	LDA $1697|!Base2
	CLC			;\Add by Consecutive enemies killed by a sprite (how kicked shells
	ADC !1626,x		;/continue the counter if you stop it after killing many enemies)
	INC $1697|!Base2	;>Increase it again (so it increase by a value that is AT LEAST 1)(won't write to A).
	TAY			;>Transfer it to Y for each sounds and score.
	INY			;>Don't know why nintendo would increase it again for some reason...
	CPY #$08		;\If after the last sound pitch (and a score of 8000),
	BCS .NoSound		;/replace with 1-up.
	LDA StompSounds,y	;\Play stomp sounds with different pitches
	STA $1DF9|!Base2	;/depending on the consecutive stomp counter.

	.NoSound
		TYA			;>Transfer back to A
		CMP #$08		;\Now I know why it uses INY above, basicaly so that the original value would make 
		BCC .NoReset		;/this assume always #$08 or #$07. Here, this caps to prevent 256 stomps overflow.
		LDA #$08		;>Load maximum value

	.NoReset
		PHX
		JSL $02ACE5|!bank		;>Give points (200, 400, 800, 1000, 2000, 4000, 8000, 1-up.)
		PLX
		PLY
		RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SpinjumpKillSprite:
;Makes sprite die as if they were spinjumped.
;NOTE: ALL extended sprites are killable by cape, even the 4 stars.

	LDA #$04		;\Kill the sprite as if spin-jumping it.
	STA !14C8,X		;|
	LDA #$1F		;|
	STA !1540,X		;|
	PHY			;|>Y was used for other extended sprite
	JSL $07FC3B|!bank		;|
	PLY			;|>Restore it
	LDA #$08		;|
	STA $1DF9|!Base2	;/
	RTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Capped healing routine.
;
;Input:
;-$00-$01 is the amount of HP recovered. Only $00
; would be used should two-byte HP was set to 1
; byte.
;Output:
;-Sprite's current HP recovered, capped at max.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Heal:
	.StoreHealedValue
	if !Setting_SpriteHP_TwoByte != 0 ;>maths are different depending if you wanted 2-byte HP or not.
		LDA !Freeram_SpriteHP_CurrentHPLow,x	;\low byte
		CLC					;|
		ADC $00					;|>ADC sets carry if unsigned overflow happens
		STA $00					;/
		LDA !Freeram_SpriteHP_CurrentHPHi,x	;\high byte
		ADC $01					;|>ADC adds an additional 1 when overflowed
		STA $01					;/
		BCS .Maxed				;>if exceeds 65535

		.CompareWithMaxHP
			LDA $00					;\CMP is like SBC, should underflow happens, carry is clear
			CMP !Freeram_SpriteHP_MaxHPLow,x		;/HealedHPLow - MaxHPLow: carry is cleared if MaxHPLow is bigger
			LDA $01					;\should the above carry is clear, subtract by an additional 1 (4-5 becomes 4-6; borrow)
			SBC !Freeram_SpriteHP_MaxHPHi,x		;/HealedHPHi - MaxHPHi: carry is cleared if MaxHPHi is bigger
			BCC .ValidHP				;>if carry clear (below/equal to max HP), set current HP to healed HP amount.

		.Maxed
			LDA !Freeram_SpriteHP_MaxHPLow,x		;\Set HP to max when carry is set (CurrentHP - MaxHP = positive value)
			STA !Freeram_SpriteHP_CurrentHPLow,x		;|
			LDA !Freeram_SpriteHP_MaxHPHi,x		;|
			STA !Freeram_SpriteHP_CurrentHPHi,x		;/
			RTS

		.ValidHP
			LDA $00					;\Set HP to the amount of HP after healed.
			STA !Freeram_SpriteHP_CurrentHPLow,x		;|
			LDA $01					;|
			STA !Freeram_SpriteHP_CurrentHPHi,x		;/
	else ;>when using single-byte HP
		LDA !Freeram_SpriteHP_CurrentHPLow,x		;\get HP after being healed
		CLC					;|
		ADC $00					;/
		BCS .Maxed				;>in case HP goes past 255 when max HP is 255.
		CMP !Freeram_SpriteHP_MaxHPLow,x		;\if over the max, cap it also.
		BCS .Maxed				;/
		BRA .ValidHP
		
		.Maxed
			LDA !Freeram_SpriteHP_MaxHPLow,x
		
		.ValidHP
			STA !Freeram_SpriteHP_CurrentHPLow,x
	endif
	RTS