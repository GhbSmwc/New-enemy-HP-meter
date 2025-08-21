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

macro ClearNumerical()
	LDX.b #(Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat	;>2 Setting_SpriteHP_MaxDigits due to 2 numbers displayed, plus 1 because of the "/" symbol.
	-
	LDA #!StatusBarBlankTile
	if !Setting_SpriteHP_NumericalTextAlignment == 1
		STA !Setting_SpriteHP_NumericalPos_XYPos,x
	elseif !Setting_SpriteHP_NumericalTextAlignment == 2
		STA !Setting_SpriteHP_NumericalPosRightAligned_XYPos-((Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
	endif
	if !StatusBar_UsingCustomProperties != 0
		LDA.b #!Setting_SpriteHP_NumericalProp
		if !Setting_SpriteHP_NumericalTextAlignment == 1
			STA !Setting_SpriteHP_NumericalPos_XYPosProp,x
		elseif !Setting_SpriteHP_NumericalTextAlignment == 2
			STA !Setting_SpriteHP_NumericalPosRightAligned_XYPosProp-((Setting_SpriteHP_MaxStringLength-1)*!StatusbarFormat),x
		endif
	endif
	DEX #!StatusbarFormat
	BPL -
endmacro

macro GetHealthDigits8Bit(ValueToDisplay)
		LDA <ValueToDisplay>
		STA $00
		STZ $01
		%UberRoutine(SixteenBitHexDecDivision)
endmacro

macro GetHealthDigits16Bit(ValueToDisplayLo, ValueToDisplayHi)
		LDA <ValueToDisplay>
		STA $00
		LDA <ValueToDisplayHi>
		STA $01
		%UberRoutine(SixteenBitHexDecDivision)
endmacro

init:
	LDA #$FF
	STA SpriteHPDataStructure.SpriteSlot
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
	LDA !Freeram_SpriteHP_SlotToDisplayHP
	CMP.b #!sprite_slots
	BCS .ClearHPDisplay
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
			if or(equal(!Setting_SpriteHP_NumericalTextAlignment, 0), equal(!IsUsingRightAlignedSingleNumber, 1)) ;Fixed digit location
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("!Freeram_SpriteHP_CurrentHPLow,x")
				else
					%GetHealthDigits16Bit("!Freeram_SpriteHP_CurrentHPLow,x", "!Freeram_SpriteHP_CurrentHPHi,x")
				endif
				%UberRoutine(RemoveLeadingZeroes16Bit)
				%WriteFixedDigitsToLayer3(!Setting_SpriteHP_NumericalPos_XYPos, !Setting_SpriteHP_NumericalPos_XYPosProp)
			elseif and(greaterequal(!Setting_SpriteHP_NumericalTextAlignment, 1), lessequal(!Setting_SpriteHP_NumericalTextAlignment, 2)) ;left/right aligned
				if !Setting_SpriteHP_TwoByte == 0
					%GetHealthDigits8Bit("!Freeram_SpriteHP_CurrentHPLow,x")
				else
					%GetHealthDigits16Bit("!Freeram_SpriteHP_CurrentHPLow,x", "!Freeram_SpriteHP_CurrentHPHi,x")
				endif
				LDX #$00
				%UberRoutine(SuppressLeadingZeroes)
				if !Setting_SpriteHP_DisplayNumerical == 2
					LDA #!StatusBarSlashCharacterTileNumb
					STA !Scratchram_CharacterTileTable,x
					INX
					if !Setting_SpriteHP_TwoByte == 0
						%GetHealthDigits("!Freeram_SpriteHP_MaxHPLow")
					else
						%GetHealthDigits("!Freeram_SpriteHP_MaxHPLow", "!Freeram_SpriteHP_MaxHPHi")
					endif
					%UberRoutine(SuppressLeadingZeroes)
				endif
				if !Setting_SpriteHP_ExcessDigitProt
					CPX.b #(Setting_SpriteHP_MaxStringLength+1)
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
			endif
		endif
	
	BRA .Done
	.ClearHPDisplay
		..ClearNumerical
			if !Setting_SpriteHP_DisplayNumerical != 0
			
			endif
	
	.Done
	PLB
	RTL