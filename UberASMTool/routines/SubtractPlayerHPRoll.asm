	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Hurt player (with rolling HP)
	;
	;Input:
	; $00 (8/16-bit) = amount of HP loss.
	;
	;Automatically writes to !Freeram_PlayerHP_CurrentHP. Does not
	;subtract HP to below zero.
	;
	;The conditions here are different unlike the block or
	;patch version, as even if you enabled rolling HP, the
	;add/subtract HP by x amount per interval requires this,
	;and does not use the rolling HP system.
	;
	;For some reason, if you need a standard damage routine
	;(non-rolling) and have "!Setting_PlayerHP_GradualHPChange"
	;disabled (you're not using the gradual heal or damage
	;blocks) on uberasm tool, comment out
	;"if !Setting_PlayerHP_GradualHPChange != 0" and the
	;"endif" before "if !Setting_PlayerHP_RollingHP != 0".
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		?SubtractPlayerHP0:
		;this uses CLC : ADC to allow damage to stack when the player
		;takes damage while HP is counting down.
		LDA !Freeram_PlayerHP_MotherHPDirection			;\Check if the player is healing or under HP drain
		BEQ .StackDamage					;/
		if !Setting_PlayerHP_TwoByte == 0
			LDA $00
			BRA ?.NotMaxed
		else
			REP #$20
			LDA $00
			BRA ?.NotMaxed
		endif
		
		?.StackDamage
		if !Setting_PlayerHP_TwoByte == 0
			LDA !Freeram_PlayerHP_MotherHPChanger
			CLC
			ADC $00						;\Amount to subtract HP
			BCC ?.NotMaxed					;|
			
			?.Maxed
			LDA #$FF					;|
			
			?.NotMaxed
			STA !Freeram_PlayerHP_MotherHPChanger		;|
		else
			REP #$20					;|
			LDA !Freeram_PlayerHP_MotherHPChanger		;|
			CLC						;|
			ADC $00						;|
			BCC ?.NotMaxed					;|
			
			?.Maxed
			LDA #$FFFF					;|
			
			?.NotMaxed
			STA !Freeram_PlayerHP_MotherHPChanger		;|
			SEP #$20					;/
		endif
		?.SetToDamage
		LDA #$00						;\Set to damage the player
		STA !Freeram_PlayerHP_MotherHPDirection			;/
		RTL