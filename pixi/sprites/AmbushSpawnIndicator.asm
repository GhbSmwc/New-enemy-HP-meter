;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sprite spawn indicator
;
;This sprite displays a "!" indicator before a
;sprite "spawns"* in its spot. This informs the
;player of where the sprite to appear at to avoid
;suddenly taking damage.
;
;Note: Several sprites have different widths and
;hights, as well as their origin XY positions of
;their bodies. Thus, it is possible that the
;indicator may not always be centered with the
;sprite it "spawns". If that's an issue, see
;"Graphic offset table" at the bottom of this ASM
;code.
;
;Extra byte settings:
;EXB1: Sprite number
;EXB2: Extra bits: %0000C---
;
;Custom flag (0 = vanilla SMW, 1 = custom sprite)
;
;
;*This sprite actually turns into the sprite, to
;avoid potentially being repositioned in the sprite
;table slot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Configurations
	!Setting_AmbushIndicator_TileNumb = $C2			;>Valid: $00-$FF, tile number of 8x8 tile editor.
	!Setting_AmbushIndicator_TileProp_Page = 0		;>Valid: 0-1, page number of 8x8 tile editor.
	!Setting_AmbushIndicator_TileProp_Palette = 2	;>Valid: 0-7, Palette to use, hint: LM_palette_editor_row_number = ValueHere + 8 (ValueHere = LM_palette_editor_row_number - 8)
	!Setting_AmbushIndicator_TileProp_Priority = 3	;>Valid: 0-3, higher value = front of most things
	!Setting_AmbushIndicator_TileProp_XFlip = 0		;>Valid: 0-1, X-flip: 0 = no, 1 = yes
	!Setting_AmbushIndicator_TileProp_YFlip = 0		;>Valid: 0-1, Y-flip: 0 = no, 1 = yes
	!Setting_AmbushIndicator_TileSize = 1			;>Valid: 0-1, 0 = 8x8 tile, 1 = 16x16.
	
	!Setting_AmbushIndicator_Duration = 90
		;^How long the warning indicator last before the sprite spawns, in frames
		;(valid: 0-255, 60 = 1 second, up to 4.25 seconds). I don't recommend values less than 30 though.

;Don't touch unless you know what you're doing
	incsrc "../SharedSubroutineDefs.asm"
	incsrc "../EnemyHPMeterDefines.asm"
	incsrc "../GraphicalBarDefines.asm"

	!Setting_AmbushIndicator_YXPPCCCT #= ((!Setting_AmbushIndicator_TileProp_YFlip<<7)|(!Setting_AmbushIndicator_TileProp_YFlip<<6)|(!Setting_AmbushIndicator_TileProp_Priority<<4)|(!Setting_AmbushIndicator_TileProp_Palette<<1)|(!Setting_AmbushIndicator_TileProp_Page))
	!RAM_WarningTimer = !1540 ;>Must be RAM that decrements itself each frame and freezes if $9D is set.
	!RAM_CurrentProcessSpriteSlot = $15E9|!addr
	!RAM_OAM_XPos = $0300|!addr
	!RAM_OAM_YPos = $0301|!addr
	!RAM_OAM_TileNumber = $0302|!addr
	!RAM_OAM_TileProps = $0303|!addr
	!RAM_MarioIsTouchingThisSprite = $C2
print "INIT ",pc
	LDA.b #!Setting_AmbushIndicator_Duration
	STA !RAM_WarningTimer,x
	RTL
print "MAIN ",pc
MainCode:
	PHB
	PHK
	PLB
	.DetectMarioTouchingIndicator
		;This code detects if the player is touching this sprite, of so, would move the indicator graphic
		;so that the player isn't covering the indicator sprite and therefore still be informed of
		;oncomming enemies to appear.
		STZ !RAM_MarioIsTouchingThisSprite,x
		JSL $03B69F|!bank	;>Get sprite clipping
		JSL $03B664|!bank	;>Get Mario clipping
		JSL $03B72B|!bank	;>Check contact
		BCC ..NoContact
		INC !RAM_MarioIsTouchingThisSprite,x
		LDA !sprite_y_high,x
		XBA
		LDA !sprite_y_low,x
		REP #$20
		SEC
		SBC $1C
		CMP #$0010
		SEP #$20
		BPL ..IsVisibleOnScreen
		
		..IsNotVisibleOnScreen
			INC !RAM_MarioIsTouchingThisSprite,x
		..IsVisibleOnScreen
		..NoContact
	JSR SUB_GFX
	LDA !RAM_WarningTimer,x
	BNE .Done
	
	LDA #$01
	STA !14C8,x
	
	LDA !extra_byte_1,x
	STA !9E,x
	LDA !extra_byte_2,x
	STA !7FAB10,x			
	JSL $07F7D2|!BankB		;>Sprite number and custom flags must be adjusted before clearing sprite tables to properly set tweaker and HP values.
	LDA !extra_byte_2,x
	AND.b #%00001000
	BEQ .TurnIntoVanillaSprite
	
	.TurnIntoCustomSprite
		LDA !9E,x
		STA !7FAB9E,x
		
		REP #$20
		LDA $00 : PHA
		LDA $02 : PHA
		SEP #$20
		
		JSL $0187A7|!BankB            ; this sucker kills $00-$02
				
		REP #$20
		PLA : STA $02
		PLA : STA $00
		SEP #$20
		
		BRA .DeductHP
	.TurnIntoVanillaSprite
		STA !new_sprite_num,x
		LDA !extra_byte_2,x
		STA !extra_bits,x
	.DeductHP
		;Here, every time you spawn a sprite, you need to, within that
		;frame of spawning the sprite, deduct the value in
		;!Freeram_SpriteHP_TotalHPOfUnloadedSprites by how much HP
		;that spawned sprite has, else the meter fills upward because
		;a sprite went from not being loaded, to now being loaded
		;without "taking its health with it".
		;
		;This sprite however turns into whatever sprite it was "spawning"
		;but should still be treated the same way, except that it happens
		;during the "transformation" of the sprite rather than
		;"AmbushWithTotalHPMeter.asm" spawning this sprite.
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
			LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
			SEC
			SBC !Freeram_SpriteHP_CurrentHPLow,x
			STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
			if !Setting_SpriteHP_TwoByte
				LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
				SBC !Freeram_SpriteHP_CurrentHPHi,x
				STA !Freeram_SpriteHP_TotalHPOfUnloadedSprites+1
			endif
	.SetProcessOffScreen
		LDA !167A,x
		ORA.b #%00000100
		STA !167A,x
	.SFX
		LDA #$10
		STA $1DF9|!addr
	.Done
		PLB
		RTL
SUB_GFX:
	;The following code handles the blinking
		LDA !RAM_WarningTimer,x
		AND.b #%00000100
		BNE .Done
	;JSR GET_DRAW_INFO	; after: Y = index to sprite OAM ($300)
				;  $00 = sprite x position relative to screen boarder 
				;  $01 = sprite y position relative to screen boarder  
				
	%GetDrawInfo()
	
	.XYPos
		LDA !extra_byte_2,x
		AND.b #%00001000
		BNE ..CustomSprite
		..SMWSprites
			LDA !extra_byte_1,x
			TAX
			LDA $00
			CLC
			ADC SMWSprIndicatorOffsetX,x
			STA !RAM_OAM_XPos,y
			LDA $01
			CLC
			ADC SMWSprIndicatorOffsetY,x
			STA !RAM_OAM_YPos,y
			BRA ..AdjustYPositionIfPlayerCovering
		..CustomSprite
			LDA !extra_byte_1,x
			TAX
			LDA $00
			CLC
			ADC CusSprIndicatorOffsetX,x
			STA !RAM_OAM_XPos,y
			LDA $01
			CLC
			ADC CusSprIndicatorOffsetY,x
			STA !RAM_OAM_YPos,y
		..AdjustYPositionIfPlayerCovering
			LDX !RAM_CurrentProcessSpriteSlot
			LDA !RAM_MarioIsTouchingThisSprite,x
			TAX
			LDA !RAM_OAM_YPos,y
			CLC
			ADC MarioTouchIndicatorDisplacement,x
			STA !RAM_OAM_YPos,y
		..XYDone
			LDX !RAM_CurrentProcessSpriteSlot
	.Tile
		LDA.b #!Setting_AmbushIndicator_TileNumb
		STA !RAM_OAM_TileNumber,y
		LDA.b #!Setting_AmbushIndicator_YXPPCCCT
		STA !RAM_OAM_TileProps,y
		LDY.b #(!Setting_AmbushIndicator_TileSize*2)	; #$02 means the tiles are 16x16
		LDA.b #$00										; value here is NumberOfTiles+1
		JSL $01B7B3|!bank
	.Done
		RTS
MarioTouchIndicatorDisplacement:
	;These are Y displacement for when the player is covering the indicator sprite.
	;First one is when not toucing at all, second is when the player is touching the
	;indicator and have enough room above the player, and third is when the player
	;is near the top of the screen.
	db $00, -$28, $10
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Graphic offset table
;This handles adjusting the "!" tile to allow
;it to be centered to where the sprite is being
;spawned (because sprites may not always have their
;orgin XY point in the middle of the sprite). Units
;are in pixels, X increases going right, Y increases
;going down.
;
;You can enter negative values here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SMWSprIndicatorOffsetX:
    ;X position displacement for vanilla SMW sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $00-$0F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $10-$1F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $20-$2F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $30-$3F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $40-$4F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $50-$5F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $60-$6F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $70-$7F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $80-$8F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $90-$9F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $A0-$AF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $B0-$BF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000                                    ;>Sprite numbers $C0-$C8
SMWSprIndicatorOffsetY:
    ;Y position displacement for vanilla SMW sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $00-$0F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $10-$1F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $20-$2F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $30-$3F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $40-$4F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $50-$5F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $60-$6F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $70-$7F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $80-$8F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $90-$9F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $A0-$AF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $B0-$BF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000                                    ;>Sprite numbers $C0-$C8
CusSprIndicatorOffsetX:
    ;X position displacement for pixi sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $00-$0F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $10-$1F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $20-$2F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $30-$3F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $40-$4F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $50-$5F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $60-$6F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $70-$7F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $80-$8F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $90-$9F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $A0-$AF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $B0-$BF
CusSprIndicatorOffsetY:
    ;Y position displacement for pixi sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $00-$0F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $10-$1F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $20-$2F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $30-$3F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $40-$4F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $50-$5F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $60-$6F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $70-$7F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $80-$8F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $90-$9F
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $A0-$AF
    db  000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000 ;>Sprite numbers $B0-$BF