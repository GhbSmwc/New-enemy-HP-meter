;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Easy stripe setup-er 2.1. Sets up stripe header, Updates length of stripe,
;and writes the terminating byte. You only need to write the tile data
;afterwards. NOTE: Fails if using SA-1 CPU.
;
; - $00: X position (%00XXXXXX, only bits 0-5 used, ranges from 0-63 ($00-$3F))
; - $01: Y position (%00YYYYYY, only bits 0-5 used, ranges from 0-63 ($00-$3F))
; - $02: What layer:
; -- $02 = Layer 1
; -- $03 = Layer 2
; -- $05 = Layer 3
; - $03: Direction and RLE: %DR000000
;   D = Direction: 0 = horizontal (rightwards), 1 = vertical (downwards)
;   R = RLE: 0 = no (manually write different tiles), 1 = yes (write one
;   tile multiple times, based on input $04-$05).
; - $04 to $05 (16-bit): Number of tiles, minus 1 (a value of 2 here means 3
;   tiles). (If RLE is used, this is how many times a tile is repeated).
;Output:
; - $7F837B-$7F837C: Updated length of stripe data.
; - X register (16-bit, XY registers are 16-bit): The index position of where
;   to write tile data (starting at $7F837D+4,x)
;Destroyed:
; - $06-$08: Used when not using RLE, to calculate the terminating byte location.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;note to self
; $7F837B = Length of stripe, counting header and tile data, but not the terminating byte.
; $7F837D+0,x = EHHHYXyy
; $7F837D+1,x = yyyxxxxx
; $7F837D+2,x = DRllllll
; $7F837D+3,x = LLLLLLLL
; $7F837D+4,x = Tile, number
; $7F837D+5,x = Tile properties
; $7F837D+6,x = Terminating byte
?SetupStripe:
	?.GetWhereToSafelyWriteStripe
		REP #$30		;>16-bit AXY
		LDA $7F837B		;\LDX $XXXXXX does not exist so we need LDA $XXXXXX : TAX to
		TAX			;/get RAM values stored in bank $7F into X register.
	?.StartWithBlankHeaderInitally
		LDA #$0000		;\Clear everything out first
		STA $7F837D+0,x		;|
		STA $7F837D+2,x		;/
		SEP #$20
	?.Xposition
		LDA $00			;\X bit 0-4
		AND.b #%00011111	;|
		ORA $7F837D+1,x		;|
		STA $7F837D+1,x		;/
		LDA $00			;\X bit 5
		AND.b #%00100000	;|
		LSR #3			;|
		ORA $7F837D+0,x		;|
		STA $7F837D+0,x		;/
	?.Yposition
		LDA $01			;\Y bit 0-2
		AND.b #%00000111	;|
		ASL #5			;|
		ORA $7F837D+1,x		;|
		STA $7F837D+1,x		;/
		LDA $01			;\Y bit 3-4
		AND.b #%00011000	;|
		LSR #3			;|
		ORA $7F837D+0,x		;|
		STA $7F837D+0,x		;/
		LDA $01			;\Y bit 5
		AND.b #%00100000	;|
		LSR #2			;|
		ORA $7F837D+0,x		;|
		STA $7F837D+0,x		;/
	?.WhatLayer
		LDA $02
		AND.b #%00000111
		ASL #4
		ORA $7F837D+0,x
		STA $7F837D+0,x
	?.Direction
		LDA $03
		AND.b #%11000000	;>Failsafe
		ORA $7F837D+2,x
		STA $7F837D+2,x
	?.Length
		AND.b #%01000000
		BEQ ?..NoRLE
		
		?..RLE
			REP #$21		;REP #$21 is 8-bit A with carry cleared
			TXA			;\Update length of stripe. 6 because 2 bytes of 1 tile plus 4 bytes of header)
			ADC #$0006		;|
			STA $7F837B		;/
			SEP #$20		;>8-bit A
			LDA #$FF		;\Terminating byte
			STA $7F837D+6,x		;/
			REP #$20
			LDA $04			;\NumberOfBytes = (NumberOfTiles-1)*2
			ASL			;|
			SEP #$20		;/
			BRA ?..Write
		?..NoRLE
			REP #$21		;REP #$21 is 8-bit A with carry cleared
			LDA $04			;\4+(NumberOfTiles*2)...
			INC			;|
			ASL			;|
			CLC			;|
			ADC #$0004		;/
			CLC			;\plus the current length
			ADC $7F837B		;/
			STA $7F837B		;>And that is our new length
			SEP #$20		;>8-bit AXY
			LDA #$7F		;\Bank byte
			STA $08			;/
			REP #$20		;\4+(NumberOfTiles*2)...
			LDA $04			;|
			INC			;|
			ASL			;|
			CLC			;|>Just in case
			ADC.w #$837D+4		;|
			STA $06			;/
			TXA			;\Plus index ($7F837D+(NumberOfBytesSinceHeader),x is equivalent to $7F837D + NumberOfBytesSinceHeader + X_index)
			CLC			;|
			ADC $06			;|
			STA $06			;/
			SEP #$20
			LDA #$FF		;\Write terminate byte here.
			STA [$06]		;/
			REP #$20
			LDA $04			;\NumberOfBytes = (NumberOfTiles*2)-1
			INC			;|
			ASL			;|
			DEC			;|
			SEP #$20		;/
		?..Write
			STA $7F837D+3,x		;\Write length bits
			XBA			;|
			AND.b #%00111111	;|
			ORA $7F837D+2,x		;|
			STA $7F837D+2,x		;/
	?.Done
		RTL