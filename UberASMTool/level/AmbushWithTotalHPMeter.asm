;>bytes 1

;This simple ASM code tests the total HP system utilizing "!Freeram_SpriteHP_TotalHPOfUnloadedSprites",
;by simulating an ambush system. This will make the meter show the total HP for sprites currently loaded,
;and the enemies yet to spawn in the level.
;
;Note:
; - The patch, "HPSystemForSMWSprites.asm" is required.
; - For custom sprites, they need to be adopted to use this ASM resource's HP system to properly track
;   the total health remaining.
; - Because "DisplayEnemyHP.asm" total HP mode display counts all HP of loaded sprites, this also includes
;   sprites that are placed in Lunar Magic.
; - If the meter increases or decreases when enemies spawn, that indicates that the enemy was spawn with
;   an improper health amount, causing the value stored in RAM defined !Freeram_SpriteHP_TotalHPOfUnloadedSprites
;   to be subtracted by an incorrect amount. It relies on the sprite table clearing routine that now
;   have a default HP amount at spawn (see HPSystemForSMWSprites.asm under "DefaultHPOnSpawn").
; - Make sure that enemies cannot spawn another enemy that has health, such as "Splittin Chuck" (Sprite $92).
; - Enemies spawn by this ambush system will always have "process off-screen" tweaker bit set ($167A bit 2 set)
;   this allows ambush rooms to span more than a single screen wide and long without allowing the player to
;   despawn them by moving the screen.
;
;A test level file is provided, for level 106 (Yoshi's Island 2), as seen in
;"LM stuff/Levels/Level_106_TotalHPTest.mwl". You just need to have this file
;be placed in uberasm tool's level folder (and make sure the defines are placed
;in where the .exe program is at).
;
;In this example, and using default HP values, the level should play out like this:
; - First wave: 2 Rexes, 1 Chuck
; - Second wave: 2 Chucks
; - Third wave: 1 goomba and 1 blue shell-less koopa
; Result:
; 3 chucks (15 HP each): 45 HP
; 2 Rexes (2 HP each): 4 HP
; A Goomba and shell-less blue koopa (1 HP each): 2 HP
; Total HP: 51. This is the amount to be written at a table labeled "AmbushTotalHPList".
;
;Extra bytes info:
; EXB1: What set of ambush to use (adding new ambushes requires updating the table under "AmbushList" as well as
; the tables below that). Valid values are $00-$7F (0-127).
;
;Settings:
	!Setting_Ambush_WaveDelay = 60
		;^How many frames after a wave is finished, or to end the level after the final wave. Note that if
		; spawn indicators were enabled, the indicator sprites have their own delay (thus the total delay is this
		; plus indicator sprite's "!Setting_AmbushIndicator_Duration").
	!Setting_Ambush_SpawnIndicator = 1
		;^Spawn with warning indicator: 0 = no, 1 = yes (requires pixi sprite "AmbushSpawnIndicator.asm",
		; included in this ASM resource).
	;These are failsafe to prevent sprites from spawning on or near the player (causes sudden damage
	;to the player without warning). This is only needed if you don't have spawn indicator enabled.
		!Setting_Ambush_SpawnTaxicabDistanceDetect = $0040
			;^The taxicab distance between a spawned sprite, and the player that if less than, will
			; offset the spawn position to prevent spawning on or near the player's current position,
			; to prevent sudden damage to the player. I don't recommend $0080-$FFFF though.
		!Setting_Ambush_SpawnOffset = $0060
			;^When the spawned sprite is too close to the player, offset the X position by this amount
			; (+/- this value). Must be $0000-$7FFF.
	;These are used when using the spawning indicator.
		!Setting_Ambush_SpawnIndicator_SpawnIndicatorNumb = $0E
			;^Used only when !Setting_Ambush_SpawnIndicator == 1. This is the sprite number of the ambush spawning indicator.
;RAM to use
	!Freeram_Ambush_SpawnPointer = $1487|!addr
		;^[2 bytes] A tracker that holds the "position" (a 16-bit address pointing to the enemy spawn table) of what wave
		; and enemies to spawn. Note that the spawn table and this code must be on the same bank.
	!Freeram_Ambush_DelayTimer = $1436|!addr ;>Reusing the RAM that, when used in a normal level, only by keyholes.
		;^[1 byte] A frame counter that ticks down once per frame. This is the amount of delay between waves
;Don't touch
	incsrc "../SharedSubroutineDefs.asm"
	incsrc "../StatusBarDefines.asm"
	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"
	incsrc "../NumberDisplayRoutinesDefines.asm"

	assert !Setting_SpriteHP_TotalHPMode == 2, "This test ASM code requires the total HP system."
	assert !Setting_SpriteHP_VanillaSprite_OneShotSprites != 0, "This test ASM code requires HP for 1-shot sprites."
	
	!TableSizeForHP = "db"
	if !Setting_SpriteHP_TwoByte
		!TableSizeForHP = "dw"
	endif

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
	if !sa1
		%invoke_sa1(.RunSA1)
		RTL
		.RunSA1
	endif
	PHB
	PHK
	PLB
	;Set pointer of a set of enemies to spawn
		REP #$20
		LDA ($00)
		AND #$00FF
		ASL
		TAX
		LDA AmbushList,x
		STA !Freeram_Ambush_SpawnPointer
	;Set total HP
		if !Setting_SpriteHP_TwoByte == 0
			SEP #$20
			TXA
			LSR
			TAX
			LDA AmbushTotalHPList,x
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
			STA !Freeram_SpriteHP_TotalMaxHP
		else
			LDA AmbushTotalHPList,x
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
			STA !Freeram_SpriteHP_TotalMaxHP
			SEP #$20
		endif
	;Delay timer just in case
		LDA.b #!Setting_Ambush_WaveDelay
		STA !Freeram_Ambush_DelayTimer
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
	PLB
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
		LDA !Freeram_Ambush_DelayTimer
		BEQ ..Zero
		DEC A
		STA !Freeram_Ambush_DelayTimer
		..Zero
		
	JSR SearchSprites
	CPX #$FF
	BNE .EnemiesRemaining ;>If there are enemies remaining, don't advance
	LDA !Freeram_Ambush_DelayTimer		;\After all enemies gone, wait
	BNE .Done				;/
		
		
	.SpawnEnemiesOfWave
		..Loop
			REP #$20
			LDA !Freeram_Ambush_SpawnPointer
			STA $06
			SEP #$20
			LDA ($06)
			CMP #$FF
			BEQ .InBetweenWaves
			CMP #$FE
			BEQ .EndLevel
			CMP #$FD
			BEQ .TeleportScreenExit
			
			...SpawnSpriteOfWave
				LDY #$01
				LDA ($06),y
				BEQ ....SpawnVanilla
				
				....SpawnCustom
					SEC
					BRA ....SetXYPos
				....SpawnVanilla
					CLC
				....SetXYPos
					LDY #$02
					REP #$20
					LDA ($06),y
					STA $02
					INY #2
					LDA ($06),y
					STA $04
					SEP #$20
					if !Setting_Ambush_SpawnIndicator == 0
						LDA ($06)
					else
						SEC
						LDA.b #!Setting_Ambush_SpawnIndicator_SpawnIndicatorNumb
					endif
				JSR AmbushSpawn
				BCC ..Loop ;>Loop to spawn the next sprite if there is an available slot.
			...ExitLoop ;>Otherwise if there isn't, don't proceed and skip for this frame.
		BRA .Done
	.InBetweenWaves
		REP #$20
		LDA !Freeram_Ambush_SpawnPointer
		INC A
		STA !Freeram_Ambush_SpawnPointer
		SEP #$20
	.Done
		PLB
		RTL
	.EnemiesRemaining
		LDA.b #!Setting_Ambush_WaveDelay
		STA !Freeram_Ambush_DelayTimer
		BRA .Done
	.EndLevel
		LDA #$FF
		STA !Freeram_SpriteHP_MeterState
		LDA !Freeram_Ambush_DelayTimer	;\Avoid triggering immidiately after last enemy killed.
		BNE .Done			;/
		LDA #$FF
		STA $1493|!addr
		STA $13C6|!addr
		BRA .Done
	.TeleportScreenExit
		LDA #$FF
		STA !Freeram_SpriteHP_MeterState
		LDA #$06				;\Teleport player.
		STA $71					;|
		STZ $89					;|
		STZ $88					;/
		BRA .Done
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
				;Put your list here for custom sprites, if using the spawning indicator sprite, it must count as "enemy exists" (don't have it on here).
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
	; -- Decreases the amount of HP of unloaded sprite (every time a sprite is spawned, it
	;    "takes its HP with it"), only applies if you have indicators turned off.
	;Input:
	; - A = Sprite number
	; - Carry: 0 = Vanilla sprite, 1 = custom
	; - $02-$03: X position
	; - $04-$05: Y position
	;Output:
	; - Carry: 0 = successfully spawned sprite, 1 = failed
	LDX #!sprite_slots-3
		;^Let me explain why !sprite_slots-3 instead of !sprite_slots-1. The fireballs thrown by the
		; player does not interact with sprites on the last 2 slots. Meaning LoROM, only $00-09 of
		; the $00-$0B slots are consitered. In SA-1 however, only $00-$13 of the $00-$15 slots are
		; checked. The last 2 sprite slots are consitered "important" sprites that are spawned
		; uniquely such as when dropped from the item box, or from blocks.
	%UberRoutine(SpawnSprite)
	BCC .SpawnSuccess
	JMP .SpawnFailed	;>If all slots (from $00 to !sprite_slots-3) filled, don't advance
	.SpawnSuccess
	.SpawningIndicatorSprite
		if !Setting_Ambush_SpawnIndicator
			LDA ($06)
			STA !extra_byte_1,x
			LDY #$01
			LDA ($06),y
			BEQ ..Vanilla
			..Custom
				LDA #$08
				BRA ..SetCustomFlag
			..Vanilla
				LDA #$00
			..SetCustomFlag
				STA !extra_byte_2,x
		endif
	.SFX
		if !Setting_Ambush_SpawnIndicator == 0
			LDA #$10
			STA $1DF9|!addr
		endif
	.SetXYPos
		..AvoidSpawningOnOrNearPlayer
			if !Setting_Ambush_SpawnIndicator == 0
				;This checks if the spawning sprite is too close to the player. If so, offset that
				;that spawn X position. The direction to offset the sprite spawning position will
				;be towards the middle of the level (to avoid potentially spawning the sprite
				;outside the level boundaries). Note that this does not check if the spawn point
				;is inside a wall.
				;
				;The proximity check uses the taxicab distance if the player is too close.
				REP #$20
				...XDelta
					LDA $94
					SEC
					SBC $02
					BPL ....Pos
					EOR #$FFFF
					INC
					....Pos
					PHA			;>Save X position distance to stack
				...YDelta
					LDA $96
					SEC
					SBC $04
					BPL ....Pos
					EOR #$FFFF
					INC
					....Pos
					CLC
					ADC $01,s	;>Add Y position distance with X (in the stack), forming a taxicab distance
					CMP.w #!Setting_Ambush_SpawnTaxicabDistanceDetect
					BCS ...CheckDone   ;>If too far away, then the current spot is safe to spawn the sprite in.
				...IsOnOrNearPlayer
					LDY #$00
					LDA $5D						;\Load level width in pixels (Loads $5D in A's low byte, $5E (level width) in A's high byte),
					AND.w #$FF00				;/then zeroes out the low byte, leaving the high byte pixel position in A's high byte
					LSR							;>Divide by 2 to obtain the x position halfway point
					CMP $02						;>Halfway point compares with X position of sprite
					BCS ....OffsetSpawnRight	;>If halfway point is to the right of spawn point, or spawn point to the left, move spawn point to the right
					....OffsetSpawnLeft
						INY #2					;>Otherwise spawn to the left.
					....OffsetSpawnRight
					LDA .SpawnOffsets,y
					CLC
					ADC $02
					STA $02
				...CheckDone
					PLA
					SEP #$20
			endif
		..SetXYPos
			LDA $02
			STA !sprite_x_low,x
			LDA $03
			STA !sprite_x_high,x
			LDA $04
			STA !sprite_y_low,x
			LDA $05
			STA !sprite_y_high,x
		..SetProcessOffScreen
			LDA !167A,x
			ORA.b #%00000100
			STA !167A,x
	.DeductHPOfUnloaded
		if !Setting_Ambush_SpawnIndicator == 0
			LDA #$01		;\When sprite is in inital phase, it's HP is counted. Thus this increases total HP of loaded sprite, which immidiately
			STA !14C8,x		;/after this, deducts total HP of unloaded sprites, thus canceling out and preventing meter from increasing or decreasing.
			;Here, every time you spawn a sprite, you need to, within that
			;frame of spawning the sprite, deduct the value in
			;!Freeram_SpriteHP_TotalHPOfUnloadedSprites by how much HP
			;that spawned sprite has, else the meter fills upward because
			;a sprite went from not being loaded, to now being loaded
			;without "taking its health with it".
			;
			;Notes:
			; - This assumes that the sprites spawned via the ambush
			;   system have its HP initialized properly (see
			;   "HPSystemForSMWSprites.asm" under "DefaultHPOnSpawn:")
			; - If you have enemies with HP amounts based on how it spawns,
			;   such as the "Better Pokey" (https://www.smwcentral.net/?p=section&a=details&id=36812 )
			;   by Isikoro (Each segment and head counts as 1 HP), then
			;   you may need to make some changes here to accomodate its
			;   spawn configuration-dependent HP.
			; - If you're using spawning indicators
			;   (!Setting_Ambush_SpawnIndicator == 1), then the "HP transfer
			;   from an unloaded enemy to a loaded enemy" happens when
			;   the spawning indicator "spawns" (indicator sprite actually
			;   turns into an enemy with its sprite tables and HP values
			;   initialized) the sprite, not when this ambush code spawns
			;   the indicator sprites.
				LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
				SEC
				SBC !Freeram_SpriteHP_CurrentHPLow,x
				STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
				if !Setting_SpriteHP_TwoByte
					LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
					SBC !Freeram_SpriteHP_CurrentHPHi,x
					STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
				endif
		else
			;Indicator sprites shouldn't have HP
			LDA #$00
			STA !Freeram_SpriteHP_CurrentHPLow,x
			STA !Freeram_SpriteHP_MaxHPLow,x
			if !Setting_SpriteHP_TwoByte
				STA !Freeram_SpriteHP_CurrentHPHi,x
				STA !Freeram_SpriteHP_MaxHPHi
			endif
		endif
	.AdvanceSpawnCounter
		REP #$20
		LDA !Freeram_Ambush_SpawnPointer
		CLC
		ADC #$0006
		STA !Freeram_Ambush_SpawnPointer
		SEP #$20
	.Done
		CLC
		RTS
	.SpawnFailed
		SEC
		RTS
	.SpawnOffsets
		dw !Setting_Ambush_SpawnOffset
		dw -!Setting_Ambush_SpawnOffset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;List of ambushes. This determine which ambushes to use should your hack have multiple.
;An ambush, refers to a set of enemies to kill, including all "waves" of enemies till
;the end.
;
;Which one here to use depends on this level ASM's extra byte setting, where each value
;is an index to each item in the following table. WARNING: Using an extra byte value
;that corresponds to anything beyond the last item in the table results in garbage data
;which may crash the game during level fade-in or when spawning sprites. You can have
;up to 128 ambushes.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	AmbushList:
		dw AmbushTable0
		;dw AmbushTable1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This is the same as above, but determines how much HP in total, per ambush. It is used to determine
;how much HP of enemies yet to encounter (!Freeram_SpriteHP_TotalHPOfUnloadedSprites). Setting this
;to an incorrect value causes the meter to fill up or drain incorrectly, and/or ending with the
;meter not being empty. Do the math, add all applicable enemies' HP, and the total should be stored
;here.
;
;Format:
;  !TableSizeForHP <TotalHP>
;
; - Define !TableSizeForHP is simply "db" or "dw" depending on !Setting_SpriteHP_TwoByte (which makes the values
;   either 8 or 16-bit)
; - <TotalHP> Is a value representing the total HP. You can enter a literal number here (any base), or a math
;   statement (like below) and it will work.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	AmbushTotalHPList:
		!TableSizeForHP (!Setting_SpriteHP_VanillaSprite_Rex_HPAmount*2)+(!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount*3)+2
		;!TableSizeForHP 1234
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Ambush wave/spawn table
;Sprite spawn data format (spans 6 bytes):
; db <SpriteNumberToSpawn>, <CustomSpriteFlag> : dw <XPosition>, <YPosition>
;
; - SpriteNumberToSpawn: Sprite number to spawn.
; - CustomSpriteFlag: 0 = Vanilla SMW sprites, 1 = Custom sprite
; - XPosition = X Position to spawn
; - XPosition = Y Position to spawn
;
;Special behaviors (these are 1-byte large entries, not to be in the middle of the sprite spawn data):
; - To indicate a wave boundary:
;    db $FF
; - These are end-of-battle triggers. Note that a wave boundary must be placed before this byte
;   to prevent pre-mature ending trigger
; -- To mark end of battle (end level):
;     db $FE
; -- To mark end of battle (teleport via screen exit):
;     db $FD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	AmbushTable0:
		db $AB, $00 : dw $0060, $0170
		db $AB, $00 : dw $0080, $0170
		db $91, $00 : dw $00A0, $0170
		db $FF
		db $91, $00 : dw $0010, $0170
		db $91, $00 : dw $00E0, $0170
		db $FF
		db $02, $00 : dw $0010, $0170
		db $0F, $00 : dw $00E0, $0170
		db $FF
		db $FE