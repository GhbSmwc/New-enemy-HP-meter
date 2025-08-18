	incsrc "../StatusBarDefines.asm"
	incsrc "../PlayerHPDefines.asm"
	incsrc "../MotherHPDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;This simply sets or clear the block exist flag depending of the pickup bits are
;;set or clear.
;;
;;Input:
;; - X: (8-bit; 0-127) the index of what level listed (in increments of 1 for every level).
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?DisablePickupRespawnM16:
	LDY #$07						;>loop 8 times that each loop handles a bit.

	?.Loop
	LDA !Freeram_PlayerHP_MaxHPUpgradePickupFlag,x		;\Read the pickup bit flags (see if it is clear or set)
	AND ?DisablePickupRespawnBitwisetable,y			;|
	BNE ?..SetBit						;/

	;This is where if you use a non-bitwise based flags to determine
	;a 2-state block should appear or not, you edit this.
	;
	;Currently, I assume you are using the conditional map16 access
	;feature of lunar magic. Each bit number (0-7) corresponds to what bits
	;in a byte defined by !Ram_PickupBlockExistFlag (by default its the
	;conditional map16 flags; $7FC060). For example, using "!MaxHP_UpgradeBit0.asm"
	;would write to bit 0 both in !Freeram_PlayerHP_MaxHPUpgradePickupFlag and
	;!Ram_PickupBlockExistFlag.
	
	?..ClearBit
	LDA ?DisablePickupRespawnBitwisetable,y
	ORA !Ram_PickupBlockExistFlag				;\Make blocks respawn (currently LM's conditional map16)
	STA !Ram_PickupBlockExistFlag				;/
	BRA ?..Next
	
	?..SetBit
	LDA ?DisablePickupRespawnBitwisetable,y
	EOR #$FF
	AND !Ram_PickupBlockExistFlag				;\Don't respawn (currently LM's conditional map16)
	STA !Ram_PickupBlockExistFlag				;/
	
	?..Next
	DEY
	BPL ?.Loop
	RTL
	
	
	?DisablePickupRespawnBitwisetable:
	db %00000001			;\What bit to check from !Freeram_PlayerHP_MaxHPUpgradePickupFlag,x
	db %00000010			;|
	db %00000100			;|
	db %00001000			;|
	db %00010000			;|
	db %00100000			;|
	db %01000000			;|
	db %10000000			;/