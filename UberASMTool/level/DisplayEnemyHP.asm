;Insert this as level.

;This ASM code displays the enemy's HP on the HUD of the most recent enemy the player
;have dealt damage to.

incsrc "../StatusBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"
incsrc "../GraphicalBarDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"


macro WriteFixedDigitsToLayer3(TileLocation, TileLocationProps)
	if !StatusbarFormat == $01
		LDX.b #(!Setting_SpriteHP_MaxDigits-1)
		-
		LDA.b !Scratchram_16bitHexDecOutput+$04-(!Setting_SpriteHP_MaxDigits-1),x
		STA <TileLocation>,x
		
		if !StatusBar_UsingCustomProperties
			LDA.b #!Setting_SpriteHP_NumericalProp
			STA <TileLocationProps>,x
		endif
		
		DEX
		BPL -
	else
		LDX.b #((!Setting_SpriteHP_MaxDigits-1)*2)
		LDY.b #(!Setting_SpriteHP_MaxDigits-1)
		-
		LDA.w !Scratchram_16bitHexDecOutput+$04-(!Setting_SpriteHP_MaxDigits-1)|!dp,y
		STA <TileLocation>,x
		
		if !StatusBar_UsingCustomProperties
			LDA.b #!Setting_SpriteHP_NumericalProp
			STA <TileLocationProps>,x
		endif
		
		DEY
		DEX #2
		BPL -
	endif
endmacro

macro WriteAlignedDigitsToLayer3()
	if !StatusbarFormat == $01
		%UberRoutine(WriteStringDigitsToHUD)
	else
		%UberRoutine(WriteStringDigitsToHUDFormat2)
	endif
endmacro

macro WriteTileAddress(TileLocation, PropLocation, PropValue)
	LDA.b #<TileLocation>
	STA $00
	LDA.b #<TileLocation>>>8
	STA $01
	LDA.b #<TileLocation>>>16
	STA $02
	if !StatusBar_UsingCustomProperties != 0
		LDA.b #<PropLocation>
		STA $03
		LDA.b #<PropLocation>>>8
		STA $04
		LDA.b #<PropLocation>>>16
		STA $05
		LDA.b #<PropValue>
		STA $06
	endif
endmacro

macro ClearNumerical()
	LDX.b #(!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat	;>2 Setting_SpriteHP_MaxDigits due to 2 numbers displayed, plus 1 because of the "/" symbol.
	-
	LDA #!StatusBarBlankTile
	if !Setting_SpriteHP_NumericalTextAlignment == 1
		STA !Setting_SpriteHP_NumericalPos_XYPos,x
	elseif !Setting_SpriteHP_NumericalTextAlignment == 2
		STA !Setting_SpriteHP_NumericalPosRightAligned_XYPos-((!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
	endif
	if !StatusBar_UsingCustomProperties != 0
		LDA.b #!Setting_SpriteHP_NumericalProp
		if !Setting_SpriteHP_NumericalTextAlignment == 1
			STA !Setting_SpriteHP_NumericalPos_XYPosProp,x
		elseif !Setting_SpriteHP_NumericalTextAlignment == 2
			STA !Setting_SpriteHP_NumericalPosRightAligned_XYPosProp-((!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
		endif
	endif
	DEX #!StatusbarFormat
	BPL -
endmacro

macro GetHealthDigits8Bit(ValueToDisplay)
		LDA !<ValueToDisplay>
		STA $00
		STZ $01
		%UberRoutine(SixteenBitHexDecDivision)
endmacro

macro GetHealthDigits16Bit(ValueToDisplayLo, ValueToDisplayHi)
		LDA !<ValueToDisplayLo>
		STA $00
		LDA !<ValueToDisplayHi>
		STA $01
		%UberRoutine(SixteenBitHexDecDivision)
endmacro

macro ConvertToRightAligned()
	if !StatusbarFormat == $01
		%UberRoutine(ConvertToRightAligned)
	else
		%UberRoutine(ConvertToRightAlignedFormat2)
	endif
endmacro

;init:
;	.ClearHPData
;		LDA #$FF
;		STA !Freeram_SpriteHP_SlotToDisplayHP
;		LDX.b #!sprite_slots-1
;		..Loop
;			LDA #$00
;			STA !Freeram_SpriteHP_CurrentHPLow,x
;			if !Setting_SpriteHP_TwoByte
;				STA !Freeram_SpriteHP_CurrentHPHi,x
;				STA !Freeram_SpriteHP_MaxHPHi,x
;			endif
;			if !Setting_SpriteHP_BarAnimation
;				LDA.b #!Setting_SpriteHP_GraphicalBar_TotalPieces
;				STA !Freeram_SpriteHP_BarAnimationFill,x
;				LDA.b #!Setting_SpriteHP_BarChangeDelay
;				STA !Freeram_SpriteHP_BarAnimationTimer,x
;			endif
;			LDA #$01
;			STA !Freeram_SpriteHP_MaxHPLow,x
;			...Next
;				DEX
;				BPL ..Loop
;	RTL
	
main:
	if !sa1
		%invoke_sa1(.RunSA1)
		RTL
		.RunSA1
	endif
	PHB
	PHK
	PLB
	LDA !Freeram_SpriteHP_SlotToDisplayHP
	CMP.b #!sprite_slots
	BCC +
	JMP .ClearHPDisplay
	+
	.CheckIfSlotIsCorrect
		LDA !Freeram_SpriteHP_SlotToDisplayHP
		CMP.b #!sprite_slots				;\Failsafe. A valid slot number ranges from 0 to !sprite_slots-1.
		BCC ..DisplayMeter
		JMP .Done					;/
		..DisplayMeter
			TAX
			LDA !14C8,x
			BNE ...Exists
			LDA #$FF
			STA !Freeram_SpriteHP_SlotToDisplayHP
			JMP .Done
			...Exists
	.DisplayNumerical
		;Detect user trying to make a right-aligned single number (which avoids unnecessarily uses suppress leading zeroes)
			!IsUsingRightAlignedSingleNumber = and(equal(!Setting_SpriteHP_NumericalTextAlignment, 2),equal(!Setting_SpriteHP_DisplayNumerical, 1))
		if !Setting_SpriteHP_DisplayNumerical != 0 ;User allow displaying HP numerically
			;Clear the tiles. To prevent leftover "ghost" tiles that should've
			;disappear when the number of digits decreases (so when "10" becomes "9",
			;won't display "90").
			if !IsUsingRightAlignedSingleNumber == 0 ;if using suppressed zeroes
				%ClearNumerical()
			endif
			LDA !Freeram_SpriteHP_SlotToDisplayHP
			TAX
			if or(equal(!Setting_SpriteHP_NumericalTextAlignment, 0), equal(!IsUsingRightAlignedSingleNumber, 1)) ;Fixed digit location
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("Freeram_SpriteHP_CurrentHPLow,x")
				else
					%GetHealthDigits16Bit("Freeram_SpriteHP_CurrentHPLow,x", "Freeram_SpriteHP_CurrentHPHi,x")
				endif
				%UberRoutine(RemoveLeadingZeroes16Bit)
				%WriteFixedDigitsToLayer3(!Setting_SpriteHP_NumericalPos_XYPos, !Setting_SpriteHP_NumericalPos_XYPosProp)
			elseif and(greaterequal(!Setting_SpriteHP_NumericalTextAlignment, 1), lessequal(!Setting_SpriteHP_NumericalTextAlignment, 2)) ;left/right aligned
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("Freeram_SpriteHP_CurrentHPLow,x")
				else
					%GetHealthDigits16Bit("Freeram_SpriteHP_CurrentHPLow,x", "Freeram_SpriteHP_CurrentHPHi,x")
				endif
				LDX #$00
				%UberRoutine(SuppressLeadingZeroes)
				if !Setting_SpriteHP_DisplayNumerical == 2
					LDA #!StatusBarSlashCharacterTileNumb
					STA !Scratchram_CharacterTileTable,x
					INX
					PHX
					LDA !Freeram_SpriteHP_SlotToDisplayHP
					TAX
					if !Setting_SpriteHP_TwoByte == 0
						%GetHealthDigits8Bit("Freeram_SpriteHP_MaxHPLow,x")
					else
						%GetHealthDigits16Bit("Freeram_SpriteHP_MaxHPLow,x", "Freeram_SpriteHP_MaxHPHi,x")
					endif
					PLX
					%UberRoutine(SuppressLeadingZeroes)
				endif
				if !Setting_SpriteHP_ExcessDigitProt
					CPX.b #(!Setting_SpriteHP_MaxStringLength+1)
					BCS ..TooMuchChar
				endif
				if !Setting_SpriteHP_NumericalTextAlignment == 1
					%WriteTileAddress(!Setting_SpriteHP_NumericalPos_XYPos, !Setting_SpriteHP_NumericalPos_XYPosProp, !Setting_SpriteHP_NumericalProp)
				elseif !Setting_SpriteHP_NumericalTextAlignment == 2
					%WriteTileAddress(!Setting_SpriteHP_NumericalPosRightAligned_XYPos, !Setting_SpriteHP_NumericalPosRightAligned_XYPosProp, !Setting_SpriteHP_NumericalProp)
				endif
				if !Setting_SpriteHP_NumericalTextAlignment == 2 ;Right-aligned
					%ConvertToRightAligned()
				endif
				%WriteAlignedDigitsToLayer3()
				..TooMuchChar
			endif
		endif
	.DisplayGraphicalBar
		if !Setting_SpriteHP_DisplayGraphicalBar
			..HandleTimerAndPreviousHP
				LDA.b #!Setting_SpriteHP_GraphicalBar_LeftPieces
				STA !Scratchram_GraphicalBar_LeftEndPiece
				LDA.b #!Setting_SpriteHP_GraphicalBar_MiddlePieces
				STA !Scratchram_GraphicalBar_MiddlePiece
				LDA.b #!Setting_SpriteHP_GraphicalBar_RightPieces
				STA !Scratchram_GraphicalBar_RightEndPiece
				LDA.b #!Setting_SpriteHP_GraphicalBarMiddleLength
				STA !Scratchram_GraphicalBar_TempLength
				LDA !Freeram_SpriteHP_SlotToDisplayHP
				TAX
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				STA !Scratchram_GraphicalBar_FillByteTbl
				LDA !Freeram_SpriteHP_MaxHPLow,x
				STA !Scratchram_GraphicalBar_FillByteTbl+2
				if !Setting_SpriteHP_TwoByte
					LDA !Freeram_SpriteHP_CurrentHPHi,x
					STA !Scratchram_GraphicalBar_FillByteTbl+1
					LDA !Freeram_SpriteHP_MaxHPHi,x
					STA !Scratchram_GraphicalBar_FillByteTbl+3
				else
					LDA #$00
					STA !Scratchram_GraphicalBar_FillByteTbl+1,x
					STA !Scratchram_GraphicalBar_FillByteTbl+3,x
				endif
				PHX
				if !Setting_SpriteHP_BarFillRoundDirection == 0
					%UberRoutine(GraphicalBar_CalculatePercentage)
				elseif !Setting_SpriteHP_BarFillRoundDirection == 1
					%UberRoutine(GraphicalBar_CalculatePercentageRoundDown)
				elseif !Setting_SpriteHP_BarFillRoundDirection == 2
					%UberRoutine(GraphicalBar_CalculatePercentageRoundUp)
				endif
				;$00~$01 = percentage
				if !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 1
					%UberRoutine(GraphicalBar_RoundAwayEmpty)
				elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 2
					%UberRoutine(GraphicalBar_RoundAwayFull)
				elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 3
					%UberRoutine(GraphicalBar_RoundAwayEmptyFull)
				endif
				PLX
				if !Setting_SpriteHP_BarAnimation
					if !Setting_SpriteHP_BarChangeDelay
						LDA !Freeram_SpriteHP_BarAnimationTimer,x
						BEQ ...TimerEnded
						DEC
						STA !Freeram_SpriteHP_BarAnimationTimer,x
						...TimerEnded
					endif
					LDA $00
					CMP !Freeram_SpriteHP_BarAnimationFill,x
					BEQ ...PreviousAndCurrentHPEqual
					BCC ...Damage
					
					...FillUp
						if and(notequal(!Setting_SpriteHP_FillDelayFrames, 0), less(!Setting_SpriteHP_BarFillUpPerFrame, 2))
							LDA $13
							AND.b #!Setting_SpriteHP_FillDelayFrames
							BNE ....ShowFilllingUp
						endif
						if and(notequal(!Setting_SpriteHP_ShowHealedTransparent, 0), notequal(!Setting_SpriteHP_BarChangeDelay, 0))
							LDA !Freeram_SpriteHP_BarAnimationTimer,x
							BNE ....ShowFilllingUp
						endif
						LDA !Freeram_SpriteHP_BarAnimationFill,x
						if !Setting_SpriteHP_BarFillUpPerFrame >= 2
							CLC
							ADC.b #!Setting_SpriteHP_BarFillUpPerFrame
							BCS ....IncrementPast
							CMP $00
							BCC ....Increment
							
							....IncrementPast
								LDA $00
								STA !Freeram_SpriteHP_BarAnimationFill,x
								BRA ....ShowFilllingUp
							....Increment
								STA !Freeram_SpriteHP_BarAnimationFill,x
						else
							INC
							STA !Freeram_SpriteHP_BarAnimationFill,x
						endif
						....ShowFilllingUp
							if !Setting_SpriteHP_ShowHealedTransparent
								LDA $13
								AND.b #%00000001
								BNE .....FillSoundEffect
							endif
							LDA !Freeram_SpriteHP_BarAnimationFill,x
							STA $00
							.....FillSoundEffect
								if !Setting_SpriteHP_FillingSFXNumb
									LDA $13D4|!addr
									BNE ......NoSfx
									LDA $13
									AND.b #%00000001
									BNE ......NoSfx
										LDA.b #!Setting_SpriteHP_FillingSFXNumb
										STA !Setting_SpriteHP_FillingSFXPort
									......NoSfx
								endif
							JMP ...AnimationDone
					...Damage
						if and(notequal(!Setting_SpriteHP_EmptyDelayFrames, 0), less(!Setting_SpriteHP_BarEmptyPerFrame, 2))
							LDA $13							;\Decrement every 2^n frames
							AND.b #!Setting_SpriteHP_EmptyDelayFrames		;|
							if !Setting_SpriteHP_BarChangeDelay != 0
								ORA !Setting_SpriteHP_BarEmptyPerFrame		;|>Freeze if timer still active
							endif
							BNE ....TransperentAnimation				;/>If odd frame, display alternating frames of HP.
						else
							if !Setting_SpriteHP_BarChangeDelay != 0
								LDA !Freeram_SpriteHP_BarAnimationTimer,x
								BNE ....TransperentAnimation
							endif
						endif
						if !Setting_SpriteHP_BarEmptyPerFrame >= 2
							LDA !Freeram_SpriteHP_BarAnimationFill,x	;\Decrement fill
							SEC						;|
							SBC.b #!Setting_SpriteHP_BarEmptyPerFrame	;/
							BCC ....Underflow				;>Underflow check
							CMP $00						;\Check if record decrements past the current HP.
							BCS ....Decrement				;/
							
							....Underflow
								LDA $00						;\Set record to current if it did goes past.
								STA !Freeram_SpriteHP_BarAnimationFill,x	;/
								BRA ...AnimationDone
							
							....Decrement
								STA !Freeram_SpriteHP_BarAnimationFill,x	;>And set the subtracted value to record
								BRA ....TransperentAnimation
						else
							LDA !Freeram_SpriteHP_BarAnimationFill,x	;\Decrement by 1
							DEC						;|
							STA !Freeram_SpriteHP_BarAnimationFill,x	;/
						endif
						....TransperentAnimation
							if !Setting_SpriteHP_ShowDamageTransperent != 0
								LDA $13					;\Alternating frames
								AND.b #%00000001			;/
								BNE ...AnimationDone			;>If odd frame, display current HP.
							endif
							LDA !Freeram_SpriteHP_BarAnimationFill,x	;\Otherwise if even, display previous HP
							STA $00						;/
					...PreviousAndCurrentHPEqual
					...AnimationDone
					
				endif
				%UberRoutine(GraphicalBar_DrawGraphicalBarSubtractionLoopEdition)
				STZ $00									;>Set graphics mode to level layer 3
				%UberRoutine(GraphicalBar_ConvertBarFillAmountToTiles)
				
				LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPos
				STA $00
				LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPos>>8
				STA $01
				LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPos>>16
				STA $02
				if !StatusBar_UsingCustomProperties != 0
					LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPosProp
					STA $03
					LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPosProp>>8
					STA $04
					LDA.b #!Setting_SpriteHP_GraphicalBarPos_XYPosProp>>16
					STA $05
					if !Setting_SpriteHP_LeftwardsBar == 0
						LDA.b #!Setting_SpriteHP_GraphicalBarProp
					else
						LDA.b #(!Setting_SpriteHP_GraphicalBarProp|(!Setting_SpriteHP_LeftwardsBar<<6))
					endif
					STA $06
				endif
				if !Setting_SpriteHP_LeftwardsBar == 0
					if !StatusbarFormat == $01
						%UberRoutine(GraphicalBar_WriteToStatusBar)
					else
						%UberRoutine(GraphicalBar_WriteToStatusBar_Format2)
					endif
				else
					if !StatusbarFormat == $01
						%UberRoutine(GraphicalBar_WriteToStatusBarLeftwards)
					else
						%UberRoutine(GraphicalBar_WriteToStatusBarLeftwards_Format2)
					endif
				endif
		endif
	BRA .Done
	.ClearHPDisplay
		..ClearNumerical
			if !Setting_SpriteHP_DisplayNumerical
				%ClearNumerical()
			endif
		..ClearGraphicalBar
			if !Setting_SpriteHP_DisplayGraphicalBar
				LDX.b #(!Setting_SpriteHP_GraphicalBar_TotalTiles-1)*!StatusbarFormat
				...Loop
					LDA.b #!StatusBarBlankTile
					STA !Setting_SpriteHP_GraphicalBarPos_XYPos,x
					LDA.b #!Setting_SpriteHP_GraphicalBarProp
					STA !Setting_SpriteHP_GraphicalBarPos_XYPosProp,x
					....Next
						DEX #!StatusbarFormat
						BPL ...Loop
			endif
	.Done
	PLB
	RTL