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

load:
	;To ASM hackers, when a sprite is placed in a level so that the player entering the level
	;would immediately load the sprite, the codes are executed in this order:
	;(1) Uberasm tool (UAT)'s level load
	;(2) Pixi's sprite init
	;(3) UAT's level init
	;
	;therefore to clear out garbage data and then have the sprite's init code set its HP,
	;this code needs to be executed under "load" and not "init".
	.ClearHPData
		LDA #$FF								;\Default to not display any HP
		STA !Freeram_SpriteHP_MeterState					;/
		LDX.b #!sprite_slots-1
		..Loop
			;This defaults HP for 12 or 22 sprite slots to having 0 HP out of 1 HP.
			;and with a graphical bar fill value maxed out (so when the meter appears,
			;shows that it previously have 100% HP).
			LDA #$00
			STA !Freeram_SpriteHP_CurrentHPLow,x
			if !Setting_SpriteHP_TwoByte
				STA !Freeram_SpriteHP_CurrentHPHi,x
				STA !Freeram_SpriteHP_MaxHPHi,x
			endif
			if !Setting_SpriteHP_BarAnimation
				LDA.b #!Setting_SpriteHP_GraphicalBar_TotalPieces
				STA !Freeram_SpriteHP_BarAnimationFill,x
				if !Setting_SpriteHP_BarChangeDelay != 0
					LDA.b #!Setting_SpriteHP_BarChangeDelay
					STA !Freeram_SpriteHP_BarAnimationTimer,x
				endif
			endif
			LDA #$01
			STA !Freeram_SpriteHP_MaxHPLow,x
			...Next
				DEX
				BPL ..Loop
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
	.SlotStateCheck
		LDA !Freeram_SpriteHP_MeterState
		if !Setting_SpriteHP_BarAnimation
			;LoROM: Index ranging 0 to 11 and 12 to 23 are valid.
			;SA-1: Index ranging from 0 to 21 and 22 to 43 are valid.
			CMP.b #!sprite_slots*2
		else
			;With no bar animation, then only 0 to 11 or 0 to 21 are valid
			CMP.b #!sprite_slots
		endif
		BCC ..ValidDisplay							;>Valid range, continue
		JMP .ClearHPDisplay							;>Otherwise, don't display at all.
		..ValidDisplay
			if !Setting_SpriteHP_BarAnimation
				CMP.b #!sprite_slots					;This converts a range representing an intro-fill mode to the regular HP display mode
				BCC ...NonIntroFillMode
				...IntroFillMode
					SEC
					SBC.b #!sprite_slots
				...NonIntroFillMode
					STA !Scratchram_SpriteHP_SpriteSlotToDisplay
			else
				STA !Scratchram_SpriteHP_SpriteSlotToDisplay
			endif
	.CheckIfSlotIsCorrect
		..DisplayMeter
			LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
			LDA !14C8,x				;>Sprite status table
			BNE ...Exists				;>If exists, allow HP to be displayed.
			LDA #$FF				;\Don't display HP of an enemy that does not exist.
			STA !Freeram_SpriteHP_MeterState	;/
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
			..SpriteSlotIndexing
				LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
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
					LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
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
				LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
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
					STA !Scratchram_GraphicalBar_FillByteTbl+1
					STA !Scratchram_GraphicalBar_FillByteTbl+3
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
					
					LDA $00							;>Fill amount of current HP
					CMP !Freeram_SpriteHP_BarAnimationFill,x		;>Fill amount of previous HP prior damage/recovery
					BNE +
					JMP ...PreviousAndCurrentHPEqual
					+
					BCS +
					JMP ...Damage
					+
					...FillUp
						if and(notequal(!Setting_SpriteHP_FillDelayFrames, 0), less(!Setting_SpriteHP_BarFillUpPerFrame, 2))
							LDA $13
							AND.b #!Setting_SpriteHP_FillDelayFrames
							BNE ....ShowFilllingUp
						endif
						if and(notequal(!Setting_SpriteHP_ShowHealedTransparent, 0), notequal(!Setting_SpriteHP_BarChangeDelay, 0))
							LDA !Freeram_SpriteHP_MeterState
							CMP.b #!sprite_slots
							BCS ....IncreaseFill				;>No pause delays if IntroFill is active
							LDA !Freeram_SpriteHP_BarAnimationTimer,x
							BNE ....ShowFilllingUp
						endif
						....IncreaseFill
							LDA !Freeram_SpriteHP_BarAnimationFill,x
							if !Setting_SpriteHP_BarFillUpPerFrame >= 2
								CLC
								ADC.b #!Setting_SpriteHP_BarFillUpPerFrame
								BCS .....IncrementPast
								CMP $00
								BCC .....Increment
								
								.....IncrementPast
									LDA $00
									STA !Freeram_SpriteHP_BarAnimationFill,x
									BRA ....ShowFilllingUp
								.....Increment
									STA !Freeram_SpriteHP_BarAnimationFill,x
							else
								INC
								STA !Freeram_SpriteHP_BarAnimationFill,x
							endif
						....ShowFilllingUp
							.....TerminateIntroFillIfAtCurrentHP
								LDA !Freeram_SpriteHP_MeterState
								CMP.b #!sprite_slots
								BCC ......NoTerminate
								LDA !Freeram_SpriteHP_BarAnimationFill,x
								CMP $00
								BCC ......NoTerminate
								
								......Terminate
									LDA !Freeram_SpriteHP_MeterState
									SEC
									SBC.b #!sprite_slots
									STA !Freeram_SpriteHP_MeterState
								......NoTerminate
							if !Setting_SpriteHP_ShowHealedTransparent
								LDA !Freeram_SpriteHP_MeterState
								CMP.b #!sprite_slots
								BCS .....IntroFill
								LDA $13
								AND.b #%00000001
								BNE .....FillSoundEffect
								.....IntroFill
							endif
							LDA !Freeram_SpriteHP_BarAnimationFill,x	;\Show animation fill.
							STA $00						;/
							.....FillSoundEffect
								if !Setting_SpriteHP_FillingSFXNumb
									LDA $13D4|!addr					;>Pause flag
									if !Setting_SpriteHP_BarChangeDelay
										ORA !Freeram_SpriteHP_BarAnimationTimer,x	;>Fill freeze timer
									endif
									BNE ......NoSfx					;>Only SFX if actually filling upwards.
									LDA $13
									AND.b #%00000001
									BNE ......NoSfx
										LDA.b #!Setting_SpriteHP_FillingSFXNumb
										STA !Setting_SpriteHP_FillingSFXPort
									......NoSfx
								endif
									JMP ...AnimationDone
					...Damage
						....TerminateIntroFill
							;This is if you damage the sprite so that the current HP fill amount jumps to below
							;the fill amount during an IntroFill, would immediately terminate the IntroFill.
							;Without this, if the sprite heals, would not show the healing indicator of the bar
							;on the first time.
							LDA !Freeram_SpriteHP_MeterState
							CMP.b #!sprite_slots
							BCC .....AlreadyTerminated
							SEC
							SBC.b #!sprite_slots
							STA !Freeram_SpriteHP_MeterState
							.....AlreadyTerminated
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
						....DecreaseFill
							if !Setting_SpriteHP_BarEmptyPerFrame >= 2
								LDA !Freeram_SpriteHP_BarAnimationFill,x	;\Decrement fill
								SEC						;|
								SBC.b #!Setting_SpriteHP_BarEmptyPerFrame	;/
								BCC .....Underflow				;>Underflow check
								CMP $00						;\Check if record decrements past the current HP.
								BCS .....Decrement				;/
								
								.....Underflow
									LDA $00						;\Set record to current if it did goes past.
									STA !Freeram_SpriteHP_BarAnimationFill,x	;/
									BRA ...AnimationDone
								
								.....Decrement
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
		LDA !Freeram_SpriteHP_MeterState
		CMP #$FF
		BEQ ..ClearEveryFrame
		CMP #$FE
		BEQ ..ClearItselfOnlyOnce
		CMP #$FD
		BEQ ..AlreadyClearedOnce
		
		..ClearItselfOnlyOnce
			LDA #$FD
			STA !Freeram_SpriteHP_MeterState
		..ClearEveryFrame
		
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
		..AlreadyClearedOnce
	.Done
	PLB
	RTL