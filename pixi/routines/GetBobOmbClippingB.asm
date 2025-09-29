;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Get Bob-Omb explosion clipping (hitbox B)
;Input:
; - Y (8-bit): Sprite slot of the Bob-omb to get explosion
;   clipping
; - $8B (1 byte): Explosion "apothem", centered within Bob-omb.
;   Note that the hitbox is a square.
;Output:
; - Hitbox B values:
; -- $00 (1 byte): X Position low byte
; -- $01 (1 byte): Y Position low byte
; -- $02 (1 byte): Width
; -- $03 (1 byte): Height
; -- $08 (1 byte): X position high byte
; -- $09 (1 byte): Y Position high byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
?BobOmbClippingB:
	LDA !E4,y		;\Sprite is 16x16, and our current position is the top-left of that.
	CLC			;|We need to go 8 pixels to the right and 8 down to locate the center
	ADC #$08		;|of that sprite.
	STA $00			;|
	LDA !14E0,y		;|
	ADC #$00		;|
	STA $08			;|
	LDA !D8,y		;|
	CLC			;|
	ADC #$08		;|
	STA $01			;|
	LDA !14D4,y		;|
	ADC #$00		;|
	STA $09			;/
	LDA $8B			;\As the "apothem" expands, the width expands twice the value of "apothem"
	ASL			;|
	STA $02			;|
	STA $03			;/
	LDA $00			;\As the box expands from center, the top or left gets moved by "apothem"
	SEC			;|
	SBC $8B			;|
	STA $00			;|
	LDA $08			;|
	SBC #$00		;|
	STA $08			;|
	LDA $01			;|
	SEC			;|
	SBC $8B			;|
	STA $01			;|
	LDA $09			;|
	SBC #$00		;|
	STA $09			;/
	RTL