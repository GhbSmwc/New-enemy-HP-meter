;Insert this as level.

;This ASM code displays the enemy's HP on the HUD of the most recent enemy the player
;have dealt damage to.

incsrc "../SharedSubroutineDefs.asm"
incsrc "../StatusBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"
incsrc "../GraphicalBarDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"

;Status bar display handler macros
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
			JSL !SharedSub_WriteStringDigitsToHUD
		else
			JSL !SharedSub_WriteStringDigitsToHUDFormat2
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
			JSL !SharedSub_SixteenBitHexDecDivision
	endmacro
	
	macro GetHealthDigits16Bit(ValueToDisplayLo, ValueToDisplayHi)
			LDA !<ValueToDisplayLo>
			STA $00
			LDA !<ValueToDisplayHi>
			STA $01
			JSL !SharedSub_SixteenBitHexDecDivision
	endmacro
	
	macro ConvertToRightAligned()
		if !StatusbarFormat == $01
			JSL !SharedSub_ConvertToRightAligned
		else
			JSL !SharedSub_ConvertToRightAlignedFormat2
		endif
	endmacro
;Blacklisted sprite macros
	macro SpriteHPMeterBlacklist(SpriteNumb, LabelToJump)
		CMP.b #<SpriteNumb>
		BEQ <LabelToJump>
	endmacro
	
	macro SpriteHPMeterBlacklist_UnlimitedDistance(SpriteNumb, LabelToJump)
		CMP.b #<SpriteNumb>
		BNE ?+
		JMP <LabelToJump>
		?+
	endmacro
	
	macro SpriteHPMeterBlacklist_Range(SpriteNumbMin, SpriteNumbMax, LabelToJump)
		assert <SpriteNumbMin> <= <SpriteNumbMax>, "blacklisted sprite range's minimum is greater than max."
		CMP.b #clamp(<SpriteNumbMin>, $00, $FF)
		BCC ?+
		if <SpriteNumbMax>+1 < $FF
			CMP.b #<SpriteNumbMax>+1
			BCS ?+
		endif
		JMP <LabelToJump>
		?+
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
		if !Setting_SpriteHP_BarAnimation
			LDA.b #!Setting_SpriteHP_GraphicalBar_TotalPieces
			STA !Freeram_SpriteHP_BarAnimationFill
			if !Setting_SpriteHP_BarChangeDelay != 0
				LDA.b #!Setting_SpriteHP_BarChangeDelay
				STA !Freeram_SpriteHP_BarAnimationTimer
			endif
		endif
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
	.HPMeterStateCheck
		LDA !Freeram_SpriteHP_MeterState
		if !Setting_SpriteHP_BarAnimation == 0
			;With no bar animation, then only 0 to 11 or 0 to 21 are valid
			CMP.b #!sprite_slots
		else
			;LoROM: Index ranging 0 to 11 and 12 to 23 are valid.
			;SA-1: Index ranging from 0 to 21 and 22 to 43 are valid.
			CMP.b #!sprite_slots*2
		endif
		BCC ..IndividualSpritesHPMode							;>Valid range, continue (failsafe)
		if !Setting_SpriteHP_TotalHPMode
			CMP #(!sprite_slots*2)+2
			BCC ..TotalHPMode
		endif
		JMP .ClearHPDisplay						;>Failsafe
		..IndividualSpritesHPMode
			if !Setting_SpriteHP_BarAnimation
				CMP.b #!sprite_slots					;This gets the equivilant sprite slots
				BCC ...NonIntroFillMode
				...IntroFillMode
					SEC
					SBC.b #!sprite_slots
				...NonIntroFillMode
					STA !Scratchram_SpriteHP_SpriteSlotToDisplay
			else
				STA !Scratchram_SpriteHP_SpriteSlotToDisplay
			endif
			TAX
			LDA !Freeram_SpriteHP_CurrentHPLow,x
			STA !Scratchram_GraphicalBar_FillByteTbl
			LDA !Freeram_SpriteHP_MaxHPLow,x
			STA !Scratchram_GraphicalBar_FillByteTbl+2
			if !Setting_SpriteHP_TwoByte == 0
				LDA #$00
				STA !Scratchram_GraphicalBar_FillByteTbl+1
				STA !Scratchram_GraphicalBar_FillByteTbl+3
			else
				LDA !Freeram_SpriteHP_CurrentHPHi,x
				STA !Scratchram_GraphicalBar_FillByteTbl+1
				LDA !Freeram_SpriteHP_MaxHPHi,x
				STA !Scratchram_GraphicalBar_FillByteTbl+3
			endif
		if !Setting_SpriteHP_TotalHPMode
			BRA .CheckIfSpriteStateValid
			..TotalHPMode
				...GetTotalHPOfLoaded
					if !Setting_SpriteHP_TwoByte == 0
						LDA #$00
						STA !Scratchram_GraphicalBar_FillByteTbl+1              ;>Rid high byte
						if !Setting_SpriteHP_TotalHPMode == 2
							LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites
						endif
						STA !Scratchram_GraphicalBar_FillByteTbl
					else
						REP #$20
						if !Setting_SpriteHP_TotalHPMode == 2
							LDA !Freeram_SpriteHP_TotalHPOfUnloadedSprites      ;>Start with amount of HP of unloaded sprites before adding HPs of the loaded
						else
							LDA #$0000                                          ;>Start at zero and only count what's loaded
						endif
						STA !Scratchram_GraphicalBar_FillByteTbl
						SEP #$20
					endif
					LDX.b #!sprite_slots-1
					....Loop
						LDA !14C8,x
						CMP #$08
						BNE .....Next
						JSR .CheckForBlacklistedSpritesTotalHP
						BCS .....Next
						LDA !Freeram_SpriteHP_CurrentHPLow,x
						CLC
						ADC !Scratchram_GraphicalBar_FillByteTbl
						STA !Scratchram_GraphicalBar_FillByteTbl
						if !Setting_SpriteHP_TwoByte
							LDA !Freeram_SpriteHP_CurrentHPHi,x
							ADC !Scratchram_GraphicalBar_FillByteTbl+1
							STA !Scratchram_GraphicalBar_FillByteTbl+1
						endif
						.....Next
							DEX
							BPL ....Loop
					....SetMaxHP
						if !Setting_SpriteHP_TwoByte
							REP #$20
						endif
						LDA !Freeram_SpriteHP_TotalMaxHP
						STA !Scratchram_GraphicalBar_FillByteTbl+2
						if !Setting_SpriteHP_TwoByte
							SEP #$20
						endif
						if !Setting_SpriteHP_TwoByte == 0
							LDA #$00
							STA !Scratchram_GraphicalBar_FillByteTbl+3
						endif
						JML .DisplayNumerical
		endif
	.CheckIfSpriteStateValid
		..DisplayMeter
			LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
			LDA !14C8,x				;>Sprite status table
			BNE ...Exists				;>If exists, allow HP to be displayed.
			
			...HideHPMeter
				LDA #$FF				;\Hide HP for non-existing sprites, sprites that have HP in certain cases
				STA !Freeram_SpriteHP_MeterState	;/(like before it was turned into a coin from a fireball, or bob-omb exploding)
				JMP .Done
			...Exists
				JSR .CheckForBlacklistedSprites
				BCS ...HideHPMeter
			...DisplayNormally
	.DisplayNumerical
		;After this point:
		; - !Scratchram_GraphicalBar_FillByteTbl (and !Scratchram_GraphicalBar_FillByteTbl+1) are used as scratch RAM to either
		;   hold the amount of either the HP of a selected sprite, or the total HP across many sprites.
		; - !Scratchram_GraphicalBar_FillByteTbl+2 (and !Scratchram_GraphicalBar_FillByteTbl+3) are used as maximum HP for individual
		;   sprites or total maximum HP across multiple sprites
	
		;Detect user trying to make a right-aligned single number (which avoids unnecessarily use suppress leading zeroes)
			!IsUsingRightAlignedSingleNumber = and(equal(!Setting_SpriteHP_NumericalTextAlignment, 2),equal(!Setting_SpriteHP_DisplayNumerical, 1))
		if !Setting_SpriteHP_DisplayNumerical != 0 ;User allow displaying HP numerically
			;Clear the tiles. To prevent leftover "ghost" tiles that should've
			;disappear when the number of digits decreases (so when "10" becomes "9",
			;won't display "90").
			if !IsUsingRightAlignedSingleNumber == 0 ;if using suppressed zeroes
				%ClearNumerical()
			endif
			..IndividualSpriteWriteString
			if or(equal(!Setting_SpriteHP_NumericalTextAlignment, 0), equal(!IsUsingRightAlignedSingleNumber, 1)) ;Fixed digit location
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("Scratchram_GraphicalBar_FillByteTbl")
				else
					%GetHealthDigits16Bit("Scratchram_GraphicalBar_FillByteTbl", "Scratchram_GraphicalBar_FillByteTbl+1")
				endif
			
				JSL !SharedSub_RemoveLeadingZeroes16Bit
				%WriteFixedDigitsToLayer3(!Setting_SpriteHP_NumericalPos_XYPos, !Setting_SpriteHP_NumericalPos_XYPosProp)
			elseif and(greaterequal(!Setting_SpriteHP_NumericalTextAlignment, 1), lessequal(!Setting_SpriteHP_NumericalTextAlignment, 2)) ;left/right aligned
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("Scratchram_GraphicalBar_FillByteTbl")
				else
					%GetHealthDigits16Bit("Scratchram_GraphicalBar_FillByteTbl", "Scratchram_GraphicalBar_FillByteTbl+1")
				endif
				LDX #$00
				JSL !SharedSub_SuppressLeadingZeros
				if !Setting_SpriteHP_DisplayNumerical == 2 ;>Current/Max display
					LDA #!StatusBarSlashCharacterTileNumb
					STA !Scratchram_CharacterTileTable,x
					INX
					if !Setting_SpriteHP_TwoByte == 0
						%GetHealthDigits8Bit("Scratchram_GraphicalBar_FillByteTbl+2")
					else
						%GetHealthDigits16Bit("Scratchram_GraphicalBar_FillByteTbl+2", "Scratchram_GraphicalBar_FillByteTbl+3")
					endif
					JSL !SharedSub_SuppressLeadingZeros
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
				PHX
				if !Setting_SpriteHP_BarFillRoundDirection == 0
					JSL !SharedSub_CalculateGraphicalBarPercentage
				elseif !Setting_SpriteHP_BarFillRoundDirection == 1
					JSL !SharedSub_CalculateGraphicalBarPercentageRoundDown
				elseif !Setting_SpriteHP_BarFillRoundDirection == 2
					JSL !SharedSub_CalculateGraphicalBarPercentageRoundUp
				endif
				;$00~$01 = percentage
				if !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 1
					JSL !SharedSub_GraphicalBarRoundAwayEmpty
				elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 2
					JSL !SharedSub_GraphicalBarRoundAwayFull
				elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 3
					JSL !SharedSub_GraphicalBarRoundAwayEmptyFull
				endif
				PLX
				if !Setting_SpriteHP_BarAnimation
					if !Setting_SpriteHP_BarChangeDelay
						LDA !Freeram_SpriteHP_BarAnimationTimer
						BEQ ...TimerEnded
						DEC
						STA !Freeram_SpriteHP_BarAnimationTimer
						...TimerEnded
					endif
					
					LDA $00							;>Fill amount of current HP
					CMP !Freeram_SpriteHP_BarAnimationFill			;>Fill amount of previous HP prior damage/recovery
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
							LDA !Freeram_SpriteHP_BarAnimationTimer
							BNE ....ShowFilllingUp
						endif
						....IncreaseFill
							LDA !Freeram_SpriteHP_BarAnimationFill
							if !Setting_SpriteHP_BarFillUpPerFrame >= 2
								CLC
								ADC.b #!Setting_SpriteHP_BarFillUpPerFrame
								BCS .....IncrementPast
								CMP $00
								BCC .....Increment
								
								.....IncrementPast
									LDA $00
									STA !Freeram_SpriteHP_BarAnimationFill
									BRA ....ShowFilllingUp
								.....Increment
									STA !Freeram_SpriteHP_BarAnimationFill
							else
								INC
								STA !Freeram_SpriteHP_BarAnimationFill
							endif
						....ShowFilllingUp
							.....TerminateIntroFillIfAtCurrentHP
								LDA !Freeram_SpriteHP_MeterState
								CMP.b #!sprite_slots
								BCC ......NoTerminate
								LDA !Freeram_SpriteHP_BarAnimationFill
								CMP $00
								BCC ......NoTerminate
								
								......Terminate
									LDA !Freeram_SpriteHP_MeterState
									if !Setting_SpriteHP_TotalHPMode
										CMP.b #!sprite_slots*2  ;>Total HP, main mode.
										BEQ ......NoTerminate
										CMP.b #(!sprite_slots*2)+1   ;>Total HP, introfill
										BEQ .......TotalHPTerminate
									endif
									SEC
									SBC.b #!sprite_slots
									STA !Freeram_SpriteHP_MeterState
									if !Setting_SpriteHP_TotalHPMode
										BRA ......NoTerminate
										.......TotalHPTerminate
											DEC A
											STA !Freeram_SpriteHP_MeterState
									endif
								......NoTerminate
							if !Setting_SpriteHP_ShowHealedTransparent
								LDA !Freeram_SpriteHP_MeterState
								CMP.b #!sprite_slots
								BCS .....IntroFill
								LDA $13
								AND.b #%00000001
								BNE .....FillSoundEffect ;On odd frames, show current HP fill
								.....IntroFill
							endif
							LDA !Freeram_SpriteHP_BarAnimationFill		;\Show animation fill.
							STA $00						;/
							.....FillSoundEffect
								if !Setting_SpriteHP_FillingSFXNumb
									LDA $13D4|!addr					;>Pause flag
									if !Setting_SpriteHP_BarChangeDelay
										ORA !Freeram_SpriteHP_BarAnimationTimer	;>Fill freeze timer
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
							CMP.b #!sprite_slots*2
							if !Setting_SpriteHP_TotalHPMode
								BCC .....ConvertIntroFillSlotsToRegularSlots
								BEQ .....AlreadyTerminated
								CMP.b #(!sprite_slots*2)+2
								BCC .....ConvertTotalModeIntroFillToJustTotalMode
							endif
							.....ConvertIntroFillSlotsToRegularSlots
								SEC
								SBC.b #!sprite_slots
								BRA .....Write
							.....ConvertTotalModeIntroFillToJustTotalMode
								DEC A
							.....Write
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
								LDA !Freeram_SpriteHP_BarAnimationTimer
								BNE ....TransperentAnimation
							endif
						endif
						....DecreaseFill
							if !Setting_SpriteHP_BarEmptyPerFrame >= 2
								LDA !Freeram_SpriteHP_BarAnimationFill		;\Decrement fill
								SEC						;|
								SBC.b #!Setting_SpriteHP_BarEmptyPerFrame	;/
								BCC .....Underflow				;>Underflow check
								CMP $00						;\Check if record decrements past the current HP.
								BCS .....Decrement				;/
								
								.....Underflow
									LDA $00						;\Set record to current if it did goes past.
									STA !Freeram_SpriteHP_BarAnimationFill		;/
									BRA ...AnimationDone
								
								.....Decrement
									STA !Freeram_SpriteHP_BarAnimationFill		;>And set the subtracted value to record
									BRA ....TransperentAnimation
							else
								LDA !Freeram_SpriteHP_BarAnimationFill		;\Decrement by 1
								DEC						;|
								STA !Freeram_SpriteHP_BarAnimationFill		;/
							endif
						....TransperentAnimation
							if !Setting_SpriteHP_ShowDamageTransperent != 0
								LDA $13					;\Alternating frames
								AND.b #%00000001			;/
								BNE ...AnimationDone			;>If odd frame, display current HP.
							endif
							LDA !Freeram_SpriteHP_BarAnimationFill		;\Otherwise if even, display previous HP
							STA $00						;/
					...PreviousAndCurrentHPEqual
					...AnimationDone
					
				endif
				JSL !SharedSub_DrawGraphicalBarSubtractionLoopEdition
				STZ $00									;>Set graphics mode to level layer 3
				JSL !SharedSub_ConvertBarFillAmountToTiles
				
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
						JSL !SharedSub_WriteBarToHUD
					else
						JSL !SharedSub_WriteBarToHUDFormat2
					endif
				else
					if !StatusbarFormat == $01
						JSL !SharedSub_WriteBarToHUDLeftwards
					else
						JSL !SharedSub_WriteBarToHUDLeftwardsFormat2
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Check for blacklisted sprites.
;
;This subroutine is used to prevent showing HP of sprites that shouldn't use the
;HP system based on its state or it changing to another sprite. This runs every
;frame while the meter is active, and espically so during total HP mode.
;
;To add a sprite number here you wish not to show/use the HP system, the syntax
;is:
; - %SpriteHPMeterBlacklist(SpriteNumber, Label)
; - %SpriteHPMeterBlacklist_UnlimitedDistance(SpriteNumber, Label)
;    ;^Use this instead of "SpriteHPMeterBlacklist" if you have
;    ; branch-out-of-bounds issues.
; - %SpriteHPMeterBlacklist_Range(SpriteNumberMin, SpriteNumberMax, Label)
;    ;^Use this if you have consecutive values of blacklisted sprite numbers.
;Legend:
; - SpriteNumber is obvious (enter $xx where xx is the hexadecimal value of the
;   sprite number), including the min and max variants.
; - Label is a label that specifies a jump if equal to or in between min and
;   max. Oftentimes you can just branch to "..Blacklisted", or for conditionally
;   blacklisted sprites, add your own label and code for checking the state of
;   the sprite.
;
;Protip: Most optimized way of handling custom sprites without a massive list
;(which takes up space in the ROM) is to have custom sprites that should have
;HP in one group, sprites that conditionally have HP in another seperate group,
;and sprites that shouldn't at all use it in another seperate group. Then you
;use "SpriteHPMeterBlacklist_Range" on each of these groups.
;
;Input:
; - X: Sprite slot to check
;Output:
; - Carry:
; -- Clear (0): if it should be allowed
; -- Set (1):if it should not be allowed.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.CheckForBlacklistedSprites
		if !Setting_SpriteHP_UsingCustomSprites
			LDA !7FAB10,x			;\If sprite is custom, allow display
			AND.b #%00001000		;/(can be overridden within sprite code to not display)
			BNE ..CustomSprite		;>For custom sprites, you'll need to edit the custom sprite's code.
		endif
		..VanillaSprite
			LDA !9E,x
			;Here is the blacklist for vanilla sprite numbers.
			;Most sprites that don't get damaged doesn't even call
			;such subroutines, thus they don't need to be listed here,
			;except for total HP mode (see ".CheckForBlacklistedSpritesTotalHP").
			%SpriteHPMeterBlacklist($0D, ...BobOmb) ;>Bobomb (blacklisted if its an explosion)
			%SpriteHPMeterBlacklist($21, ..Blacklisted) ;>Moving coin
			...Allowed
				CLC
				RTS
				
			;Custom handler for conditionally blacklisted sprites here.
			...BobOmb
				LDA !1534,x
				BNE ..Blacklisted	;>If its an explosion, it's blacklisted
				BRA ...Allowed
		if !Setting_SpriteHP_UsingCustomSprites
			..CustomSprite
				;Here is the blacklist for custom sprite numbers
				
				...Allowed
					CLC
					RTS
				;Custom handler for conditionally blacklisted custom sprites here.
		endif
		..Blacklisted
			SEC
			RTS
if !Setting_SpriteHP_TotalHPMode
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Check for blacklisted sprites, for total HP mode
	;Same as before, but can be used to prevent showing HP of things like Magikoopa
	;magic and summoned bullet bills.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.CheckForBlacklistedSpritesTotalHP
			if !Setting_SpriteHP_UsingCustomSprites
				LDA !7FAB10,x			;\If sprite is custom, allow display
				AND.b #%00001000		;/(can be overridden within sprite code to not display)
				BNE ..CustomSprite		;>For custom sprites, you'll need to edit the custom sprite's code.
			endif
			..VanillaSprite
				LDA !9E,x
				;Here is the blacklist for vanilla sprite numbers.
				%SpriteHPMeterBlacklist($0D, ..Blacklisted) ;>Bobomb (blacklisted if its an explosion)
				%SpriteHPMeterBlacklist($53, ..Blacklisted) ;>Throwblock
				%SpriteHPMeterBlacklist_Range($55, $5F, ..Blacklisted) ;\Various platforms
				%SpriteHPMeterBlacklist_Range($62, $63, ..Blacklisted) ;/
				%SpriteHPMeterBlacklist($6D, ..Blacklisted) ;>Invisible solid block
				%SpriteHPMeterBlacklist_Range($74, $78, ..Blacklisted) ;>Consumable sprites (powerups, 1-up)
				%SpriteHPMeterBlacklist_Range($83, $84, ..Blacklisted) ;>Flying question blocks
				%SpriteHPMeterBlacklist($8F, ..Blacklisted) ;>Scale platforms
				%SpriteHPMeterBlacklist($9C, ..Blacklisted) ;>Hammer Bro platform
				%SpriteHPMeterBlacklist($A3, ..Blacklisted) ;>Rotating grey platform
				%SpriteHPMeterBlacklist($B1, ..Blacklisted)
				%SpriteHPMeterBlacklist($BB, ..Blacklisted)
				%SpriteHPMeterBlacklist_Range($C0, $C1, ..Blacklisted)
				%SpriteHPMeterBlacklist($C4, ..Blacklisted)
	
				...Allowed
					CLC
					RTS
					
				;Custom handler for conditionally blacklisted sprites here.
			if !Setting_SpriteHP_UsingCustomSprites
				..CustomSprite
					;Here is the blacklist for custom sprite numbers
					
					...Allowed
						CLC
						RTS
					;Custom handler for conditionally blacklisted custom sprites here.
			endif
			..Blacklisted
				SEC
				RTS

endif