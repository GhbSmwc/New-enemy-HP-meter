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
?RoundAwayEmpty:
	REP #$20
	CPY #$01
	BEQ ?.HaveRoundedToEmpty
	CPY #$02
	BEQ ?.HaveRoundedToFull
	SEP #$20
	RTL
	?.HaveRoundedToEmpty
		INC $00
		SEP #$20
		RTL
	?.HaveRoundedToFull
		DEC $00
		SEP #$20
		RTL