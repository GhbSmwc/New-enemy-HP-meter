;This simple ASM code tests the total HP system utilizing "!Freeram_SpriteHP_TotalHPOfUnloadedSprites",
;by simulating an ambush system. This will make the meter show the total HP for sprites currently loaded,
;and the enemies yet to spawn in the level.
;
;Note:
; - The patch, "HPSystemForSMWSprites.asm" is required.
; - For custom sprites, they need to be adopted to use this ASM resource's HP system to properly track
;   the total health remaining.
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
	!Setting_StartingTotalHP #= (!Setting_SpriteHP_VanillaSprite_Rex_HPAmount*2)+(!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*3)+2
		;^Total HP. This includes sprite loaded, and sprite yet to load. With default settings, that should be 19.
	!Setting_StartingHP_SpritesYetToLoad = (!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*2)+2
		;^Total HP of sprites that have yet to spawn into the level.
	!Setting_WaveDelay = 60
;RAM to use
	!RAM_SpawnCounter = $1487|!addr
		;^[2 bytes] A tracker that holds the "position" of what wave and enemies to spawn. Note that
		; the spawn table and this code must be on the same bank.
	!RAM_SpawnDelay = $1436|!addr ;>Reusing the RAM that, when used in a normal level, only by keyholes.
		;^[1 byte] A frame counter that ticks down once per frame. This is the amount of delay between waves


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
	;Initalize some values
		;LDA #$00
		STA !RAM_SpawnCounter
		LDA.b #!Setting_WaveDelay
		STA !RAM_SpawnDelay
	;This gets the HP of all enemies yet to spawn
		LDA.b #!Setting_StartingHP_SpritesYetToLoad
		STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		if !Setting_SpriteHP_TwoByte
			LDA.b #!Setting_StartingHP_SpritesYetToLoad>>8
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
		endif
	;This gets the total HP of all enemies, current enemies placed in LM, and all enemies yet to spawn
		LDA.b #!Setting_StartingTotalHP
		STA !Freeram_SpriteHP_TotalMaxHP
		if !Setting_SpriteHP_TwoByte
			LDA.b #!Setting_StartingTotalHP>>8
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
	LDA $9D
	BNE .Done
	.DecreaseDelayTimer
		LDA !RAM_SpawnDelay
		BEQ ..Zero
		DEC A
		STA !RAM_SpawnDelay
		..Zero
		
	JSR SearchSprites
	CPX #$FF
	BNE .Done ;>If there are enemies remaining, don't advance
	LDA !RAM_SpawnDelay		;\After all enemies gone, wait
	BNE .Done				;/
		
		
	.SpawnEnemiesOfWave
		..Loop
			
			;<Insert code here that pulls from the table>
			
			JSR AmbushSpawn
			BCC ..Loop ;>Loop to spawn the next sprite if there is an available slot.
			...ExitLoop ;>Otherwise if there isn't, don't proceed and skip for this frame.
		LDA.b #!Setting_WaveDelay
		STA !RAM_SpawnDelay
	.Done
		PLB
		RTL
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
AmbushSpawn:
	;This subroutine:
	; - Atempts to spawn a sprite
	; - If fails, will not advance
	; - If success:
	; -- Sets up the sprite to spawn (XY Pos)
	; -- Decreases the amount of HP of unloaded sprite (every time a sprite is spawned, it "takes its HP with it")
	;Input:
	; - A = Sprite number
	; - Carry: 0 = Vanilla sprite, 1 = custom
	; - $00-$01: X position
	; - $02-$03: Y position
	;Output:
	; - Carry: 0 = successfully spawned sprite, 1 = failed
	LDX #!sprite_slots-3
		;^Let me explain why !sprite_slots-3 instead of !sprite_slots-1. The fireballs thrown by the
		; player does not interact with sprites on the last 2 slots. Meaning LoROM, only $00-09 of
		; the $00-$0B slots are consitered. In SA-1 however, only $00-$13 of the $00-$15 slots are
		; checked. The last 2 sprite slots are consitered "important" sprites that are spawned
		; uniquely such as when dropped from the item box, or from blocks.
	%UberRoutine(SpawnSprite)
	BCS .SpawnFailed	;>If all slots (from $00 to !sprite_slots-3) filled, don't advance
	.SFX
		LDA #$10
		STA $1DF9|!addr
	.AdvanceSpawnCounter
		REP #$20
		LDA !RAM_SpawnCounter
		CLC
		ADC #$0006
		STA !RAM_SpawnCounter
		SEP #$20
	.SetXYPos
		LDA $00
		STA !sprite_x_low,x
		LDA $01
		STA !sprite_x_high,x
		LDA $02
		STA !sprite_y_low,x
		LDA $03
		STA !sprite_y_high,x
	.DeductHPOfUnloaded
		;Here, every time you spawn a sprite, you need to, within that
		;frame of spawning the sprite, deduct the value in
		;!Freeram_SpriteHP_TotalHPOfUnloadedSprites by how much HP
		;that spawned sprite has, else the meter fills upward because
		;a sprite went from not being loaded, to now being loaded
		;without "taking its health with it".
		;
		;Note that this assumes that the sprites spawned via the ambush
		;system have its HP initialized properly (see
		;"HPSystemForSMWSprites.asm" under "DefaultHPOnSpawn:")
		LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		SEC
		SBC !Freeram_SpriteHP_CurrentHPLow,x
		STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
		if !Setting_SpriteHP_TwoByte
			LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
			SBC !Freeram_SpriteHP_CurrentHPHi,x
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
		endif
	.Done
		CLC
		RTS
	.SpawnFailed
		SEC
		RTS
		
	;Ambush wave/spawn table
	;Format:
	; db <SpriteNumberToSpawn>, <CustomSpriteFlag> : dw <XPosition>, <YPosition>
	;
	; - SpriteNumberToSpawn: Sprite number to spawn.
	; - CustomSpriteFlag: 0 = Vanilla SMW sprites, 1 = Custom sprite
	; - XPosition = X Position to spawn
	; - XPosition = Y Position to spawn
	;
	;To indicate a boundary between waves:
	; db $FF
	;
	;To mark end of battle:
	; db $FE
	
	;

AmbushTable:
	db $AB, $00 : dw $0060, $0170
	db $AB, $00 : dw $0080, $0170
	db $91, $00 : dw $00A0, $0170
	db $FF
	db $91, $00 : dw $0010, $0170
	db $91, $00 : dw $00E0, $0170
	db $FF
	db $02, $00 : dw $0010, $0170
	db $0F, $00 : dw $00E0, $0170