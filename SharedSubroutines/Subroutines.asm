	incsrc "SharedSub_Defines/GraphicalBarDefines.asm"
	incsrc "SharedSub_Defines/NumberDisplayRoutinesDefines.asm"
	incsrc "SharedSub_Defines/StatusBarDefines.asm"
	incsrc "SharedSub_Defines/EnemyHPMeterDefines.asm"
	
	
;Subroutine list:
; - MathDiv
; - MathDiv32_16
; - MathMul16_16
; - SixteenBitHexDecDivision
; - RemoveLeadingZeroes16Bit
; - SuppressLeadingZeros
; - WriteStringDigitsToHUD
; - WriteStringDigitsToHUDFormat2
; - ConvertToRightAligned
; - ConvertToRightAlignedFormat2
; - CalculateGraphicalBarPercentage
; - CalculateGraphicalBarPercentageRoundUp
; - CalculateGraphicalBarPercentageRoundDown
; - ConvertBarFillAmountToTiles
; - DrawGraphicalBarSubtractionLoopEdition
; - GraphicalBarRoundAwayEmpty
; - GraphicalBarRoundAwayFull
; - GraphicalBarRoundAwayEmptyFull
; - WriteBarToHUD
; - WriteBarToHUDFormat2
; - WriteBarToHUDLeftwards
; - WriteBarToHUDLeftwardsFormat2
; - GetMaxBarInAForRoundToMaxCheck
; - GraphicalBarNumberOfTiles
; - 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;General math routines.
;Due to the fact that registers have limitations and such.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; unsigned 16bit / 16bit Division
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Arguments
	; $00-$01 : Dividend
	; $02-$03 : Divisor
	; Return values
	; $00-$01 : Quotient
	; $02-$03 : Remainder
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	MathDiv:	REP #$20
			ASL $00
			LDY #$0F
			LDA.w #$0000
	-		ROL A
			CMP $02
			BCC +
			SBC $02
	+		ROL $00
			DEY
			BPL -
			STA $02
			SEP #$20
			RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Unsigned 32bit / 16bit Division
	; By Akaginite (ID:8691), fixed the overflow
	; bitshift by GreenHammerBro (ID:18802)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Arguments
	; $00-$03 : Dividend
	; $04-$05 : Divisor
	; Return values
	; $00-$03 : Quotient
	; $04-$05 : Remainder
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	MathDiv32_16:	REP #$20
			ASL $00
			ROL $02
			LDY #$1F
			LDA.w #$0000
	-		ROL A
			BCS +
			CMP $04
			BCC ++
	+		SBC $04
			SEC
	++		ROL $00
			ROL $02
			DEY
			BPL -
			STA $04
			SEP #$20
			RTL
	if !sa1 == 0
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; 16bit * 16bit unsigned Multiplication
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; Argusment
		; $00-$01 : Multiplicand
		; $02-$03 : Multiplier
		; Return values
		; $04-$07 : Product
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
		MathMul16_16:	REP #$20
				LDY $00
				STY $4202
				LDY $02
				STY $4203
				STZ $06
				LDY $03
				LDA $4216
				STY $4203
				STA $04
				LDA $05
				REP #$11
				ADC $4216
				LDY $01
				STY $4202
				SEP #$10
				CLC
				LDY $03
				ADC $4216
				STY $4203
				STA $05
				LDA $06
				CLC
				ADC $4216
				STA $06
				SEP #$20
				RTL
	else
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; 16bit * 16bit unsigned Multiplication SA-1 version
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; Argusment
		; $00-$01 : Multiplicand
		; $02-$03 : Multiplier
		; Return values
		; $04-$07 : Product
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
		MathMul16_16:	STZ $2250
				REP #$20
				LDA $00
				STA $2251
				ASL A
				LDA $02
				STA $2253
				BCS +
				LDA.w #$0000
		+		BIT $02
				BPL +
				CLC
				ADC $00
		+		CLC
				ADC $2308
				STA $06
				LDA $2306
				STA $04
				SEP #$20
				RTL
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;16-bit hex to 4 (or 5)-digit decimal subroutine (using right-2-left
;division). Example: 12345
; 12345/10 = Q: 1234 R: 5 \These remainders are decimal digits (holds a value $00-$09; unpacked BCD)
; 1234/10  = Q: 123  R: 4 |ordered from least significant digits to most.
; 123/10   = Q: 12   R: 3 |
; 12/10    = Q: 1    R: 2 |
; 1/10     = Q: 0    R: 1 /
;
;Input:
; - $00-$01 = the value you want to display
;Output:
; - !Scratchram_16bitHexDecOutput to !Scratchram_16bitHexDecOutput+4 = a digit 0-9 per byte table
;   (used for 1-digit per 8x8 tile):
; -- !Scratchram_16bitHexDecOutput+$00 = ten thousands
; -- !Scratchram_16bitHexDecOutput+$01 = thousands
; -- !Scratchram_16bitHexDecOutput+$02 = hundreds
; -- !Scratchram_16bitHexDecOutput+$03 = tens
; -- !Scratchram_16bitHexDecOutput+$04 = ones
;
;!Scratchram_16bitHexDecOutput is address $02 for normal ROM and $04 for SA-1.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	SixteenBitHexDecDivision:
		if !sa1 == 0
			PHX
			PHY

			LDX #$04	;>5 bytes to write 5 digits.

			.Loop
			REP #$20	;\Dividend (in 16-bit)
			LDA $00		;|
			STA $4204	;|
			SEP #$20	;/
			LDA.b #10	;\base 10 Divisor
			STA $4206	;/
			JSR .Wait	;>wait
			REP #$20	;\quotient so that next loop would output
			LDA $4214	;|the next digit properly, so basically the value
			STA $00		;|in question gets divided by 10 repeatedly. [Value/(10^x)]
			SEP #$20	;/
			LDA $4216	;>Remainder (mod 10 to stay within 0-9 per digit)
			STA $02,x	;>Store tile

			DEX
			BPL .Loop

			PLY
			PLX
			RTL

			.Wait
			JSR ..Done		;>Waste cycles until the calculation is done
			..Done
			RTS
		else
			PHX
			PHY

			LDX #$04

			.Loop
			REP #$20			;>16-bit XY
			LDA.w #10			;>Base 10
			STA $02				;>Divisor (10)
			SEP #$20			;>8-bit XY
			JSL MathDiv			;>divide
			LDA $02				;>Remainder (mod 10 to stay within 0-9 per digit)
			STA.b !Scratchram_16bitHexDecOutput,x	;>Store tile

			DEX
			BPL .Loop

			PLY
			PLX
			RTL
		endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Leading zeroes remover.
;Writes $FC on all leading zeroes (except the 1s place),
;Therefore, numbers will have leading spaces instead.
;
;Example: 00123 ([$00, $00, $01, $02, $03]) becomes
; __123 ([$FC, $FC, $01, $02, $03])
;
;Call this routine after using: [ThirtyTwoBitHexDecDivision]
;or [SixteenBitHexDecDivision].
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;16-bit version, use after [SixteenBitHexDecDivision]
		RemoveLeadingZeroes16Bit:
		LDX #$00				;>Start at the leftmost digit
		
		.Loop
		LDA !Scratchram_16bitHexDecOutput,x	;\if current digit non-zero, don't omit trailing zeros for the rest of the number string.
		BNE .NonZero				;/
		LDA #!StatusBarBlankTile		;\blank tile to replace leading zero
		STA !Scratchram_16bitHexDecOutput,x	;/
		INX					;>next digit
		CPX.b #$04				;>last digit to check. So that it can display a single 0.
		BCC .Loop				;>if not done yet, continue looping.
		
		.NonZero
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Suppress Leading zeros via left-aligned positioning
;
;This routine takes a 16-bit unsigned integer (works up to 5 digits),
;suppress leading zeros and moves the digits so that the first non-zero
;digit number is located where X is indexed to. Example: the number 00123
;with X = $00:
;
; [0] [0] [1] [2] [3]
;
; Each bracketed item is a byte storing a digit. The X above means the X
; index position.
; After this routine is done, they are placed in an address defined
; as "!Scratchram_CharacterTileTable" like this:
;
;              X
; [1] [2] [3] [*] [*]...
;
; [*] Means garbage and/or unused data. X index is now set to $03, shown
; above.
;
;Usage:
; Input:
;  - !Scratchram_16bitHexDecOutput to !Scratchram_16bitHexDecOutput+4 = a 5-digit 0-9 per byte (used for
;    1-digit per 8x8 tile, using my 4/5 hexdec routine; ordered from high to low digits)
;  - X = the starting location within the table to place the string in. X=$00 means the starting byte.
; Output:
;  - !Scratchram_CharacterTileTable = A table containing a string of numbers with
;    unnecessary spaces and zeroes stripped out.
;  - X = the location to place string AFTER the numbers (increments every character written). Also use
;    for indicating the last digit (or any tile) number for how many tiles to be written to the status
;    bar, overworld border, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SuppressLeadingZeros:
	LDY #$00				;>Start looking at the leftmost (highest) digit
	LDA #$00				;\When the value is 0, display it as single digit as zero
	STA !Scratchram_CharacterTileTable,x	;/(gets overwritten should nonzero input exist)

	.Loop
		LDA.w !Scratchram_16bitHexDecOutput|!dp,Y	;\If there is a leading zero, move to the next digit to check without moving the position to
		BEQ ..NextDigit					;/place the tile in the table
	
		..FoundDigit
			LDA.w !Scratchram_16bitHexDecOutput|!dp,Y	;\Place digit
			STA !Scratchram_CharacterTileTable,x	;/
			INX					;>Next string position in table
			INY					;\Next digit
			CPY #$05				;|
			BCC ..FoundDigit			;/
			RTL
	
		..NextDigit
			INY			;>1 digit to the right
			CPY #$05		;\Loop until no digits left (minimum is 1 digit)
			BCC .Loop		;/
			INX			;>Next item in table
			RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write string to Status bar/OWB+
;
;Input:
; - $00-$02 = 24-bit address location to write to status bar tile number.
; - If tile properties are edit-able (if !StatusBar_UsingCustomProperties != 0):
; -- $03-$05 = Same as $00-$02 but tile properties
; -- $06 = Tile properties to use for all tiles of the string.
; - X = The number of characters to write, ("123" would have X = 3)
; - !Scratchram_CharacterTileTable-(!Scratchram_CharacterTileTable+N-1)
;   the string to write to the status bar.
;Overwritten:
; - X = Will be $FF as it uses a countdown loop.
;
;Note:
; - WriteStringDigitsToHUD is designed for [TTTTTTTT, TTTTTTTT,...], [YXPCCCTT, YXPCCCTT,...]
; - WriteStringDigitsToHUDFormat2 is designed for [TTTTTTTT, YXPCCCTT, TTTTTTTT, YXPCCCTT...]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WriteStringDigitsToHUD:
	DEX
	TXY
	
	.Loop
		LDA !Scratchram_CharacterTileTable,x
		STA [$00],y
		if !StatusBar_UsingCustomProperties != 0
			LDA $06
			STA [$03],y
		endif
		DEX
		DEY
		BPL .Loop
	RTL
WriteStringDigitsToHUDFormat2:
	DEX
	TXA				;\SSB and OWB+ uses a byte pair format.
	ASL				;|
	TAY				;/
	
	.Loop
		LDA !Scratchram_CharacterTileTable,x
		STA [$00],y
		if !StatusBar_UsingCustomProperties != 0
			LDA $06
			STA [$03],y
		endif
		DEX
		DEY #2
		BPL .Loop
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Convert left-aligned to right-aligned.
;
;Use this routine after calling SuppressLeadingZeros and before calling
;WriteStringDigitsToHUD. Note: Be aware that the math of handling the address
;does NOT account to changing the bank byte (address $XX****), so be aware of
;having status bar tables that crosses bank borders ($7EFFFF, then $7F0000,
;as an made-up example, but its unlikely though). This routine basically takes
;a given RAM address stored in $00-$02, subtract by how many tiles (minus 1), then
;$00-$02 is now the left tile position.
;
;Input:
; - $00-$02 = 24-bit address location to write to status bar tile number.
; - If tile properties are edit-able:
; -- $03-$05 = Same as $00-$02 but tile properties.
; - X = The number of characters to write, ("123" would have X = 3)
;Output:
; - $00-$02 and $03-$05 are subtracted by [(NumberOfCharacters-1)*!StatusbarFormat]
;   so that the last character is always at a fixed location and as the number
;   of characters increase, the string would extend leftwards. Therefore,
;   $00-$02 and $03-$05 before calling this routine contains the ending address
;   which the last character will be written.
;
;Note:
; - ConvertToRightAligned is designed for [TTTTTTTT, TTTTTTTT,...], [YXPCCCTT, YXPCCCTT,...]
; - ConvertToRightAlignedFormat2 is designed for [TTTTTTTT, YXPCCCTT, TTTTTTTT, YXPCCCTT...]
; - This routine is meant to be used when displaying 2 numbers (For example: 123/456). Since
;   when displaying a single number, using HexDec and removing leading zeroes (turns them
;   into leading spaces) is automatically right-aligned, using this routine is pointless.
; - X register is not modified here at all.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ConvertToRightAligned:
	TXA					;>Transfer X (number of tiles) to A
	DEC					;>Decrement A (since it's 0-based)
	TAY					;>Transfer A status bar leftmost position to Y (Y is how many tiles of offset by, need this later)
	BRA +
ConvertToRightAlignedFormat2:
	TXA					;>Transfer X (number of tiles) to A
	DEC					;>Decrement A (since it's 0-based)
	ASL					;>Double A (because each tile is 2 bytes, becomming the number of tiles being 0-based)
	TAY					;>Transfer A to Y status bar leftmost position to Y (need this later)
	+
	REP #$21				;\-(NumberOfTiles-1)...
	AND #$00FF				;|
	EOR #$FFFF				;|
	INC A					;/
	ADC $00					;>...+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
	STA $00					;>Store difference in $00-$01
	SEP #$20				;\Handle bank byte
;	LDA $02					;|
;	SBC #$00				;|
;	STA $02					;/
	
	if !StatusBar_UsingCustomProperties != 0
		TYA
		REP #$21				;\-(NumberOfTiles-1)
		AND #$00FF				;|
		EOR #$FFFF				;|
		INC A					;/
		ADC $03					;>+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
		STA $03					;>Store difference in $00-$01
		SEP #$20				;\Handle bank byte
;		LDA $05					;|
;		SBC #$00				;|
;		STA $05					;/
	endif
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Graphical bar routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Calculate ratio of Quantity/MaxQuantity to FilledPieces/TotalMaxPieces.
	;
	;Basically, this routine calculates the "percentage" amount of pieces
	;filled. It does this formula in order for this to work (solve for
	;"FilledPieces"):
	;
	; Cross multiply:
	;
	;   Quantity          FilledPieces
	;   -----------   =   ------------
	;   MaxQuantity       TotalMaxPieces
	;
	; Turns into:
	;
	; (Quantity * TotalMaxPieces)
	; ---------------------------  = FilledPieces
	;        MaxQuantity
	;
	; You may be wondering, why multiply first, and then divide, unlike most modern
	; programmers to calculate a percentage? Well, it is because we are dealing
	; with integers and division (not floating points). After division is performed,
	; the quotient is rounded (division routine alone rounds downwards, but this one
	; here rounds half-up). Performing any rounding before the last step tends to
	; increase (accumulate) the error (how far off from the exact value). It is
	; better to perform rounding ONLY on the final result than anytime before the
	; last operation.
	;
	; Example: 1 out of 3 HP on a 62-pieced bar results 20.[6] pieces filled
	; (bracketed digits means repeating digits).
	;  Division rounding first:
	;   (1 HP / 3 Max HP) * 62 = 0 filled out of 62 pieces in bar. It is off by a huge 20.[6] units.
	;   This is going to result the bar only displaying full or empty, if quantity is less than 50%, will show 0%, otherwise
	;   it will show 100%.
	;  Division rounding last:
	;   (1 HP * 62 pieces) / 3 HP = 21 filled out of 62 pieces in bar. It is off by a tiny 0.[3] units.
	;   Multiplying with 2 integers always results the correct value, unless an overflow occurs, but this
	;   subroutine utilizes "16bit*16bit = 32bit" and "32bit/16bit = R:16bit Q:16bit" subroutines, so 16-bit
	;   overflows during multiplication is impossible.
	;The variables are:
	;*Quantity = the amount of something, say current HP.
	;*MaxQuantity = the maximum amount of something, say max HP.
	;*FilledPieces = the number of pieces filled in the whole bar (rounded 1/2 up).
	; *Note that this value isn't capped (mainly Quantity > MaxQuantity), the
	;  "DrawGraphicalBar" (and "DrawGraphicalBarSubtractionLoopEdition") subroutine will
	;  detect and will not display over max, just in case if you somehow want to use the
	;  over-the-max-value on advance use (such as filling 2 separate bars, filling up
	;  the 2nd one after the 1st is full).
	;*TotalMaxPieces = the number of pieces of the whole bar when full.
	;
	;Input:
	; - !Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl+1:
	;   the quantity.
	; - !Scratchram_GraphicalBar_FillByteTbl+2 to !Scratchram_GraphicalBar_FillByteTbl+3:
	;   the max quantity.
	; - !Scratchram_GraphicalBar_LeftEndPiece: number of pieces in left end
	; - !Scratchram_GraphicalBar_MiddlePiece: same as above but for each middle
	; - !Scratchram_GraphicalBar_RightEndPiece: same as above, but right end
	; - !Scratchram_GraphicalBar_TempLength: number of middle bytes excluding both ends.
	;
	;Output:
	; - $00 to $01: the "percentage" amount of fill in the bar, Rounded:
	; -- CalculateGraphicalBarPercentage: 1/2 up, done by checking if the remainder
	;    after division, is being >= half of the divisor (MaxQuantity)).
	; -- CalculateGraphicalBarPercentageRoundDown: Rounds down an integer.
	; -- CalculateGraphicalBarPercentageRoundUp: Rounds up an integer, if remainder
	;    is nonzero.
	; - Y register: if rounded towards empty (fill amount = 0) or full:
	; -- Y = #$00 if:
	; --- Exactly full (or more, so it treats as if the bar is full if more than enough)
	;     or exactly empty.
	; --- Anywhere between full or empty
	; -- Y = #$01 if rounded to empty (so a nonzero value less than 0.5 pieces filled).
	; -- Y = #$02 if rounded to full (so if full amount is 62, values from 61.5 to 61.9).
	;   This is useful in case you don't want the bar to display completely full or empty
	;   when it is not.
	;Overwritten/Destroyed:
	; - $02 to $09: because math routines need that much bytes.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	CalculateGraphicalBarPercentage:
		JSL CalculateGraphicalBarPercentageRoundDown
		.RoundHalfUp
		..Rounding
			REP #$20
			LDA !Scratchram_GraphicalBar_FillByteTbl+2	;>Max Quantity
			LSR						;>Divide by 2 (halfway point of max).. (LSR would shift bit 0 into carry, thus if number is odd, carry is set)
			BCC ...ExactHalfPoint				;>Should a remainder in the carry is 0 (no remainder), don't round the 1/2 point
			INC						;>Round the 1/2 point...
				;^Reason 1/2 point must be rounded up, is so to truly check if remainder is greater or equal to half of MaxQuantity, to round the pieces filled up,
				; when MaxQuantity is odd. e.g. 1 Quantity * 62 pieces / 5 MaxQuantity = Q:12 R:2, which is 12 and 2/5, or 12.4. The 1/2 point of 5 is EXACTLY 2.5,
				; not 2 (LSR divides A by 2 and round down, thus resulting 2). This means that the lowest remainder integer to trigger a round-up of the amount of
				; pieces filled would be 3.
	
			...ExactHalfPoint
				CMP $04						;>Half of max compares with remainder
				BEQ ...RoundDivQuotient				;>If HalfPoint = Remainder, round upwards
				BCS ...NoRoundDivQuotient			;>If HalfPoint > remainder (or remainder < HalfPoint), round down (if exactly full, this branch is taken).
	
			...RoundDivQuotient
				;^this also gets branched to if the value is already an exact integer number of pieces (so if the
				;quantity is 50 out of 100, and a bar of 62, it would be perfectly at 31 [(50*62)/100 = 31]
				LDA $00						;\Round up an integer
				INC						;/
				STA $08						;>move towards $08 because 16bit*16bit multiplication uses $00 to $07
	
		;check should this rounded value made a full bar when it is actually not:
				....RoundingUpTowardsFullCheck
					;Just as a side note, should the bar be EXACTLY full (so 62/62 and NOT 61.9/62, it guarantees
					;that the remainder is 0, so thus, no rounding is needed.) This is due to the fact that
					;[Quantity * FullAmount / MaxQuantity] when Quantity and MaxQuantity are the same number,
					;thus, canceling each other out (so 62 divide by 62 = 1) and left with FullAmount (the
					;number of pieces in the bar)
					
					JSL GetMaxBarInAForRoundToMaxCheck
					
					LDY #$00					;>Default that the meter didn't round towards empty/full (cannot be before the above subroutine since it overwrites Y).
					
					CMP $08						;>compare with rounded fill amount
					BNE .....TransferFillAmtBack			;\should the rounded up fill matches with the full value, flag that
					LDY #$02					;/it had rounded to full.
	
					.....TransferFillAmtBack
						LDA $08						;\move the fill amount back to $00.
						STA $00						;/
						BRA .Done
		
			...NoRoundDivQuotient
				....RoundingDownTowardsEmptyCheck
					LDY #$00					;>Default that the meter didn't round towards empty/full.
					LDA $00						;\if the rounded down (result from fraction part is less than .5) quotient value ISN't zero,
					BNE .Done					;/(exactly 1 piece filled or more) don't even consider setting Y to #$01.
					LDA $04						;\if BOTH rounded down quotient and the remainder are zero, the bar is TRUELY completely empty
					BEQ .Done					;/and don't set Y to #$01.
					
					LDY #$01					;>indicate that the value was rounded down towards empty
					
					.Done
					SEP #$20
		RTL
	CalculateGraphicalBarPercentageRoundUp:
		JSL CalculateGraphicalBarPercentageRoundDown
		REP #$20
		LDA $04				;\If remainder is zero, (meaning exactly an integer), don't increment
		BEQ .NoRoundUp			;/
		.RoundUp
			INC $00				;>Otherwise if there is a remainder (between Quotient and Quotient+1), use Quotient+1
			if !sa1 != 0
				LDA $00				;\Preserve rounded quotient
				PHA				;/
			endif
			JSL GetMaxBarInAForRoundToMaxCheck
			if !sa1 != 0
				REP #$30
				TAY
				PLA				;\Restore quotient
				STA $00				;/
				TYA
				SEP #$30
			endif
			LDY #$00
			REP #$20
			CMP $00
			BNE .NoRoundToMax
			LDY #$02
		.NoRoundToMax
		.NoRoundUp
		SEP #$20
		RTL
	CalculateGraphicalBarPercentageRoundDown:
		;This is the main calculation for all 3 variations of CalculateGraphicalBarPercentage, prior to modifying the quantity amount.
		;Integer division always rounds down, by default. Any rounding besides down require checking the remainder.
		;
		;Output:
		;	$00-$03: Fill amount (rounded down)
		;	$04-$05: Remainder
		.FindTotalPieces
			..FindTotalMiddle
				if !sa1 != 0
					LDA !Scratchram_GraphicalBar_MiddlePiece	;\TotalMiddlePieces = MiddlePieces*MiddleLength
					STA $00						;|Note: Multiply two 8-bit numbers.
					STZ $01						;|
					LDA !Scratchram_GraphicalBar_TempLength		;|
					STA $02						;|
					STZ $03						;/
					JSL MathMul16_16				;MiddlePieceper8x8 * NumberOfMiddle8x8. Stored into $04-$07 (will read $04-$05 since number of pieces are 16bit, not 32)
				else
					LDA !Scratchram_GraphicalBar_MiddlePiece	;\TotalMiddlePieces = MiddlePieces*MiddleLength
					STA $4202					;|
					LDA !Scratchram_GraphicalBar_TempLength		;|
					STA $4203					;/
					XBA						;\Wait 8 cycles (XBA takes 3, NOP takes 2) for calculation
					XBA						;|
					NOP						;/
					LDA $4216					;\Store product.
					STA $04						;|
					LDA $4217					;|
					STA $05						;/
				endif
			..FindTotalEnds ;>2 8-bit pieces added together, should result a 16-bit number not exceeding $01FE (if $200 or higher, can cause overflow since carry is only 0 or 1, highest highbyte increase is 1).
				STZ $01						;>Clear highbyte
				LDA !Scratchram_GraphicalBar_LeftEndPiece	;\Lowbyte total
				CLC						;|
				ADC !Scratchram_GraphicalBar_RightEndPiece	;|
				STA $00						;/
				LDA $01						;\Handle high byte (if an 8-bit low byte number exceeds #$FF, the high byte will be #$01.
				ADC #$00					;|$00-$01 should now hold the total fill pieces in the end bytes/8x8 tiles.
				STA $01						;/
			..FindGrandTotal
				REP #$20
				LDA $04						;>Total middle pieces
				CLC
				ADC $00						;>Plus total end
		.TotalPiecesTimesQuantity
			;STA $00						;>Store grand total in input A of 32x32bit multiplication
			;STZ $02						;>Rid the highword (#$0000XXXX)
			;LDA !Scratchram_GraphicalBar_FillByteTbl	;\Store quantity
			;STA $04						;/
			;STZ $06						;>Rid the highword (#$0000XXXX)
			;SEP #$20
			;JSL MathMul32_32				;>Multiply together. Results in $08-$0F (8 bytes; 64 bit).
			
			STA $00						;>Store 16-bit total pieces into multiplicand
			LDA !Scratchram_GraphicalBar_FillByteTbl	;\Store 16-bit quantity into multiplier
			STA $02						;/
			SEP #$20
			JSL MathMul16_16				;>Multiply together ($04-$07 (32-bit) is product)
	
			;Okay, the reason why I use the 32x32 bit multiplication is because
			;it is very easy to exceed the value of #$FFFF (65535) should you
			;have a large number of pieces in the bar (long bar, or large number
			;per byte).
			
			;Also, you may see "duplicate" routines with the only difference is
			;that they are different number of bytes for the size of values to
			;handle, they are included and used because some of my code preserves
			;them and are not to be overwritten by those routines, so a smaller
			;version is needed, and plus, its faster to avoid using unnecessarily
			;large values when they normally can't reach that far.
			
			;And finally, I don't directly use SA-1's multiplication and division
			;registers outside of routines here, because they are signed. The
			;amount of fill are unsigned.
	
		.DivideByMaxQuantity
			;REP #$20
			;LDA $08						;\Store result into dividend (32 bit only, its never to exceed #$FFFFFFFF), highest it can go is #$FFFE0001
			;STA $00						;|
			;LDA $0A						;|
			;STA $02						;/
			;LDA !Scratchram_GraphicalBar_FillByteTbl+2	;\Store MaxQuantity into divisor.
			;STA $04						;/
			;SEP #$20
			;JSL MathDiv32_16				;>;[$00-$03 : Quotient, $04-$05 : Remainder], After this division, its impossible to be over #$FFFF.
	
			REP #$20					;\Store result into dividend (32 bit only, its never to exceed #$FFFFFFFF), highest it can go is #$FFFE0001
			LDA $04						;|
			STA $00						;|
			LDA $06						;|
			STA $02						;/
			LDA !Scratchram_GraphicalBar_FillByteTbl+2	;\Store MaxQuantity into divisor.
			STA $04						;/
			SEP #$20
			JSL MathDiv32_16				;>;[$00-$03 : Quotient (rounded down), $04-$05 : Remainder], After this division, its impossible to be over #$FFFF.
			..CheckRoundToZero
				LDY #$00
				REP #$20
				LDA $00
				ORA $02
				BNE ...No				;>If quotient is nonzero, then no.
				LDA $04
				BEQ ...No				;>If quotient is zero AND remainder is zero, then it's exactly zero
				LDY #$01				;>Otherwise if Q = 0 and R != 0, then the fill amount is between 0 and 1, which rounded to zero.
				...No
				SEP #$20
		RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Convert fill amount in bar to tile numbers. NOTE: does not work with double-bar.
	;Scroll down for the double-bar version.
	;
	;Note to self about the gamemode values:
	; $0D-$0E covers overworld load and overworld.
	; $13-$14 covers level load and level.
	;
	;Input:
	; - !Scratchram_GraphicalBar_FillByteTbl to (!Scratchram_GraphicalBar_FillByteTbl+NumbOfTiles)-1:
	;   fill amount array to convert to tile numbers.
	; - $00: What set of graphics to use. Under default setting and code:
	; -- #$00 = Level, layer 3
	; -- #$01 = Level, sprite
	; -- #$02 = Overworld, layer 3
	;   You can add more sets of bar tiles by adding a new table as well as adding code
	;   to use the new table.
	; - !Scratchram_GraphicalBar_LeftEndPiece: Number of pieces in left byte (0-255), also
	;   the maximum amount of fill for this byte itself. If 0, it's not included in table.
	; - !Scratchram_GraphicalBar_MiddlePiece: Same as above but each middle byte.
	; - !Scratchram_GraphicalBar_RightEndPiece: Same as above but for right end.
	; - !Scratchram_GraphicalBar_TempLength: The length of the bar (only counts
	;   middle bytes)
	;Output:
	; - !Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl+x:
	;   converted to tile numbers.
	;Overwritten/Destroyed:
	; - $01: Needed to tell if all the middle tiles are done
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;These are tile numbers. Each number, starting from the
		;left represent each tile of pieces ordered from empty
		;(0) to full (in this default number of pieces, it is 3
		;for both ends and 8 for middles).
		
		;Tiles will glitch out if the number of pieces in the
		;corresponding type of bar part (left middle and right)
		;does not equal to the number of tile numbers +1 here,
		;when they use invalid indexing that would points to
		;bytes beyond the table.
		;This is for level:
			;Layer 3
				GraphicalBar_LeftEnd8x8s_Lvl_L3:
				;Left end fill amount tile numbers:
				db $36		;>Fill amount/index: $00
				db $37		;>Fill amount/index: $01
				db $38		;>Fill amount/index: $02
				db $39		;>Fill amount/index: $03
				GraphicalBar_Middle8x8s_Lvl_L3:
				;Middle fill amount tile numbers
				db $55		;>Fill amount/index: $00
				db $56		;>Fill amount/index: $01
				db $57		;>Fill amount/index: $02
				db $58		;>Fill amount/index: $03
				db $59		;>Fill amount/index: $04
				db $65		;>Fill amount/index: $05
				db $66		;>Fill amount/index: $06
				db $67		;>Fill amount/index: $07
				db $68		;>Fill amount/index: $08
				GraphicalBar_RightEnd8x8s_Lvl_L3:
				;Right end fill amount tile numbers:
				db $50		;>Fill amount/index: $00
				db $51		;>Fill amount/index: $01
				db $52		;>Fill amount/index: $02
				db $53		;>Fill amount/index: $03
			;Sprite
				GraphicalBar_LeftEnd8x8s_Lvl_Spr:
				;Left end fill amount tile numbers:
				db $85		;>Fill amount/index: $00
				db $86		;>Fill amount/index: $01
				db $87		;>Fill amount/index: $02
				db $95		;>Fill amount/index: $03
				GraphicalBar_Middle8x8s_Lvl_Spr:
				;Middle fill amount tile numbers
				db $96		;>Fill amount/index: $00
				db $97		;>Fill amount/index: $01
				db $8A		;>Fill amount/index: $02
				db $8B		;>Fill amount/index: $03
				db $9A		;>Fill amount/index: $04
				db $9B		;>Fill amount/index: $05
				db $C0		;>Fill amount/index: $06
				db $C1		;>Fill amount/index: $07
				db $D0		;>Fill amount/index: $08
				GraphicalBar_RightEnd8x8s_Lvl_Spr:
				;Right end fill amount tile numbers:
				db $D1		;>Fill amount/index: $00
				db $E0		;>Fill amount/index: $01
				db $E1		;>Fill amount/index: $02
				db $F0		;>Fill amount/index: $03
		;These here are the same as above but intended for overworld border.
			GraphicalBar_LeftEnd8x8s_Ow_L3:
			db $80		;>Fill amount/index: $00
			db $81		;>Fill amount/index: $01
			db $82		;>Fill amount/index: $02
			db $83		;>Fill amount/index: $03
			GraphicalBar_Middle8x8s_Ow_L3:
			db $84		;>Fill amount/index: $00
			db $85		;>Fill amount/index: $01
			db $86		;>Fill amount/index: $02
			db $87		;>Fill amount/index: $03
			db $88		;>Fill amount/index: $04
			db $89		;>Fill amount/index: $05
			db $8A		;>Fill amount/index: $06
			db $8B		;>Fill amount/index: $07
			db $8C		;>Fill amount/index: $08
			GraphicalBar_RightEnd8x8s_Ow_L3:
			db $8D		;>Fill amount/index: $00
			db $8E		;>Fill amount/index: $01
			db $8F		;>Fill amount/index: $02
			db $90		;>Fill amount/index: $03
		;Convert tile code following:
			ConvertBarFillAmountToTiles:
				PHB						;>Preserve bank (so that table indexing work properly)
				PHK						;>push current bank
				PLB						;>pull out as regular bank
				if !Setting_GraphicalBar_IndexSize == 0
					LDX #$00
				else
					REP #$10								;>16-bit XY
					LDX #$0000								;>The index for what byte tile position to write.
				endif
			;Left end
				.LeftEndTranslate
					LDA !Scratchram_GraphicalBar_LeftEndPiece	;\can only be either 0 or the correct number of pieces listed in the table.
					BEQ .MiddleTranslate				;/
					if !Setting_GraphicalBar_IndexSize == 0
						LDA !Scratchram_GraphicalBar_FillByteTbl	;\Y = amount filled byte
						TAY						;/
					else
						REP #$20
						LDA !Scratchram_GraphicalBar_FillByteTbl
						AND #$00FF
						TAY
						SEP #$20
					endif
					LDA $00
					BEQ ..LevelLayer3
					CMP #$01
					BEQ ..LevelSprite
				
				..OverworldLayer3
					LDA GraphicalBar_LeftEnd8x8s_Ow_L3,y
					BRA ..WriteTable
				..LevelLayer3
					LDA GraphicalBar_LeftEnd8x8s_Lvl_L3,y				;\Convert byte to tile number byte
					BRA ..WriteTable
				..LevelSprite
					LDA GraphicalBar_LeftEnd8x8s_Lvl_Spr,y
				..WriteTable
					STA !Scratchram_GraphicalBar_FillByteTbl		;/
					INX							;>next tile byte
			;Middle
				.MiddleTranslate
					LDA !Scratchram_GraphicalBar_MiddlePiece	;\check if middle exist.
					BEQ .RightEndTranslate				;|
					LDA !Scratchram_GraphicalBar_TempLength		;|
					BEQ .RightEndTranslate				;/
		
					if !Setting_GraphicalBar_IndexSize == 0
						LDA !Scratchram_GraphicalBar_TempLength		;\Number of middle tiles to convert
						STA $01						;/
					else
						REP #$20
						LDA !Scratchram_GraphicalBar_TempLength
						AND #$00FF
						STA $01
					endif
					..Loop
						if !Setting_GraphicalBar_IndexSize == 0
							LDA !Scratchram_GraphicalBar_FillByteTbl,x	;>Y = the fill amount
							TAY
						else
							LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\amount of filled, indexed
							AND #$00FF					;|
							TAY						;/
							SEP #$20
						endif
						LDA $00
						BEQ ...LevelLayer3
						CMP #$01
						BEQ ...LevelSprite
						
						...OverworldLayer3
							LDA GraphicalBar_Middle8x8s_Ow_L3,y
							BRA ...WriteTable
						...LevelLayer3
							LDA GraphicalBar_Middle8x8s_Lvl_L3,y			;\amount filled as tile graphics
							BRA ...WriteTable
						...LevelSprite
							LDA GraphicalBar_Middle8x8s_Lvl_Spr,y
						...WriteTable
							STA !Scratchram_GraphicalBar_FillByteTbl,x	;/
				
						...Next
							INX
							if !Setting_GraphicalBar_IndexSize != 0
								REP #$20
							endif
							DEC $01
							BNE ..Loop
					SEP #$20
			;Right end
				.RightEndTranslate
					LDA !Scratchram_GraphicalBar_RightEndPiece
					BEQ .Done
					if !Setting_GraphicalBar_IndexSize == 0
						LDA !Scratchram_GraphicalBar_FillByteTbl,x
						TAY
					else
						REP #$20
						LDA !Scratchram_GraphicalBar_FillByteTbl,x
						AND #$00FF
						TAY
						SEP #$20
					endif
					LDA $00
					BEQ ..LevelLayer3
					CMP #$01
					BEQ ..LevelSprite
				
					..Overworld
						LDA GraphicalBar_RightEnd8x8s_Ow_L3,y
						BRA ..WriteTable
					..LevelLayer3
						LDA GraphicalBar_RightEnd8x8s_Lvl_L3,y
						BRA ..WriteTable
					..LevelSprite
						LDA GraphicalBar_RightEnd8x8s_Lvl_Spr,y
					..WriteTable
						STA !Scratchram_GraphicalBar_FillByteTbl,x
			;Done
				.Done
					SEP #$30					;>Just in case
					PLB						;>Pull bank
					RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Convert amount of fill to each fill per byte, repeated subtraction edition.
	;
	;Same as the other version, "DrawGraphicalBar" however does not use
	;multiplication and division routines. In fact, this alone does not use any
	;other subroutines AT ALL.
	;
	;It works by:
	;
	;(1) Taking the given/remaining fill amount, compares or subtracts by the
	;    maximum amount given for each byte in table: [Difference = RemainingFill - Maximum]
	;(1.1) If “Difference” becomes negative (RemainingFill < Maximum) “RemainingFill”
	;      (prior this subtraction into the negative) is copied and stored into
	;      the byte in the table array and then “RemainingFill” is set to 0.
	;      In simple terms, use all the rest if remaining fill is small.
	;(1.2) If zero or positive number occurs (RemainingFill >= Maximum),
	;      a byte in the table array is set to “Maximum”, “RemainingFill” is set to
	;      “Difference” (as in, RemainingFill := RemainingFill - Maximum).
	;      In simple terms, remaining amount deducted to “completely fill” a byte
	;      in table array.
	; (2) Index for tile array increases, and repeat back to step (1),
	;     basically "go to the next tile"
	;
	;^Essentially, you are transferring a given amount and “distributing” a given value
	; to each consecutive byte in the table. This is division in the form of repeated
	; subtraction. Much lighter than the other version.
	;
	;Input:
	; - $00 to $01: The amount of fill for the WHOLE bar.
	; - !Scratchram_GraphicalBar_LeftEndPiece: Number of pieces in left byte (0-255), also
	;   the maximum amount of fill for this byte itself. If 0, it's not included in table.
	; - !Scratchram_GraphicalBar_MiddlePiece: Same as above but each middle byte.
	; - !Scratchram_GraphicalBar_RightEndPiece: Same as above but for right end.
	; - !Scratchram_GraphicalBar_TempLength: The length of the bar (only counts
	;   middle bytes)
	;Output:
	; - !Scratchram_GraphicalBar_FillByteTbl to !Scratchram_GraphicalBar_FillByteTbl+EndAddress:
	;   A table array containing the amount of fill for each byte (N bytes (including zero) full,
	;   0 or 1 bytes a fraction, and then N bytes (including zero) empty), the address it ends at is:
	;
	;    EndAddress = (L + MLength + R) - 1
	;
	;  - L and R are 0 if set to 0 number of pieces, 1 otherwise on any nonzero values.
	;  - MLength is how many middle tiles.
	;
	; - $00 to $01: The leftover fill amount. If bar isn't full, it will be #$0000, otherwise its
	;  [RemainingFill = OriginalFill - EntireBarCapicity]. (overall calculation: RemainingFill = max((InputFillAmount - BarMaximumFull), 0))
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	DrawGraphicalBarSubtractionLoopEdition:
			LDX #$00
		.Leftend
			LDA !Scratchram_GraphicalBar_LeftEndPiece       ;\If left end does not exist, skip
			BEQ .Middle                                     ;/
			LDA $00                                         ;\Fillamount = Fillamount - MaxAmount (without writing to $00)
			SEC                                             ;|(SBC clears carry if an unsigned underflow occurs (x < 0))
			SBC !Scratchram_GraphicalBar_LeftEndPiece       ;|
			LDA $01                                         ;|
			SBC #$00                                        ;/
			BCC ..NotFull                                   ;>If Fillamount < MaxAmount, use all remaining fill amount of $00.
			
			..Full ;>Otherwise set the byte to max, and deduct the remaining fill amount by maximum.
				LDA !Scratchram_GraphicalBar_LeftEndPiece       ;\Full left end.
				STA !Scratchram_GraphicalBar_FillByteTbl        ;/
				LDA $00                                         ;\Fill amount deducted.
				SEC                                             ;|
				SBC !Scratchram_GraphicalBar_LeftEndPiece       ;|
				STA $00                                         ;|
				LDA $01                                         ;|
				SBC #$00                                        ;|
				STA $01                                         ;/
				BRA ..NextByte
			
			..NotFull
				LDA $00                                         ;\Take all the rest of $00.
				STA !Scratchram_GraphicalBar_FillByteTbl        ;|
				STZ $00                                         ;|
				STZ $01                                         ;/
			
			..NextByte
				INX                                             ;>Next tile byte
		.Middle
			LDA !Scratchram_GraphicalBar_MiddlePiece        ;\If middle does not exist, skip
			BEQ .RightEnd                                   ;|
			LDA !Scratchram_GraphicalBar_TempLength         ;|
			BEQ .RightEnd                                   ;/
			
			LDA !Scratchram_GraphicalBar_TempLength         ;\Loop counter for number of middle tiles.
			TAY                                             ;/
			
			..LoopMiddleTiles
				LDA $00                                         ;\Fillamount = Fillamount - MaxAmount (without writing to $00)
				SEC                                             ;|(SBC clears carry if an unsigned underflow occurs (x < 0))
				SBC !Scratchram_GraphicalBar_MiddlePiece        ;|
				LDA $01                                         ;|
				SBC #$00                                        ;/
				BCC ...NotFull                                   ;>If Fillamount < MaxAmount, use all remaining fill amount of $00.
			
				...Full ;>Otherwise set the byte to max, and deduct the remaining fill amount by maximum.
					LDA !Scratchram_GraphicalBar_MiddlePiece        ;\Full middle tile.
					STA !Scratchram_GraphicalBar_FillByteTbl,x      ;/
					LDA $00                                         ;\Fill amount deducted.
					SEC                                             ;|
					SBC !Scratchram_GraphicalBar_MiddlePiece        ;|
					STA $00                                         ;|
					LDA $01                                         ;|
					SBC #$00                                        ;|
					STA $01                                         ;/
					BRA ...NextByte
				
				...NotFull
					LDA $00                                         ;\Take all the rest of $00.
					STA !Scratchram_GraphicalBar_FillByteTbl,x      ;|
					STZ $00                                         ;|
					STZ $01                                         ;/
				
				...NextByte
					INX                                             ;>Next middle tile or to the right end.
					DEY                                             ;\Loop till all middle tiles done.
					BNE ..LoopMiddleTiles                           ;/
		.RightEnd
			LDA !Scratchram_GraphicalBar_RightEndPiece      ;\If right end does not exist, skip
			BEQ .Done                                       ;/
	
			LDA $00                                         ;\Fillamount = Fillamount - MaxAmount (without writing to $00)
			SEC                                             ;|(SBC clears carry if an unsigned underflow occurs (x < 0))
			SBC !Scratchram_GraphicalBar_RightEndPiece      ;|
			LDA $01                                         ;|
			SBC #$00                                        ;/
			BCC ..NotFull                                   ;>If Fillamount < MaxAmount, use all remaining fill amount of $00.
			
			..Full ;>Otherwise set the byte to max, and deduct the remaining fill amount by maximum.
				LDA !Scratchram_GraphicalBar_RightEndPiece      ;\Full right end.
				STA !Scratchram_GraphicalBar_FillByteTbl,x      ;/
				LDA $00                                         ;\Fill amount deducted.
				SEC                                             ;|
				SBC !Scratchram_GraphicalBar_RightEndPiece      ;|
				STA $00                                         ;|
				LDA $01                                         ;|
				SBC #$00                                        ;|
				STA $01                                         ;/
				BRA .Done
			
			..NotFull
				LDA $00                                         ;\Take all the rest of $00.
				STA !Scratchram_GraphicalBar_FillByteTbl,x      ;|
				STZ $00                                         ;|
				STZ $01                                         ;/
		.Done
			RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Round away code
	;Input:
	; - Y: rounding status, obtained from CalculateGraphicalBarPercentage:
	; -- $00 = not rounded to full or empty
	; -- $01 = rounded to empty
	; -- $02 = rounded to full
	;Output:
	; - $00-$01: Percentage, rounded away from 0 and max.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	GraphicalBarRoundAwayEmpty:
		CPY #$01
		BEQ GraphicalBarRoundAwayEmptyFull_RoundedEmpty
		RTL
	GraphicalBarRoundAwayFull:
		CPY #$02
		BEQ GraphicalBarRoundAwayEmptyFull_RoundedFull
		RTL
	GraphicalBarRoundAwayEmptyFull:
		CPY #$00						;\check rounding flags (Y is only #$00 to #$02)
		BEQ .NotRounded						;|
		CPY #$01						;|
		BEQ .RoundedEmpty					;|
		BRA .RoundedFull					;/>Of course, if Y cannot be 0 and 1, it has to be 2, so no extra checks.
		
		.RoundedEmpty ;>Asar treats this sublabel as [GraphicalBarRoundAwayEmptyFull_RoundedEmpty]
		REP #$20						;\Turn a number rounded to 0 to 1 as the amount filled
		INC $00							;|
		SEP #$20						;/
		BRA .NotRounded						;>and done

		.RoundedFull ;>Asar treats this sublabel as [GraphicalBarRoundAwayEmptyFull_RoundedFull]
		REP #$20						;\Turn a number rounded to full to [FullAmount-1] (so if rounded to 62/62, display 61/62).
		DEC $00							;|
		SEP #$20						;/
		
		.NotRounded
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This routine directly writes the tile to the status bar or
;overworld border plus, filling left to right.
;
;Note: This only writes up to 128 (64 if using super status
;bar and OWB+ format) tiles. But it is unlikely you would ever
;need that much tiles, considering that the screen is 32 ($20)
;8x8 tiles wide.
;
;Input:
; - $00 to $02: The starting byte address location of the status bar (tile number).
;   This is the leftmost tile to position.
; -- If you're using SA-1 mode here and using vanilla status bar,
;    the status bar tilemap table is moved to bank $40.
; - !Scratchram_GraphicalBar_LeftEndPiece: Number of pieces in left byte (0-255), also
;   the maximum amount of fill for this byte itself. If 0, it's not included in table.
; - !Scratchram_GraphicalBar_MiddlePiece: Same as above but each middle byte.
; - !Scratchram_GraphicalBar_RightEndPiece: Same as above but for right end.
; - !Scratchram_GraphicalBar_TempLength: The length of the bar (only counts
;   middle bytes)
; - If you are using custom status bar patches that enables editing tile properties in-game,
;   and have set "!StatusBar_UsingCustomProperties" to 1, you have another input:
; -- $03 to $05: Same as $00 to $02 but for tile properties instead of tile numbers.
; -- $06: The tile properties (YXPCCCTT) you want it to be. Note: This does not automatically
;    modify the X-bit flip flag. You need to flip them yourself for this routine alone for flipped bars.
;Output:
; - [RAMAddressIn00] to [RAMAddressIn00 + ((NumberOfTiles-1)*TileFormat]: the status bar/OWB+
;   RAM write range.
; - If using SB/OWB+ patch that allows editing YXPCCCTT in-game and have set !StatusBar_UsingCustomProperties
;   to 1:
; -- [RAMAddressIn03] to [RAMAddressIn03 + ((NumberOfTiles-1)*TileFormat]: same as above but YXPCCCTT
;Note:
; - These routines can be used on stripe image for both horizontal (left to right) and vertical (top to
;   bottom)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	WriteBarToHUD:
		JSL GraphicalBarNumberOfTiles
		CPX #$FF				;\If 0-1 = (-1), there is no tile to write.
		BEQ .Done				;/(non-existent bar)
		TXY					;>STA [$xx],x does not exist! Only STA [$xx,x] does but functions differently!

		.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Write each tile.
			STA [$00],y					;/
			if !StatusBar_UsingCustomProperties != 0
				LDA $06
				STA [$03],y
			endif
			
			..Next
				DEX
				DEY
				BPL .Loop
		
		.Done
			RTL
	
	WriteBarToHUDFormat2:
		JSL GraphicalBarNumberOfTiles
		CPX #$FF				;\If 0-1 = (-1), there is no tile to write.
		BEQ .Done				;/(non-existent bar)
		TXA					;\Have Y = X*2 due to SSB/OWB+ patch formated for 2 contiguous bytes per tile.
		ASL					;|
		TAY					;/
		
		.Loop
			LDA !Scratchram_GraphicalBar_FillByteTbl,x	;\Write each tile.
			STA [$00],y					;/
			if !StatusBar_UsingCustomProperties != 0
				LDA $06
				STA [$03],y
			endif
			
			..Next
				DEX
				DEY #2
				BPL .Loop
		
		.Done
			RTL
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Same as WriteBarToHUD, but fills leftwards as opposed to
	;rightwards.
	;
	;Note:
	; - This is still "left anchored", meaning the address
	;   to write your bar on would be the left side where the fill
	;   edge is at when full.
	; - Does not reverse the order of data in
	;   !Scratchram_GraphicalBar_FillByteTbl, it simply writes to the
	;   HUD in reverse order.
	; - These routines can be used on stripe image for both horizontal
	;   (right to left) and vertical (bottom to top).
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		WriteBarToHUDLeftwards:
			JSL GraphicalBarNumberOfTiles
			CPX #$FF
			BEQ .Done
			LDY #$00
			
			.Loop
				LDA !Scratchram_GraphicalBar_FillByteTbl,x
				STA [$00],y
				if !StatusBar_UsingCustomProperties != 0
					LDA $06
					STA [$03],y
				endif
			
				..Next
					INY
					DEX
					BPL .Loop
		
			.Done
				RTL
		
		WriteBarToHUDLeftwardsFormat2:
			JSL GraphicalBarNumberOfTiles
			CPX #$FF
			BEQ .Done
			LDY #$00
			
			.Loop
				LDA !Scratchram_GraphicalBar_FillByteTbl,x
				STA [$00],y
				if !StatusBar_UsingCustomProperties != 0
					LDA $06
					STA [$03],y
				endif
				
				..Next
					INY #2
					DEX
					BPL .Loop
			
			.Done
				RTL
GetMaxBarInAForRoundToMaxCheck:
	;Must be called with 16-bit A.
	;Get the full number of pieces (for checking if rounding a number between Max-1 and Max to Max.)
	;Output: A (16-bit): Maximum fill amount (processor flag for A is 8-bit though)
	;Destroys:
	; -$00-$07 in LoROM
	; -$04-$05 in SA-1
	if !sa1 != 0
		LDA !Scratchram_GraphicalBar_MiddlePiece	;\Get amount of pieces in middle
		AND #$00FF					;|
		STA $00						;|
		LDA !Scratchram_GraphicalBar_TempLength		;|
		AND #$00FF					;|
		STA $02						;/
		SEP #$20
		JSL MathMul16_16				;>[$04-$07: Product]
	else
		SEP #$20
		LDA !Scratchram_GraphicalBar_MiddlePiece
		STA $4202
		LDA !Scratchram_GraphicalBar_TempLength
		STA $4203
		XBA						;\Wait 8 cycles (XBA takes 3, NOP takes 2) for calculation
		XBA						;|
		NOP						;/
		LDA $4216					;\[$04-$07: Product]
		STA $04						;|
		LDA $4217					;|
		STA $05						;/
	endif
	;add the 2 ends tiles amount (both are 8-bit, but results 16-bit)
	
	;NOTE: should the fill amount be exactly full OR greater, Y will be #$00.
	;This is so that greater than full is 100% treated as exactly full.
	LDA #$00					;\A = $YYXX, (initially YY is $00)
	XBA						;/
	LDA !Scratchram_GraphicalBar_LeftEndPiece	;\get total pieces
	CLC						;|\carry is set should overflow happens (#$FF -> #$00)
	ADC !Scratchram_GraphicalBar_RightEndPiece	;//
	XBA						;>A = $XXYY
	ADC #$00					;>should that overflow happen, increase the A's upper byte (the YY) by 1 ($01XX)
	XBA						;>A = $YYXX, addition maximum shouldn't go higher than $01FE. A = 16-bit total ends pieces
	REP #$20
	CLC						;\plus middle pieces = full amount
	ADC $04						;/
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Count tiles. Stupid that you cannot call a separate subroutine
;file from a subroutine file. This is used by other subroutines
;to compute the left side of the bar position so that the right
;side is at a fixed position.
;
;Input:
; - !Scratchram_GraphicalBar_LeftEndPiece,
;   !Scratchram_GraphicalBar_MiddlePiece,
;   !Scratchram_GraphicalBar_TempLength, and
;   !Scratchram_GraphicalBar_RightEndPiece: used to find how many
;   tiles.
;Output:
; - X = Number of bytes or 8x8 tiles the bar takes up of minus 1
;   For example: 9 total bytes, this routine would output X=$08.
;   Returns X=$FF should not a single tile exist.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GraphicalBarNumberOfTiles:
	LDX #$00
	LDA !Scratchram_GraphicalBar_LeftEndPiece
	BEQ +
	INX
	+
	LDA !Scratchram_GraphicalBar_MiddlePiece
	BEQ +
	TXA
	CLC
	ADC !Scratchram_GraphicalBar_TempLength
	TAX
	+
	LDA !Scratchram_GraphicalBar_RightEndPiece
	BEQ +
	INX
	+
	DEX					;>Subtract by 1 because index 0 exists.
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Damage sprite subroutine.
;Input:
; - $00 to $00+!Setting_SpriteHP_TwoByte = Amount of damage.
;Output:
; - HP is already subtracted, if damage > currentHP, HP is
;   set to 0.
;
;Note that this DOES NOT handle death sequence, only
;subtracts HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SpriteHPDamage:
	PHY
	LDA !Freeram_SpriteHP_MeterState
	CMP #$FE
	BEQ .Disabled
	CMP #$FD
	BEQ .Disabled
	if !Setting_SpriteHP_BarAnimation == 0
		TXA
		STA !Freeram_SpriteHP_MeterState
	else
		LDA $00
		PHA
		if !Setting_SpriteHP_TwoByte != 0
			LDA $01
			PHA
		endif
		JSL SpriteHPGetSlotIndex
		TXA
		CMP !Scratchram_SpriteHP_SpriteSlotToDisplay
		BEQ .SameSpriteSlot
		STA !Freeram_SpriteHP_MeterState
		.Different
			JSL SpriteHPRemoveRecordEffect		;>Get fill amount of current HP *before* the damage (and not before even that) to properly show how much fill loss when switching slots.
		.SameSpriteSlot
		if !Setting_SpriteHP_TwoByte != 0
			PLA
			STA $01
		endif
		PLA
		STA $00
	endif
	.Disabled
	if and(notequal(!Setting_SpriteHP_BarAnimation, 0), notequal(!Setting_SpriteHP_BarChangeDelay, 0))
		LDA.b #!Setting_SpriteHP_BarChangeDelay		;\Freeze damage indicator (this makes the bar animation hangs before decreasing towards current HP fill amount)
		STA !Freeram_SpriteHP_BarAnimationTimer,x	;/
	endif
	if !Setting_SpriteHP_TwoByte != 0
		LDA !Freeram_SpriteHP_CurrentHPHi,x	;>HP high byte
		XBA					;>Transfer to A's high byte
		LDA !Freeram_SpriteHP_CurrentHPLow,x	;>HP low byte in A's low byte
		REP #$20				;>Make A read also the high byte.
		SEC					;\Subtract by damage.
		SBC $00					;/
		SEP #$20				;>8-bit A (low byte)
		BCS .NonNegHP				;>if HP value didn't underflow, set HP to subtracted value.
		LDA #$00				;\Set HP to 0
		STA !Freeram_SpriteHP_CurrentHPLow,x	;|
		STA !Freeram_SpriteHP_CurrentHPHi,x	;/
		BRA .Done

		.NonNegHP
			STA !Freeram_SpriteHP_CurrentHPLow,x	;>Low byte subtracted HP
			XBA					;>Switch to high byte
			STA !Freeram_SpriteHP_CurrentHPHi,x	;>High byte subtracted HP
	else
		LDA !Freeram_SpriteHP_CurrentHPLow,x	;\if HP subtracted by damage didn't underflow (carry set), write HP
		SEC					;|
		SBC $00					;|
		BCS .NonNegHP				;/
		LDA #$00				;>otherwise if underflow (carry clear; borrow needed), set HP to 0.
		
		.NonNegHP
		STA !Freeram_SpriteHP_CurrentHPLow,x
	endif
	.Done
	PLY
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This essentially takes the value of !Freeram_SpriteHP_MeterState, and modulo by
;!sprite_slots, which can be used to detect if what sprite slot index number the meter is
;on is on the same slot number as the currently processed sprite.
;
;Output:
; - !Scratchram_SpriteHP_SpriteSlotToDisplay: Sprite slot index number. $FF means invalid.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	SpriteHPGetSlotIndex:
		LDA !Freeram_SpriteHP_MeterState
		CMP.b #!sprite_slots
		BCC .Normal				;0 to 11 or 0 to 21
		CMP.b #(!sprite_slots*2)
		BCC .IntroFillMode			;12 to 23 or 22 to 43
		LDA #$FF
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL
		.IntroFillMode
			SEC
			SBC.b #!sprite_slots
		.Normal
		STA !Scratchram_SpriteHP_SpriteSlotToDisplay
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This subroutine sets the graphical bar animation
;fill value to its current HP fill amount. Effectively
;removing the transparent effect of taking damage.
;
;This is used to instantly get the fill amount prior
;to taking damage, when the HP meter switches sprite
;slots (including from $FF of a null-sprite). That way
;the bar always show its before-damage fill amount
;but not before even that if the player damages the
;this sprite, then the other sprite, than this sprite
;quickly.
;
;Input:
; - !Setting_SpriteHP_GraphicalBar_LeftPieces = Number of pieces, to find total pieces of the bar.
; - !Setting_SpriteHP_GraphicalBar_MiddlePieces = Number of pieces, to find total pieces of the bar.
; - !Setting_SpriteHP_GraphicalBar_RightPieces = Number of pieces, to find total pieces of the bar.
; - !Setting_SpriteHP_GraphicalBarMiddleLength = Number of middle tiles, to find total pieces of the bar.
;Output:
; - $00 = Amount of fill in the bar of the sprite's
;   current HP.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SpriteHPRemoveRecordEffect:
	LDA.b #!Setting_SpriteHP_GraphicalBar_LeftPieces
	STA !Scratchram_GraphicalBar_LeftEndPiece
	LDA.b #!Setting_SpriteHP_GraphicalBar_MiddlePieces
	STA !Scratchram_GraphicalBar_MiddlePiece
	LDA.b #!Setting_SpriteHP_GraphicalBar_RightPieces
	STA !Scratchram_GraphicalBar_RightEndPiece
	LDA.b #!Setting_SpriteHP_GraphicalBarMiddleLength
	STA !Scratchram_GraphicalBar_TempLength
	PHX
	JSL SpriteHPGetSlotIndex
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
	if !Setting_SpriteHP_BarFillRoundDirection == 0
		JSL CalculateGraphicalBarPercentage
	elseif !Setting_SpriteHP_BarFillRoundDirection == 1
		JSL CalculateGraphicalBarPercentageRoundDown
	elseif !Setting_SpriteHP_BarFillRoundDirection == 2
		JSL CalculateGraphicalBarPercentageRoundUp
	endif
	;$00~$01 = percentage
	if !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 1
		JSL GraphicalBarRoundAwayEmpty
	elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 2
		JSL GraphicalBarRoundAwayFull
	elseif !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull == 3
		JSL GraphicalBarRoundAwayEmptyFull
	endif
	PLX
	if !Setting_SpriteHP_BarAnimation
		LDA $00
		STA !Freeram_SpriteHP_BarAnimationFill,x
	endif
	RTL