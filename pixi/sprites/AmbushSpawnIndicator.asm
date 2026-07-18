;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sprite spawn indicator
;
;This sprite displays a "!" indicator before a sprite
;spawns* in its spot.
;
;
;Extra byte settings:
;EXB1: Sprite number
;EXB2: Extra bits: %0000C---
;
;Custom flag (0 = vanilla SMW, 1 = custom sprite)


;*This sprite actually turns into the sprite, to avoid
;being repositioned in the sprite table slot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Conffigurations
	!Setting_AmbushIndicator_TileNumb = $1D			;>Valid: $00-$FF
	!Setting_AmbushIndicator_TileProp_Page = 0		;>Valid: 0-1
	!Setting_AmbushIndicator_TileProp_Palette = 4	;>Valid: 0-7, hint: It's LM's row number = ValueHere + 8
	!Setting_AmbushIndicator_TileProp_Priority = 3	;>Valid: 0-3, higher value = front of most things
	!Setting_AmbushIndicator_TileProp_XFlip = 0		;>Valid: 0-1, X-flip
	!Setting_AmbushIndicator_TileProp_YFlip = 0		;>Valid: 0-1, Y-flip
	!Setting_AmbushIndicator_TileSize = 0			;>Valid: 0-1, 0 = 8x8 tile, 1 = 16x16.
	
	!Setting_AmbushIndicator_Duration = 90
		;^How long the warning indicator last before the sprite spawns, in frames
		;(valid: 0-255, 60 = 1 second, up to 4.25 seconds)

;Don't touch unless you know what you're doing
	!Setting_AmbushIndicator_YXPPCCCT #= ((!Setting_AmbushIndicator_TileProp_YFlip<<7)|(!Setting_AmbushIndicator_TileProp_YFlip<<6)|(!Setting_AmbushIndicator_TileProp_Priority<<4)|(!Setting_AmbushIndicator_TileProp_Palette<<1)|(!Setting_AmbushIndicator_TileProp_Page))
	!RAM_WarningTimer = !1540 ;>Must be RAM that decrements itself each frame and freezes if $9D is set.
	!RAM_CurrentProcessSpriteSlot = $15E9|!addr
	!RAM_OAM_XPos = $0300|!addr
	!RAM_OAM_YPos = $0301|!addr
	!RAM_OAM_TileNumber = $0302|!addr
	!RAM_OAM_TileProps = $0303|!addr
print "INIT ",pc
	LDA.b #!Setting_AmbushIndicator_Duration
	STA !RAM_WarningTimer,x
	RTL
print "MAIN ",pc
MainCode:
	PHB
	PHK
	PLB
	JSR SUB_GFX
	LDA !RAM_WarningTimer,x
	BNE .Done
	
	LDA #$00
	STA $40FFFF
	LDA #$01
	STA !14C8,x
	
	LDA !extra_byte_1,x
	STA !9E,x
	JSL $07F7D2|!BankB
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
		
		LDA #$08
		STA !7FAB10,x
		BRA .Done
	.TurnIntoVanillaSprite
	
	STA !new_sprite_num,x
	LDA !extra_byte_2,x
	STA !extra_bits,x
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
			BRA ..XYDone
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Graphic offset table
;This handles adjusting the "!" tile to allow
;it to be centered to where the sprite is being
;spawned (because sprites may not always have their
;orgin XY point in the middle of the sprite). Units
;are in pixels.
;
;You can enter negative values here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SMWSprIndicatorOffsetX:
    ;X position displacement for vanilla SMW sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $00-$0F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $10-$1F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $20-$2F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $30-$3F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $40-$4F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $50-$5F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $60-$6F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $70-$7F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $80-$8F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $90-$9F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $A0-$AF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $B0-$BF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004                                    ;>Sprite numbers $C0-$C8
SMWSprIndicatorOffsetY:
    ;Y position displacement for vanilla SMW sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $00-$0F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $10-$1F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $20-$2F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $30-$3F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $40-$4F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $50-$5F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $60-$6F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $70-$7F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $80-$8F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $90-$9F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $A0-$AF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $B0-$BF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004                                    ;>Sprite numbers $C0-$C8
CusSprIndicatorOffsetX:
    ;X position displacement for pixi sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $00-$0F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $10-$1F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $20-$2F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $30-$3F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $40-$4F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $50-$5F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $60-$6F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $70-$7F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $80-$8F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $90-$9F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $A0-$AF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $B0-$BF
CusSprIndicatorOffsetY:
    ;Y position displacement for pixi sprites
    ;   +$0  +$1  +$2  +$3  +$4  +$5  +$6  +$7  +$8  +$9  +$A  +$B  +$C  +$D  +$E  +$F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $00-$0F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $10-$1F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $20-$2F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $30-$3F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $40-$4F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $50-$5F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $60-$6F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $70-$7F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $80-$8F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $90-$9F
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $A0-$AF
    db  004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004, 004 ;>Sprite numbers $B0-$BF