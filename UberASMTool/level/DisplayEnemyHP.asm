;Insert this as level.

;This ASM code displays the enemy's HP on the HUD of the most recent enemy the player
;have dealt damage to.

incsrc "../StatusBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"


macro ClearNumerical()
	LDX.b #(((!Setting_SpriteHP_MaxDigits*2)+1)-1)*!StatusbarFormat	;>2 Setting_SpriteHP_MaxDigits due to 2 numbers displayed, plus 1 because of the "/" symbol.
	-
	LDA #!StatusBarBlankTile
	if !Setting_SpriteHP_NumericalTextAlignment == 1
		STA !Setting_SpriteHP_NumericalPos_XYPos,x
	elseif !Setting_SpriteHP_NumericalTextAlignment == 2
		STA !Setting_SpriteHP_NumericalPosRightAligned_XYPos-((((!Setting_SpriteHP_MaxDigits*2)+1)-1)*!StatusbarFormat),x
	endif
	if !StatusBar_UsingCustomProperties != 0
		LDA.b #!Setting_SpriteHP_NumericalProp
		if !Setting_SpriteHP_NumericalTextAlignment == 1
			STA !Setting_SpriteHP_NumericalPos_XYPosProp,x
		elseif !Setting_SpriteHP_NumericalTextAlignment == 2
			STA !Setting_SpriteHP_NumericalPosRightAligned_XYPosProp-((((!Setting_SpriteHP_MaxDigits*2)+1)-1)*!StatusbarFormat),x
		endif
	endif
	DEX #!StatusbarFormat
	BPL -
endmacro

init:
	LDA #$FF
	STA SpriteHPDataStructure.SpriteSlot
	RTL
	
main:
	if !CPUMode
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
		if !Setting_SpriteHP_DisplayNumerical != 0
			;Clear the tiles. To prevent leftover "ghost" tiles that should've
			;disappear when the number of digits decreases (so when "10" becomes "9",
			;won't display "90").
			if !IsUsingRightAlignedSingleNumber == 0 ;if using suppressed zeroes
				%ClearNumerical()
			endif
			if and(greaterequal(!Setting_SpriteHP_NumericalTextAlignment, 1), lessequal(!Setting_SpriteHP_NumericalTextAlignment, 2)) ;left/right aligned
				LDA !Freeram_SpriteHP_SlotToDisplayHP
				TAX
				LDA !Freeram_SpriteHP_CurrentHPLow,x
				STA $00
				if !Setting_SpriteHP_TwoByte == 0
					STZ $01
				else
					LDA !Freeram_SpriteHP_CurrentHPHi,x
					STA $01
				endif
				%UberRoutine(SixteenBitHexDecDivision)
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