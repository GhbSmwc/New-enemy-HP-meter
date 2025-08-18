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
	CPY #$01
	BEQ ?.HaveRoundedToEmpty
	RTL
	?.HaveRoundedToEmpty
		REP #$20
		INC $00
		SEP #$20
		RTL