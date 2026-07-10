;This simple ASM code tests the total HP system utilizing "!Freeram_SpriteHP_TotalHPOfUnloadedSprites".
;NOTE: Make sure the level using this ASM code is only 1-screen long, and should only contain and spawns
;sprites that cannot generate more sprites, and what it spawns are only killable sprites.
;
;In this example, it simply spawns a single Chargin Chuck after 2 Rexes were killed. Assuming no options
;were changed on their HP amounts:
; 2 Rexs: 2HP each (4 HP for both)
; 1 Chargin chuck: 15 HP
; Total: 19 HP.

;This is a test ASM, not meant to be used in an actual game, rather as a tutorial on how to get your
;custom ambush system to work.

;Don't touch
	incsrc "../SharedSubroutineDefs.asm"
	incsrc "../StatusBarDefines.asm"
	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
	incsrc "../NumberDisplayRoutinesDefines.asm"

	assert !Freeram_SpriteHP_TotalMaxHP == 2, "This test ASM code requires total HP system."
;Some settings
	!StartingTotalHP #= (!Setting_SpriteHP_VanillaSprite_Rex_HPAmount*2)+!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
		;^Total HP. This includes sprite loaded, and sprite yet to load. With default settings, that should be 19.
	!StartingHP_SpritesYetToLoad = !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
		;^Total HP of sprites that have yet to spawn into the level.
	;Spawn XY position of a chargin chuck after all previous enemies not exists.
		!SpriteSpawnXPos = $00E0
		!SpriteSpawnYPos = $0170
	
	!RAM_HaveSpawnFlag = $1421|!addr ;>Reusing the 1-up checkpoint system, for demonstration purposes

init:
	LDA.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
	STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
	if !Setting_SpriteHP_TwoByte
		LDA.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount>>8
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
	.ThereIsNoLoadedEnemy
		..SpawnASprite
			LDA #$91			;>Chargin chuck
			CLC
			LDX #!sprite_slots-1
			%UberRoutine(SpawnSprite)
			...SoundEffect
				LDA #$10
				STA $1DF9|!addr
			...SetXYPos
				LDA.b #!SpriteSpawnXPos
				STA !sprite_x_low,x
				LDA.b #!SpriteSpawnXPos>>8
				STZ !sprite_x_high,x
				LDA.b #!SpriteSpawnYPos
				STA !sprite_y_low,x
				LDA.b #!SpriteSpawnYPos>>8
				STA !sprite_y_high,x
			...SetItsHP
				;Note: The spawn sprite subroutine does NOT utilize SMW's $07F722-$07F78A,
				;thus its HP values are not initalized (garbage values).
				LDA.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
				STA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_MaxHPLow,x
				if !Setting_SpriteHP_TwoByte
					LDA.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount>>8
					STA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_MaxHPHi,x
				endif
			...DeductHPBecauseItIsLoaded
				;Here, every time you spawn a sprite, you need to, within that
				;frame of spawning the sprite, deduct the value in
				;!Freeram_SpriteHP_TotalHPOfUnloadedSprites by how much HP
				;that spawned sprite has, else the meter fills upward because
				;a sprite went from not being loaded, to now being loaded
				;without "taking its health with it". Using default
				;settings:
				;
				; Rex_A: 2HP, Rex_B: 2HP, UnloadedSprites: 15 HP = 19HP
				;
				; After Mario defeats both rexes and a Chargin Chuck spawns:
				;
				; Chuck: 15HP, UnloadedSprites: 0 HP = 15HP
				;
				LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
				SEC
				SBC.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount
				STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
				if !Setting_SpriteHP_TwoByte
					LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
					SBC.b #!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount>>8
					STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
				endif
		..MarkedAsItSpawned
			INC !RAM_HaveSpawnFlag
		BRA .Done
	.ThereIsLoadedEnemy
	.Done
		PLB
		RTL