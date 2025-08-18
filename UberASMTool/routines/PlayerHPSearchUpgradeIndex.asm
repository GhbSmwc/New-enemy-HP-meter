	incsrc "../StatusBarDefines.asm"
	incsrc "../PlayerHPDefines.asm"
	incsrc "../MotherHPDefines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;This routine obtains an index number of a level listed when the player is in a listed
;;level. This is useful for various things like blocks increases max HP differently on the
;;same block but different level.
;;
;;Output:
;; - X: (8-bit; 0-127) the index of what level listed (in increments of 1 for every level).
;;   Invalid value if it fails to find the matching level.
;; - Carry: Set if no matching level have been found.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?SearchLevel:
	REP #$30								;>16-bit AXY
	LDA $010B|!addr								;>Current level number ($FE is dangerous to use)

	LDX.w #(?LevelIndexWordListEnd-?LevelIndexWordListStart)-2		;>How many items are in the list as raw number of bytes excluding the last 2.
	LDY.w #((?LevelIndexWordListEnd-?LevelIndexWordListStart)/2)-1		;>A secondary index for what byte in the no-respawn table.
	
	?.Loop
	CMP.l ?LevelIndexWordListStart,x					;\Check if the level number matches with the item in the list.
	BEQ ?.LevelFound							;/(use .l for 24-bit addressing table and "wrong bank" -proof)
	DEX #2									;\Loop until no more levels to check
	DEY									;|
	BPL ?.Loop								;/
	BRA ?.LevelNotFound							;>Failsafe if somehow the player obtains an upgrade in an unlisted level.
	
	?.LevelFound
	TYX									;\Level listed found
	CLC									;/
	BRA ?.Done
	
	?.LevelNotFound
	SEC									;>Level not found
	
	?.Done
	SEP #$30
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Level list.
;;
;;Notes:
;; - Due to code efficiency, it will first check starting at the bottom of the list, but where
;;   they are written are intact.
;;
;; - If you have copies of these tables, make sure the order of the list matches, else you end up
;;   with pickup data in the wrong address.
;;
;; - Make sure your dw $xxxx are in between "LevelIndexWordListStart" and
;;   "LevelIndexWordListEnd" and not outside it.
;;
;; - Of course, it is possible to merge all of these table duplicates into one using the shared
;;   subroutine patch.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?LevelIndexWordListStart:
	dw $0105			;>Level 105 [!Freeram_PlayerHP_MaxHPUpgradePickupFlag+0]
	dw $0106			;>Level 106 [!Freeram_PlayerHP_MaxHPUpgradePickupFlag+1]
	dw $0103			;>Level 103 [!Freeram_PlayerHP_MaxHPUpgradePickupFlag+2]
	;dw $xxxx			;>template  [!Freeram_PlayerHP_MaxHPUpgradePickupFlag+3]
	?LevelIndexWordListEnd:	;Don't remove this (needed to count how many items in the table)