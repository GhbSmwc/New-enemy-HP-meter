;Insert this as level.

;This ASM code displays the enemy's HP on the HUD of the most recent enemy the player
;have dealt damage to.

incsrc "../StatusBarDefines.asm"
incsrc "../EnemyHPMeterDefines.asm"
incsrc "../NumberDisplayRoutinesDefines.asm"

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
	
	
	
	;Code here
	
	.Done
	PLB
	RTL