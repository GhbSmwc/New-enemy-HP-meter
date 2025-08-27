incsrc "Defines/SA1StuffDefines.asm"

;Notes:
;Code at $02A0AC ("ProcessFireball") is the fireball code that handles the interaction as well as Chuck's HP count
;$02C1F8 is the code that runs every frame (even when dying but not when its sprite status $14C8 is $00 (empty))

;190F format: wcdj5sDp
;	w=Don't get stuck in walls (carryable sprites)
;	c=Don't turn into a coin with silver POW
;	d=Death frame 2 tiles high
;	j=Can be jumped on with upward Y speed
;	5=Takes 5 fireballs to kill. If not set, the sprite is killed with a single fireball. The counter for hits is controlled by $1528.
;	s=Can't be killed by sliding
;	D=Don't erase when goal passed
;	p=Make platform passable from below

;Formula: $07F659+VanillaSpriteNum
;All their "Sprite190FVals" are $48 (%01001000)
;VanillaSpriteNum:
;	$46 = Diggin' chuck
;	$91 = Regular Chargin chuck
;	$92 = Splittin' chuck
;	$93 = Bouncin' Chuck
;	$94 = Whistlin' chuck
;	$95 = Clappin' chuck
;	$97 = Puntin' chuck
;	$98 = Pitchin' chuck

;		see 	;see https://www.smwcentral.net/?p=memorymap&game=smw&u=0&address=&sizeOperation=%3D&sizeValue=&region[]=ram&type=*&description=%22tweaker%22#
;		Sprite190FVals        wcdj5sDp   Sprite166EVals        lwcfpppg   Sprite1686Vals        dnctswye
		org $07F659+$46 : db $01001000 : org $07F3FE+$46 : db %10001011 : org $07F590+$46 : db %00010001
		org $07F659+$91 : db $01001000 : org $07F3FE+$91 : db %00001011 : org $07F590+$91 : db %00010001
		org $07F659+$92 : db $01001000 : org $07F3FE+$92 : db %00001011 : org $07F590+$92 : db %00010001
		org $07F659+$93 : db $01001000 : org $07F3FE+$93 : db %00001011 : org $07F590+$93 : db %00010001
		org $07F659+$94 : db $01001000 : org $07F3FE+$94 : db %00001011 : org $07F590+$94 : db %00010001
		org $07F659+$95 : db $01001000 : org $07F3FE+$95 : db %00001011 : org $07F590+$95 : db %00010001
		org $07F659+$97 : db $01001000 : org $07F3FE+$97 : db %00001011 : org $07F590+$97 : db %00010001
		org $07F659+$98 : db $01001000 : org $07F3FE+$98 : db %00001011 : org $07F590+$98 : db %00010001


;Remove hijack of the chucks code that runs every frame.
	if read1($02C1F8) == $5C			;>if there is a hijacked code...
		autoclean read3($02C1F8+1)		;>...then remove freespace code first
	endif
	org $02C1F8
	LDA.W !187B,X					;\Restore overwritten code
	PHA						;/
	