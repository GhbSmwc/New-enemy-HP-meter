;This simple ASM code tests the total HP system utilizing "!Freeram_SpriteHP_TotalHPOfUnloadedSprites",
;by simulating an ambush system. This will make the meter show the total HP for sprites currently loaded,
;and the enemies yet to spawn in the level.
;
;A test level file is provided, for level 106 (Yoshi's Island 2), as seen in
;"LM stuff/Levels/Level_106_TotalHPTest.mwl". You just need to have this file
;be placed in uberasm tool's level folder (and make sure the defines are placed
;in where the .exe program is at).
;
;This only supports levels being 1-screen long, enemies cannot disappear off-screen, and enemies that
;cannot spawn an enemy that have health.
;
;In this example, the level should play out like this:
; - Initally the player spawns in the level, and have these enemies (placed in LM):
; -- 2 Rexes, and 1 Chargin chuck. Assuming you make no changes on how much HP they have,
;    the total HP of these existing enemies should be 19HP.
; - After the player defeats all enemies, 2 Chargin Chucks should spawn in. Again,
;   assuming you didn't change their HP values, the total HP should be 30HP.
; - After that, it only spawns a goomba and a shell-less blue koopa, having 2 HP
; Adding up all their HP values, that should be 51HP.
;
;This means:
; - The value stored in RAM defined as !Freeram_SpriteHP_TotalMaxHP should be 51, counting all enemies.
; - The value stored in RAM defined as !Freeram_SpriteHP_TotalHPOfUnloadedSprites should be 32, before
;   the first wave was defeated, counting all enemies that are yet to spawn in to the end.
;
; - If there were another set of enemies to spawn after 2 chucks, say 2 shell-less koopas 1HP each, then
;   !Freeram_SpriteHP_TotalHPOfUnloadedSprites should have those additional enemuies accounted for,
;   in this case, 32 (Chuck's 30 HP, plus 2 HP of the koopas after), and !Freeram_SpriteHP_TotalMaxHP
;   to be set to 51 (4 HP of the 2 rexes, plus 45 HP of the 3 Chargin chucks, plus 2 HP of the 2 koopas).
;   Note that you need to add another phase by editing this ASM file yourself.
;
;
;This is a test ASM, not meant to be used in an actual game (not well optimized, espically if you're
;spawning lot of sprites, which adds code overhead), rather as a tutorial on how to get your custom
;ambush system to work with this total HP system.

;Don't touch
	incsrc "../SharedSubroutineDefs.asm"
	incsrc "../StatusBarDefines.asm"
	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
	incsrc "../NumberDisplayRoutinesDefines.asm"

	assert !Setting_SpriteHP_TotalHPMode == 2, "This test ASM code requires the total HP system."
	assert !Setting_SpriteHP_VanillaSprite_OneShotSprites != 0, "This test ASM code requires HP for 1-shot sprites."
;Some settings
	!StartingTotalHP #= (!Setting_SpriteHP_VanillaSprite_Rex_HPAmount*2)+(!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*3)+2
		;^Total HP. This includes sprite loaded, and sprite yet to load. With default settings, that should be 19.
	!StartingHP_SpritesYetToLoad = (!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*2)+2
		;^Total HP of sprites that have yet to spawn into the level.
	
	!RAM_HaveSpawnFlag = $1421|!addr ;>Reusing the 1-up checkpoint system.
	!RAM_HaveSpawnFlag2 = $1436|!addr ;>Reusing the RAM that, when used in a normal level, only by keyholes.

macro Spawn(SpriteNumber, IsCustom, XPos, YPos, SpawnHealth)
	if <IsCustom> == 0
		CLC
	else
		SEC
	endif
	LDA.b #<SpriteNumber>
	LDX #!sprite_slots-3
		;^Let me explain why !sprite_slots-3 instead of !sprite_slots-1. The fireballs thrown by the
		; player does not interact with sprites on the last 2 slots. Meaning LoROM, only $00-09 of
		; the $00-$0B slots are consitered. In SA-1 however, only $00-$13 of the $00-$15 slots are
		; checked. The last 2 sprite slots are consitered "important" sprites that are spawned
		; uniquely such as when dropped from the item box, or from blocks.
	%UberRoutine(SpawnSprite)
	BCS ?No
	
	?XYPos:
		LDA.b #<XPos>
		STA !sprite_x_low,x
		LDA.b #<XPos>>>8
		STZ !sprite_x_high,x
		LDA.b #<YPos>
		STA !sprite_y_low,x
		LDA.b #<YPos>>>8
		STA !sprite_y_high,x
	?DeductHPOfUnloaded:
		;Here, every time you spawn a sprite, you need to, within that
		;frame of spawning the sprite, deduct the value in
		;!Freeram_SpriteHP_TotalHPOfUnloadedSprites by how much HP
		;that spawned sprite has, else the meter fills upward because
		;a sprite went from not being loaded, to now being loaded
		;without "taking its health with it".
		LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		SEC
		SBC.b #<SpawnHealth>
		STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		if !Setting_SpriteHP_TwoByte
			LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
			SBC.b #<SpawnHealth>>>8
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
		endif
	?No:
endmacro
macro IgnoreSprite(SpriteNumber)
	CMP.b #<SpriteNumber>
	BEQ .NotACountedEnemy
endmacro

macro IgnoreSprite_Unlimited(SpriteNumber)
	CMP.b #<SpriteNumber>
	BNE ?+
	JMP .NotACountedEnemy
	?+
endmacro

macro IgnoreSpriteRange(MinSpriteNumber, MaxSpriteNumber)
	assert <MinSpriteNumber> <= <MaxSpriteNumber>, "Ignore sprite number min is greater than max."
	CMP.b #<MinSpriteNumber>
	BCC ?OutOfRange
	if (<MaxSpriteNumber>+1) < $FF
		CMP.b #<MaxSpriteNumber>+1
		BCS ?OutOfRange
	endif
	BRA .NotACountedEnemy
	?OutOfRange:
endmacro

init:
	;This gets the HP of all enemies yet to spawn
		LDA.b #!StartingHP_SpritesYetToLoad
		STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		if !Setting_SpriteHP_TwoByte
			LDA.b #!StartingHP_SpritesYetToLoad>>8
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
		endif
	;This gets the total HP of all enemies, current enemies placed in LM, and all enemies yet to spawn
		LDA.b #!StartingTotalHP
		STA !Freeram_SpriteHP_TotalMaxHP
		if !Setting_SpriteHP_TwoByte
			LDA.b #!StartingTotalHP>>8
			STA !Freeram_SpriteHP_TotalMaxHP+1
		endif
	;Make meter to be "total mode" and intro-fill mode
		LDA.b #(!sprite_slots*2)+1
		STA !Freeram_SpriteHP_MeterState
		if !Setting_SpriteHP_BarAnimation
			;Introfill mode.
			LDA #$00
			STA !Freeram_SpriteHP_BarAnimationFill
			if !Setting_SpriteHP_BarChangeDelay
				STA !Freeram_SpriteHP_BarAnimationTimer
			endif
		endif
	RTL
main:
	if !sa1
		%invoke_sa1(.RunSA1)
		RTL
		.RunSA1
	endif
	PHB
	PHK
	PLB
		
	JSR SearchSprites
	CPX #$FF
	BNE .No ;>If there are enemies remaining, don't advance
	
	INC !RAM_HaveSpawnFlag ;>Advance a wave
	
	.No
	
	;This checks if the next ambush have been triggered. This is to ensure that
	;spawning sprites should not happen consecutive/every frames.
		LDA !RAM_HaveSpawnFlag
		CMP !RAM_HaveSpawnFlag2
		BEQ .Done
		STA !RAM_HaveSpawnFlag2
		
	;Play out the current wave
		JSR HandleSpawning

	.Done
		PLB
		RTL
HandleSpawning:
	LDA $1493|!addr
	BNE .AlreadyFinished
	LDA !RAM_HaveSpawnFlag
	CMP.b #((.Spawns_ListEnd-.Spawns)/2)+1	;\Prevent jumping to data that isn't a pointer that crashes the game.
	BCC .NotTheEnd							;/
	LDA #$FF
	STA $1493|!addr
	STA $13C6|!addr
	STA !Freeram_SpriteHP_MeterState
	
	.AlreadyFinished
	RTS
	
	.NotTheEnd
		LDA #$10			;\Sound effect when spawning enemies
		STA $1DF9|!addr		;/
		LDA.b #120			;\Make player invulnerable due to potential risks of spawning enemies on the player.
		STA $1497|!addr		;/
		LDA !RAM_HaveSpawnFlag
		ASL
		TAX
		JMP (.Spawns-2,x)
		
		.Spawns:
			dw ..Wave1
			dw ..Wave2
			..ListEnd
			..Wave1
				%Spawn($91, 0, $00E0, $0170, 15)
				%Spawn($91, 0, $0010, $0170, 15)
				RTS
			..Wave2
				%Spawn($0F, 0, $00E0, $0170, 1)
				%Spawn($02, 0, $0010, $0170, 1)
				RTS
SearchSprites:
	;This checks if there is an enemy in the sprite slots. Used to determine if the player killed all
	;of them.
	;
	;Output:
	; - X: $FF indicates there are no enemies. If any positive value, then there are and is the
	;   index of an existing enemy sprite at the highest index.
	;
	LDX #!sprite_slots-1
	.Loop
		;Loop every sprite slot, checking if all sprite slots are empty.
		LDA !14C8,x
		CMP #$07
		BCC ..Next
		CMP #$0C
		BCC ..Check
		BRA ..Next
		..Check
			JSR CheckIfEnemyExists
			BCS .EnemyExists
		..Next
			DEX
			BPL .Loop
	.EnemyExists
		RTS
	
CheckIfEnemyExists:
		;Add a check here to filter out not-applicable enemies here, similarly to how
		;".CheckForBlacklistedSprites" to ignore certain sprites.
		;
		;Syntax:
		; %IgnoreSprite(SpriteNumber)
		; %IgnoreSprite_Unlimited(SpriteNumber) ;>Use this if you have branch-out-of-bounds error.
		; %IgnoreSpriteRange(MinSpriteNumber, MaxSpriteNumber)
		;
		; The sprite number entered here is the ID of a sprite not counted as an enemy.
		;
		;Output:
		; - Carry: Clear if not an enemy (to ignore), otherwise set.
		if !Setting_SpriteHP_UsingCustomSprites
			LDA !7FAB10,x
			AND.b #%00001000
			BEQ .VanillaSMWSpr
			.CustomSpr
				LDA !7FAB9E,x
				;Put your list here for custom sprites
				
				;Don't touch this tough
					JMP .CountedEnemy
		endif
		.VanillaSMWSpr
			LDA !9E,x
			;Put your list here for vanilla sprites
			%IgnoreSprite($B9) ;>Message block
			%IgnoreSprite($21) ;>Moving coin
			;Don't touch this tough
				JMP .CountedEnemy
		.NotACountedEnemy
			CLC
			RTS
		.CountedEnemy
			SEC
			RTS