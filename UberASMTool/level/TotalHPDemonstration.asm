;This simple ASM code tests the total HP system utilizing "!Freeram_SpriteHP_TotalHPOfUnloadedSprites".
;NOTE: Make sure the level using this ASM code is only 1-screen long, and should only contain and spawns
;sprites that cannot generate more sprites, and what it spawns are only killable sprites.
;
;In this example, it simply spawns 2 Chargin Chucks after the inital 2 Rexes and Chargin Chuck were killed.
;Assuming no options were changed on their HP amounts:
;Inital enemies:
; 2 Rexs: 2HP each (4HP for both)
; 1 Chuck: 15 HP
;After the inital enemies killed:
; 2 Chargin chucks: 15HP each (30HP for both)
;
;The result is 49 total HP. This should be for !StartingTotalHP. For counting enemies that will spawn later
;after the player kills, that is 30HP, which means !StartingHP_SpritesYetToLoad should be set to 30 (which
;will set the RAM !Freeram_SpriteHP_TotalHPOfUnloadedSprites to hold a value of 30).

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
;Some settings
	!StartingTotalHP #= (!Setting_SpriteHP_VanillaSprite_Rex_HPAmount*2)+(!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*3)
		;^Total HP. This includes sprite loaded, and sprite yet to load. With default settings, that should be 19.
	!StartingHP_SpritesYetToLoad = (!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*2)
		;^Total HP of sprites that have yet to spawn into the level.
	
	!RAM_HaveSpawnFlag = $1421|!addr ;>Reusing the 1-up checkpoint system, for demonstration purposes

macro Spawn(SpriteNumber, IsCustom, XPos, YPos, SpawnHealth)
	if <IsCustom> == 0
		CLC
	else
		SEC
	endif
	LDA.b #<SpriteNumber>
	LDX #!sprite_slots-1
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
	?SpawningHP:
		;Note: Not sure if the spawn sprite subroutine does utilize
		;SMW's $07F722-$07F78A. Just to be safe, I'll have the HP
		;initilization here anyways.
		LDA.b #<SpawnHealth>
		STA !Freeram_SpriteHP_CurrentHPLow,x
		STA !Freeram_SpriteHP_MaxHPLow,x
		if !Setting_SpriteHP_TwoByte
			LDA.b #<SpawnHealth>>>8
			STA !Freeram_SpriteHP_CurrentHPHi,x
			STA !Freeram_SpriteHP_MaxHPHi,x
		endif
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

init:
	LDA.b #!StartingHP_SpritesYetToLoad
	STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
	if !Setting_SpriteHP_TwoByte
		LDA.b #!StartingHP_SpritesYetToLoad>>8
		STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
	endif
	LDA.b #!StartingTotalHP
	STA !Freeram_SpriteHP_TotalMaxHP
	if !Setting_SpriteHP_TwoByte
		LDA.b #!StartingTotalHP>>8
		STA !Freeram_SpriteHP_TotalMaxHP+1
	endif
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
	
	LDA !RAM_HaveSpawnFlag
	BNE .Done
	
	LDX #!sprite_slots-1
	.Loop
		LDA !14C8,x
		BNE .ThereIsLoadedEnemy
		..Next
			DEX
			BPL .Loop
	.NoEnemiesExisted
		JSR HandleSpawning
	.ThereIsLoadedEnemy
	.Done
		PLB
		RTL
HandleSpawning:
	%Spawn($91, 0, $00E0, $0170, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
	%Spawn($91, 0, $0010, $0170, !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount)
	LDA #$10
	STA $1DF9|!addr
	INC !RAM_HaveSpawnFlag
	RTS