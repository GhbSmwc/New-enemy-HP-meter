;Insert this as level.

;This ASM code displays the enemy's HP on the HUD of the most recent enemy the player
;have dealt damage to. If total HP mode is active, then it instead will display the
;HP of all active sprites, plus optionally whatever value stored in RAM defined
;as "!Freeram_SpriteHP_TotalHPOfUnloadedSprites".

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
		LDX.b #(!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat	;>2 !Setting_SpriteHP_MaxDigits due to 2 numbers displayed, plus 1 because of the "/" symbol.
		-
		LDA #!StatusBarBlankTile
		if !Setting_SpriteHP_NumericalTextAlignment == 1
			STA !Setting_SpriteHP_Numerical_StatusBarAddrTile,x
		elseif !Setting_SpriteHP_NumericalTextAlignment == 2
			STA !Setting_SpriteHP_NumericalRightAligned_StatusBarAddrTile-((!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
		endif
		if !StatusBar_UsingCustomProperties != 0
			LDA.b #!Setting_SpriteHP_NumericalProp
			if !Setting_SpriteHP_NumericalTextAlignment == 1
				STA !Setting_SpriteHP_Numerical_StatusBarAddrProp,x
			elseif !Setting_SpriteHP_NumericalTextAlignment == 2
				STA !Setting_SpriteHP_NumericalRightAligned_StatusBarAddrProp-((!Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
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
			LDA.b #!Setting_SpriteHP_GraphicalBar_TotalPieces	;\Default with the animation fill amount being full.
			STA !Freeram_SpriteHP_BarAnimationFill				;/
			if !Setting_SpriteHP_BarChangeDelay != 0
				LDA.b #!Setting_SpriteHP_BarChangeDelay			;\Default with the delay timer being set
				STA !Freeram_SpriteHP_BarAnimationTimer			;/
			endif
		endif
		LDX.b #!sprite_slots-1
		..Loop
			;This defaults HP for 12 or 22 sprite slots to having 0 HP out of 1 HP (failsafe).
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
						CMP #$01					;\This is a failsafe so when a spawning indicator turns into an enemy sprite, its $14C8,x == $01
						BEQ .....ValidSpriteState	;/and on that very same frame, !Freeram_SpriteHP_TotalHPOfUnloadedSprites gets deducted. Without this, this frame would've have a net loss of every enemy with $14C8,x == $01.
						CMP #$07					;\$00: No sprite, $02-$06: Various killed states, count that as 0 HP
						BCC .....Next				;/
						CMP #$0C					;\$07-$0B: Alive state
						BCC .....ValidSpriteState	;/
						BRA .....Next				;>Anything else, count as 0 HP.
						.....ValidSpriteState
						JSR .CheckForBlacklistedSpritesTotalHP	;\Blacklisted state = 0 HP
						BCS .....Next							;/
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
						JML .DisplayNumerical ;>Skip executing the following code related to the meter being on a specific sprite slot.
		endif
	.CheckIfSpriteStateValid
		..DisplayMeter
			LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
			LDA !14C8,x				;\If sprite exists, allow meter to show, otherwise hide it.
			BNE ...Exists			;/
				;^Note: if a sprite status gets set to #$00, and at the same frame, a new sprite spawns on the same slot
				; that have its status set to #$00, the meter could transfer to the newly spawned sprite. A way to prevent
				; that is anytime $14C8,x gets set to 0, clear the meter by executing "JSL !HideHPMeterIfSpriteDespawns".
			...HideHPMeter
				LDA #$FF				;\Hide HP for non-existing sprites, sprites that have HP in certain cases
				STA !Freeram_SpriteHP_MeterState	;/(like before it was turned into a coin from a fireball, or bob-omb exploding)
				JMP .Done
			...Exists
				JSR .CheckForBlacklistedSprites
				BCS ...HideHPMeter				;>If sprite becomes a blacklisted state the meter is on, hide the meter
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
				%WriteFixedDigitsToLayer3(!Setting_SpriteHP_Numerical_StatusBarAddrTile, !Setting_SpriteHP_Numerical_StatusBarAddrProp)
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
					%WriteTileAddress(!Setting_SpriteHP_Numerical_StatusBarAddrTile, !Setting_SpriteHP_Numerical_StatusBarAddrProp, !Setting_SpriteHP_NumericalProp)
				elseif !Setting_SpriteHP_NumericalTextAlignment == 2
					%WriteTileAddress(!Setting_SpriteHP_NumericalRightAligned_StatusBarAddrTile, !Setting_SpriteHP_NumericalRightAligned_StatusBarAddrProp, !Setting_SpriteHP_NumericalProp)
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
				JSL !SharedSub_SetEnemyHPBarAttributes
				LDX !Scratchram_SpriteHP_SpriteSlotToDisplay
				PHX
				if !Setting_SpriteHP_BarFillRoundDirection == 0
					JSL !SharedSub_CalculateGraphicalBarPercentage
				elseif !Setting_SpriteHP_BarFillRoundDirection == 1
					JSL !SharedSub_CalculateGraphicalBarPercentageRoundDown
				elseif !Setting_SpriteHP_BarFillRoundDirection == 2
					JSL !SharedSub_CalculateGraphicalBarPercentageRoundUp
				endif
				;$00~$01 = percentage, Y = rounding 0 or 100 state
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
							if !Setting_SpriteHP_TotalHPMode
								CMP.b #!sprite_slots*2
								BCC .....ConvertIntroFillSlotsToRegularSlots		;>Is intro-fill of the sprite slots
								BEQ .....AlreadyTerminated							;>Total HP mode (not the intro-fill version)
								CMP.b #(!sprite_slots*2)+2
								BCC .....ConvertTotalModeIntroFillToJustTotalMode	;>Total HP mode Intro-fill
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
						if and(notequal(!Setting_SpriteHP_EmptyDelayFrames, 0), less(!Setting_SpriteHP_BarEmptyPerFrame, 2)) ;User opted for decreasing fill by 1 or less per frame.
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
				if !Setting_SpriteHP_BarExtendLeft == 0
					LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrTile
					STA $00
					LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrTile>>8
					STA $01
					LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrTile>>16
					STA $02
				else
					LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrTile
					STA $00
					LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrTile>>8
					STA $01
					LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrTile>>16
					STA $02
				endif
				if !StatusBar_UsingCustomProperties != 0
					if !Setting_SpriteHP_BarExtendLeft == 0
						LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrProp
						STA $03
						LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrProp>>8
						STA $04
						LDA.b #!Setting_SpriteHP_GraphicalBar_StatusBarAddrProp>>16
						STA $05
					else
						LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrProp
						STA $03
						LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrProp>>8
						STA $04
						LDA.b #!Setting_SpriteHP_GraphicalBarExtendLeft_StatusBarAddrProp>>16
						STA $05
						if !StatusbarFormat == $01
							JSL !SharedSub_GraphicalBarExtendLeft
						else
							JSL !SharedSub_GraphicalBarExtendLeftFormat2
						endif
					endif
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
				if !Setting_SpriteHP_GraphicalBar_VariableMiddleLength == 0
					LDX.b #(!Setting_SpriteHP_GraphicalBar_TotalTiles-1)*!StatusbarFormat
				else
					LDX.b #(!Setting_SpriteHP_GraphicalBar_TotalTilesVariableLengthMax-1)*!StatusbarFormat
				endif
				...Loop
					LDA.b #!StatusBarBlankTile
					if !Setting_SpriteHP_LeftwardsBar == 0
						STA !Setting_SpriteHP_GraphicalBar_StatusBarAddrTile,x
					else
						STA !Setting_SpriteHP_GraphicalBarExtendLeftClear_StatusBarAddrTile,x
					endif
					LDA.b #!Setting_SpriteHP_GraphicalBarProp
					if !Setting_SpriteHP_LeftwardsBar == 0
						STA !Setting_SpriteHP_GraphicalBar_StatusBarAddrProp,x
					else
						STA !Setting_SpriteHP_GraphicalBarExtendLeftClear_StatusBarAddrProp,x
					endif
					....Next
						DEX #!StatusbarFormat
						BPL ...Loop
			endif
		..AlreadyClearedOnce
	.Done
	PLB
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Check for conditionally-blacklisted sprites.
;
;This subroutine is used to prevent showing HP of sprites that shouldn't use the
;HP system based on its state or it changing to another sprite. This runs every
;frame while the meter is active, and espically so during total HP mode. If it's
;a sprite that is blacklisted reguardless of its state, then don't include it
;here but instead, open "HPSystemForSMWSprites.asm", and a table labeled
;".DefaultSMWSprHP" or ".DefaultCustSprHP", set its default HP value to "00000".
;
;Notes:
;
; - This code runs at the beginning of each frame, not during sprite code
;   processing. For example, reading $14C8,x here, on the frame the player kills
;   the sprite with a spinjump will obtain a value of $04 (killed with spinjump)
;   rather than the value it was before the player kills it.
;
;To add a sprite number here you wish not to show/use the HP system based on its
;state, the syntax is:
; - %SpriteHPMeterBlacklist(SpriteNumber, Label)
; - %SpriteHPMeterBlacklist_UnlimitedDistance(SpriteNumber, Label)
;    ;^Use this instead of "SpriteHPMeterBlacklist" if you have
;    ; branch-out-of-bounds issues.
; - %SpriteHPMeterBlacklist_Range(SpriteNumberMin, SpriteNumberMax, Label)
;    ;^Use this if you have consecutive values of blacklisted sprite numbers.
;    ; This is automatically immune to branch-out-of-bounds errors.
;Legend:
; - SpriteNumber is obvious (enter $xx where xx is the hexadecimal value of the
;   sprite number), including the min and max variants.
; - Label is a label that specifies a jump if equal to or in between min and
;   max. Oftentimes you can just branch to "..Blacklisted", or for conditionally
;   blacklisted sprites, add your own label and code for checking the state of
;   the sprite.
;
;Input:
; - X: Sprite slot to check
;Output:
; - Carry:
; -- Clear (0): if it should be allowed to show HP of it.
; -- Set (1): if it should not be allowed to show HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.CheckForBlacklistedSprites
		LDA !Freeram_SpriteHP_MaxHPLow,x		;\This is a failsafe if some faulty code runs
		if !Setting_SpriteHP_TwoByte			;|that would attempt to set the HP meter to
			ORA !Freeram_SpriteHP_MaxHPHi,x		;|be on an always-blacklisted sprite with 0
		endif									;|max HP (set by HPSystemForSMWSprites.asm),
		BNE ..HasValidHP						;|would just hide the meter. Also prevents
		SEC										;|a division by zero when calculating fill
		RTS										;/amount in bar.
		
		..HasValidHP
		
		if !Setting_SpriteHP_UsingCustomSprites
			LDA !7FAB10,x			;\If sprite is custom, allow display
			AND.b #%00001000		;/(can be overridden within sprite code to not display)
			BNE ..CustomSprite		;>For custom sprites, you'll need to edit the custom sprite's code.
		endif
		..VanillaSprite
			LDA !9E,x
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;Here is the conditionally-blacklisted vanilla sprite numbers.
			;Most sprites that don't get damaged doesn't even call
			;such subroutines, thus they don't need to be listed here,
			;except for total HP mode (see ".CheckForBlacklistedSpritesTotalHP").
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				if !Setting_SpriteHP_VanillaSprite_OneShotSprites
					%SpriteHPMeterBlacklist($0D, ...BobOmb) ;>Bobomb (blacklisted if its an explosion)
					%SpriteHPMeterBlacklist_Range($04, $07, ...KoopasAndEmptyShell) ;>Determine if the koopa shell is empty or not.
					%SpriteHPMeterBlacklist($09, ...WingedBouncingKoopa) ;>Sprite $DF is techinically sprite $09, just in a stunned state
				endif
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;Keep this here (other than listed is allowed by default)
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					...Allowed
						CLC
						RTS
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;Custom handler for conditionally-blacklisted vanilla sprites here.
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				if !Setting_SpriteHP_VanillaSprite_OneShotSprites
					...BobOmb
						LDA !1534,x
						BNE ...Blacklisted	;>If its an explosion, it's blacklisted
						CLC
						RTS
					...KoopasAndEmptyShell ;>Blacklist the sprite if its an empty shell.
						JSR .CheckIfShellEmpty
						BCS ...Blacklisted
						CLC
						RTS
					...WingedBouncingKoopa
						LDA !14C8,x
						CMP #$09
						BCC ...Allowed
				endif
				...Blacklisted
					SEC
					RTS
		if !Setting_SpriteHP_UsingCustomSprites
			..CustomSprite
				LDA !7FAB9E,x
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;Here is the conditionally-blacklisted for custom sprite numbers
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				
				
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					;Keep this here (other than listed is allowed by default)
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						...Allowed
							CLC
							RTS
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;Custom handler for conditionally blacklisted custom sprites here.
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					...Blacklisted
						SEC
						RTS
		endif
	if !Setting_SpriteHP_VanillaSprite_OneShotSprites
		.CheckIfShellEmpty
			;Since the sprite numbers and custom flags are already checked, we only need $14C8, $1540, $1558, and $187B to identify if it's a empty shell.
			LDA !14C8,x
			CMP #$02
			BEQ ..KoopaInside
				;^This is a "maybe" state, since it happens after its $14C8,x set to #$02 ($14C8,x could be any value prior). It is up to the code from the patch to
				;determine should the HP meter to show HP of this sprite.
			CMP #$07
			BEQ ..InYoshiMouth
				;^When a koopa inside its shell in yoshi's mouth, its stun timer still runs, and when the timer expire, they get deleted in their shells inside yoshi's mouth.
				; That explains why holding a koopa-in-shell (after stunning it with a quake, bounce block, or cape spin) in yoshi's mouth, that the meter could disappear
				; some time later.
			CMP #$0A
			BEQ ..Kicked
				;^When a koopa-in-shell is kicked, timer that expired are ignored. At this point $C2 is the only and reliable way to check if koopa is inside ($C2 != #$00)
			CMP #$0B
			BEQ ..Carried
			BRA ..KoopaInside
			..InYoshiMouth
			..Carried
			LDA !187B,x			;\Check if disco shell
			BNE ..KoopaInside	;/
			;Is in a status that have no koopa inside the stunned shell?
			;Note that I did not check RAM $C2 (result of $1540|$1558) because
			;it hasn't been updated yet (just in case).
				LDA !1540,x
				ORA !1558,x
				BNE ..KoopaInside
			BRA ..IsEmptyShell
			..Kicked
				LDA !C2,x
				BNE ..KoopaInside
			..IsEmptyShell
				;Empty shell (don't allow showing health meter)
				SEC
				RTS
			..KoopaInside
				;Koopa inside (entitle showing health meter)
				CLC
				RTS
	endif
if !Setting_SpriteHP_TotalHPMode
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Check for conditionally blacklisted sprites, for total HP mode
	;Same as before.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.CheckForBlacklistedSpritesTotalHP
			if !Setting_SpriteHP_UsingCustomSprites
				LDA !7FAB10,x			;\If sprite is custom, allow display
				AND.b #%00001000		;/(can be overridden within sprite code to not display)
				BNE ..CustomSprite		;>For custom sprites, you'll need to edit the custom sprite's code.
			endif
			..VanillaSprite
				LDA !9E,x
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;Here is the blacklist for vanilla sprite numbers.
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					%SpriteHPMeterBlacklist($0D, ...Blacklisted) ;>Bobomb (blacklisted if its an explosion, or as a summoned sprite)
					
					
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					;Keep this here (other than listed is allowed by default)
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						...Allowed
							CLC
							RTS
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;Custom handler for conditionally blacklisted sprites here.
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					...Blacklisted
						SEC
						RTS
			if !Setting_SpriteHP_UsingCustomSprites
				..CustomSprite
					LDA !7FAB9E,x
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					;Here is the blacklist for custom sprite numbers
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					
						;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						;Keep this here (other than listed is allowed by default)
						;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							...Allowed
								CLC
								RTS
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					;Custom handler for conditionally blacklisted custom sprites here.
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						...Blacklisted
							SEC
							RTS
			endif
endif