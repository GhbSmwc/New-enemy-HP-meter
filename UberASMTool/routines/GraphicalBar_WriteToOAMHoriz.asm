incsrc "../GraphicalBarDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This writes the graphical bar tiles to OAM (horizontal).
;
;Note: Not to be used for “normal sprites” (the generally
;interactable sprites such as SMW or pixi sprites using 12 (22 for
;SA-1) slots). This writes OAM directly like most sprite status bar
;patches. Instead, use DrawSpriteGraphicalBarHoriz instead.
;
;Input
; - !Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl + (NumberOfTiles -1)
;   the tile numbers to write.
; - $00 to $01: X position, relative to screen border (where the
;   fill starts at)
; - $02 to $03: Y position, same as above but Y position
; - $04 to $05: Number of tiles to write
; - $06: Direction of increasing fill:
; -- #$00 = left to right
; -- #$01 = right to left (YXPPCCCT's X bit being set)
; - $07: Properties (YXPPCCCT).
;Destroyed:
; - $08 to $09: Displacement of each tile during processing. Once finished
;   this will be the tile after the final tile, can be used for placing
;   static end tile here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?DrawOamGraphicalBarHoriz:
	PHB
	PHK
	PLB
	REP #$10
	LDX $04				;>Load number of tiles as 16-bit X
	PHX
	%UberRoutine(FindNFreeOAMSlot)		;>Check if enough slots are available
	PLX
	BCC ?+
	JMP ?.Done			;>If no slots available, don't write any of the graphical bar (failsafe).
	?+
	LDX #$0000			;>Start loop
	?.DrawBar
		REP #$20
		LDA $00				;\Store the initial tile pos in $08 (this makes writing each tile in each 8 pixels to the right/left)
		STA $08				;/
		SEP #$20
		LDY.w #!GraphicalBar_OAMSlot*4
		?..OAMLoop
			;Check if OAM is used by something else, if yes, pick another OAM slot
			?...CheckOAMUsed
				LDA $0201|!addr,y
				CMP #$F0
				BEQ ?....NotUsed		;>If Y pos is #$F0 (offscreen), it is not used
				
				?....Used	;>Otherwise if used, check next slot.
					INY
					INY
					INY
					INY
					BRA ?...CheckOAMUsed
				?....NotUsed
			;Screen and positions
			?...CheckIfOnScreen
				REP #$20	;\If offscreen, go to next tile of the graphical bar, and reuse the same OAM index (don't hog the slots for nothing)
				LDA $08		;|\X position
				CMP #$FFF8+1	;||
				SEP #$20	;||
				BMI ?...Next	;||
				REP #$20	;||
				CMP #$0100	;||
				SEP #$20	;||
				BPL ?...Next	;|/
				REP #$20	;|
				LDA $02		;|\Y position
				CMP #$FFF8+1	;||
				SEP #$20	;||
				BMI ?...Next	;||
				REP #$20	;||
				CMP #$00E0	;||
				SEP #$20	;||
				BPL ?...Next	;//
			?...XPos
				LDA $08			;\Low 8 bits
				STA $0200|!addr,y	;/
				REP #$30		;>Because we are transferring Y (16-bit) to A (8-bit), it's best to have both registers 16-bit.
				TYA			;>TYA : LSR #4 TAY converts the Y slot index (increments of 4) into slot number (increments of 1)
				LSR #2			;\Handle 9th bit X position
				PHY			;|
				TAY			;|
				LDA $09			;|
				SEP #$20		;|
				AND.b #%00000001	;|
				STA $0420|!addr,y	;/
				PLY
			?...YPos
				LDA $02						;\Y pos
				STA $0201|!addr,y				;/
			?...TileNumber
				LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Tile number
				STA $0202|!addr,y				;/
			?...TileProps
				LDA $06
				BNE ?....XFlip
				
				?....NoXFlip
					LDA $07
					BRA ?....Write
				?....XFlip
					LDA $07
					ORA.b #%01000000
				?....Write
					STA $0203|!addr,y		;>YXPPCCCT
			?...NextOamSlotAndBarTile
				INY			;\Next OAM slot (only next if the OAM tile is onscreen)
				INY			;|
				INY			;|
				INY			;/
			?...Next
				PHX
				LDX #$0000
				LDA $06
				BEQ ?....NoXFlip
				?....XFlip
					INX #2
				?....NoXFlip
				REP #$20			;\Move tile position by 8 pixels
				LDA $08				;|
				CLC				;|
				ADC.w ?.TileDisplacement,x	;|
				PLX				;|
				STA $08				;|
				SEP #$20			;/
				INX				;>Next graphical bar slot
				CPX $04				;\Loop until all graphical bar tiles are written.
				BCS ?+
				JMP ?..OAMLoop
				?+
	?.Done
		SEP #$30				;>Set AXY to 8-bit just in case.
		PLB
		RTL
	?.TileDisplacement
		dw $0008
		dw $FFF8