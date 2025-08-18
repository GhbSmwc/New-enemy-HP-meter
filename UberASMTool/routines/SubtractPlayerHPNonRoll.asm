	incsrc "../StatusBarDefines.asm"
	incsrc "../PlayerHPDefines.asm"
	incsrc "../MotherHPDefines.asm"
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Hurt player (merely subtracts HP and nothing else, useful
	;if you want certain damage to ignore invulnerability or
	;during a cutscene to display 0 HP without playing the
	;death animation)
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
	?SubtractPlayerHPNonRoll:
		?.DisplayDamage
			if !Setting_PlayerHP_DisplayDamageTotal
				LDA.b #!Setting_PlayerHP_DamageHeal_Duration
				STA !Freeram_PlayerHP_DamageTotalTimerDisplay
				if !Setting_PlayerHP_TwoByte != 0
					REP #$20
				endif
				LDA !Freeram_PlayerHP_DamageTotalDisplay
				CLC
				ADC $00
				BCS ?..Overflow
				if !Setting_PlayerHP_TwoByte != 0
					CMP.w #!Setting_PlayerHP_TrueMaximumHPAndDamageValue
				else
					CMP.b #!Setting_PlayerHP_TrueMaximumHPAndDamageValue
				endif
				BCC ?..Write
				
				?..Overflow
					if !Setting_PlayerHP_TwoByte != 0
						LDA.w #!Setting_PlayerHP_TrueMaximumHPAndDamageValue
					else
						LDA.b #!Setting_PlayerHP_TrueMaximumHPAndDamageValue
					endif
				?..Write
					STA !Freeram_PlayerHP_DamageTotalDisplay
				?..Done
				if !Setting_PlayerHP_TwoByte != 0
					SEP #$20
				endif
			endif
		?.SubtractHP
			if !Setting_PlayerHP_TwoByte != 0
				REP #$20
			endif
			LDA !Freeram_PlayerHP_CurrentHP		;\Health - damage
			SEC					;|
			SBC $00					;/
			BCS ?.NotPastZero			;>If value didn't subtract by larger value, go write HP.
			
			?.PastZero
			if !Setting_PlayerHP_TwoByte != 0
				LDA.w #$0000
			else
				LDA.b #$00				;>Otherwise set HP to 0.
			endif
			
			?.NotPastZero
			STA !Freeram_PlayerHP_CurrentHP		;>Write HP value.
			if !Setting_PlayerHP_TwoByte != 0
				SEP #$20
			endif
		RTL