	incsrc "../PlayerHPDefines.asm"
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Recover player HP.
	;
	;Input:
	; $00 (8/16-bit) = the amount of HP to recover
	;
	;Automatically writes to !Freeram_PlayerHP_CurrentHP. Doesn't
	;heal past the maximum HP.
	;
	;Note that this doesn't include the rolling HP
	;(so this ALWAYS instantly heals by a specified amount).
	;This is for use with the gradual heal block.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	?RecoverPlayerHP0:
		?.DisplayRecovery
			if !Setting_PlayerHP_DisplayRecoveryTotal
				LDA.b #!Setting_PlayerHP_DamageHeal_Duration
				STA !Freeram_PlayerHP_RecoveryTotalTimerDisplay
				if !Setting_PlayerHP_TwoByte != 0
					REP #$20
				endif
				LDA !Freeram_PlayerHP_RecoveryTotalDisplay
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
					STA !Freeram_PlayerHP_RecoveryTotalDisplay
				?..Done
				if !Setting_PlayerHP_TwoByte != 0
					SEP #$20
				endif
			endif
		?.RecoverHP
			if !Setting_PlayerHP_TwoByte == 0
				LDA !Freeram_PlayerHP_CurrentHP		;\Health + Recovery
				CLC					;|
				ADC $00					;/
				BCC ?.NotMaxed				;>If not exceeding 255, compare with max HP
				CMP !Freeram_PlayerHP_MaxHP		;\If not exceeding max HP, write to HP.
				BCC ?.NotMaxed				;/
				
				?.Maxed
				LDA !Freeram_PlayerHP_MaxHP
				
				?.NotMaxed
				STA !Freeram_PlayerHP_CurrentHP
			else
				REP #$20
				LDA !Freeram_PlayerHP_CurrentHP
				CLC
				ADC $00
				BCS ?.Maxed				;>If not exceeding 65535
				CMP !Freeram_PlayerHP_MaxHP
				BCC ?.NotMaxed				;>If not exceeding max HP, write to HP.
				
				?.Maxed
				LDA !Freeram_PlayerHP_MaxHP
				
				?.NotMaxed
				STA !Freeram_PlayerHP_CurrentHP
				SEP #$20
			endif
	RTL