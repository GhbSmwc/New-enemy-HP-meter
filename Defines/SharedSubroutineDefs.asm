!Freespace_SharedSub_JMLList = $90C5CA
	;^[BytesUsed = RatsIfNeeded+(NumberOfJMLs*4)]
	; RatsIfNeeded = 0 if you have [BankNumber & $7F] less than $10
	;  (so if you are in banks $00-$7F, its $10-$7F, for $80-$FF, its
	; $90-$FF). RatsIfNeeded = 8 otherwise.
	;
	; The fixed location where the JMLs list to be inserted to.
	; Must be a freespace location.
	;
	; Warning: Patching this, editing this address, then re-patching
	; does not remove the old JML list and the subroutines the list
	; points to. This causes freespace leaks (unused data that tools
	; would think it's reserved space).
	;
	; To move this without causing freespace leaks, do this instead:
	;
	; Patch "SharedSubRemover.asm" without the above define changed.
	; It will first clear the subroutine code, then the JML list.


;Define setter. Places marked "[Safe to Edit]" indicates an area you can safely edit,
;while "[Don't touch]" means don't touch unless you know what you're doing.
	;[Don't touch]
		!JMLListRatsTagSize = $00					;\A displacement to place the list
		if greaterequal((!Freespace_SharedSub_JMLList>>16)&$7F, $10)	;|AFTER the 8-byte rats tag if the
			!JMLListRatsTagSize = $08				;|rats tags exist.
		endif								;/
	
		!SharedSub_CurrentJMLAddress #= !Freespace_SharedSub_JMLList+!JMLListRatsTagSize	;Start at a freespace.
		if not(defined("SharedSubMacroDefined"))
			!SharedSubMacroDefined = 1			;>Mark that the macros and its calls have been invoked (dangerous if it can be invoked again)
			;^The above if statement is a workaround of a flaw of asar's "includeonce"
			;failing to work if two ASMs at different directories "incsrc" at different
			;paths to the same ASM file. See report here:
			; https://github.com/RPGHacker/asar/issues/287
			macro SetSharedSubDefine(Define_Name)
				!{<Define_Name>} #= !SharedSub_CurrentJMLAddress			;>First set define at current address
				!SharedSub_CurrentJMLAddress #= !SharedSub_CurrentJMLAddress+4		;>Then update the current address position for the next JML instruction location
			endmacro
			
			macro ConditionalSharedSubDefineList(DefineName_True, DefineName_False, Condition)
				if <Condition>
					%SetSharedSubDefine(<DefineName_True>)
				else
					%SetSharedSubDefine(<DefineName_False>)
				endif
			endmacro
		endif
	;[Safe to Edit]
	;Place your "use flag" defines here. It must have them be defined as
	;0 here.
	;
	;This defaults the "use flag" of subroutines to 0. Then immidiately,
	;uses incsrc "3rd_partyDefineFile.asm", which that conditionally
	;sets the "use flag" to 1 to indicate a subroutine being used.
		!SharedSubUseFlag_NumberDisplayRoutines = 0
		!SharedSubUseFlag_RightAlignedNumbers = 0
		!SharedSubUseFlag_RemoveLeadingZeroes16Bit = 0
		!SharedSubUseFlag_SuppressLeadingZeros = 0
		!SharedSubUseFlag_WriteStringDigitsToHUD = 0
		!SharedSubUseFlag_UsingGraphicalBarRoutines = 0
		!SharedSubUseFlag_GraphicalBarRoundHalfUp = 0
		!SharedSubUseFlag_GraphicalBarRoundUp = 0
		!SharedSubUseFlag_UsingExtendingLeftBar = 0
		!SharedSubUseFlag_UsingLeftwardsFillBar = 0
		!SharedSubUseFlag_UsingRightwardsFillBar = 0
		!SharedSubUseFlag_SpriteHPRemoveRecordEffect = 0
		!SharedSubUseFlag_BarExtendLeft = 0
		
	;Place your "incsrc use flag marker" here. Along with placing a
	;define file "SharedSub_Defines/SharedSubroutineDefs.asm"
	;(which the pasted define file conditionally sets the use flag
	; to 1 depending on the configuration). The example below:
	
		;incsrc "DefineConfigurationThingThatMayUseDMA.asm"
			;^This contains the following somewhere in the file:
			;	if !Setting != 0
			;		!SharedSubUseFlag_FindFreeUploadSlot = 1
			;	endif
			; NOTES:
			; - Make sure no 3rd party ASM files' defines incsrcs into
			;   this define file else it will infinitely include this
			;   file and the other file and cause an error.
			; - Make sure they DO NOT set the use flag to 0 if not
			;   used. Either it set it to 1, or leave it as is.
			;   Setting it to 0 risks excluding a subroutine define
			;   when it is actually used.
		incsrc "EnemyHPMeterDefines.asm"
	
	;[Safe to Edit]
	;These below assign each subroutine JML address location to a define.
	;Afterwards, you can utilize them by having "JSL !RoutineDefineName"
	;
	;Syntax: %SetSharedSubDefine(RoutineDefineName)
	;Conditional: %ConditionalSharedSubJMLList(RoutineDefineName, Placeholder, !Define_ConditionState)
	;
	;Notes
	; - The orders in JML list in sharedsub.asm and the macro define list
	;   here must match. This also includes conditionally-added subroutines.
	; - If you run into another ASM resource whose defines conflicts with
	;   Shared Subroutines's routine defines, to restore the define names,
	;   you can re-include this define file at where you want it to be
	;   restored (rather than at the top of the ASM file).
	; - When using conditionally-added subroutines (if statements), they
	;   must occupy the same number of bytes and number of items here
	;   reguardless if the condition is met or not. This can be done using
	;   substituting with other item in the list or a placeholder (using
	;   "else"). Easiest way is to use the aformentioned conditional
	;   macro, which automatically handles the substitute.
		%ConditionalSharedSubDefineList(SharedSub_SetEnemyHPBarAttributes, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_CalculateGraphicalBarPercentage, SharedSub_Placeholder, !SharedSubUseFlag_GraphicalBarRoundHalfUp)		;
		%ConditionalSharedSubDefineList(SharedSub_CalculateGraphicalBarPercentageRoundUp, SharedSub_Placeholder, !SharedSubUseFlag_GraphicalBarRoundUp)		;
		%ConditionalSharedSubDefineList(SharedSub_CalculateGraphicalBarPercentageRoundDown, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_GraphicalBarExtendLeft, SharedSub_Placeholder, !SharedSubUseFlag_UsingExtendingLeftBar)		;
		%ConditionalSharedSubDefineList(SharedSub_GraphicalBarExtendLeftFormat2, SharedSub_Placeholder, !SharedSubUseFlag_UsingExtendingLeftBar)		;
		%ConditionalSharedSubDefineList(SharedSub_ConvertBarFillAmountToTiles, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_DrawGraphicalBarSubtractionLoopEdition, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_GraphicalBarRoundAwayEmpty, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_GraphicalBarRoundAwayEmptyFull, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_GraphicalBarRoundAwayFull, SharedSub_Placeholder, !SharedSubUseFlag_UsingGraphicalBarRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteBarToHUD, SharedSub_Placeholder, !SharedSubUseFlag_UsingRightwardsFillBar)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteBarToHUDFormat2, SharedSub_Placeholder, !SharedSubUseFlag_UsingRightwardsFillBar)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteBarToHUDLeftwards, SharedSub_Placeholder, !SharedSubUseFlag_UsingLeftwardsFillBar)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteBarToHUDLeftwardsFormat2, SharedSub_Placeholder, !SharedSubUseFlag_UsingLeftwardsFillBar)		;
		%ConditionalSharedSubDefineList(SharedSub_ConvertToRightAligned, SharedSub_Placeholder, !SharedSubUseFlag_RightAlignedNumbers)		;
		%ConditionalSharedSubDefineList(SharedSub_ConvertToRightAlignedFormat2, SharedSub_Placeholder, !SharedSubUseFlag_RightAlignedNumbers)		;
		%ConditionalSharedSubDefineList(SharedSub_RemoveLeadingZeroes16Bit, SharedSub_Placeholder, !SharedSubUseFlag_RemoveLeadingZeroes16Bit)		;
		%ConditionalSharedSubDefineList(SharedSub_SixteenBitHexDecDivision, SharedSub_Placeholder, !SharedSubUseFlag_NumberDisplayRoutines)		;
		%ConditionalSharedSubDefineList(SharedSub_SuppressLeadingZeros, SharedSub_Placeholder, !SharedSubUseFlag_SuppressLeadingZeros)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteStringDigitsToHUD, SharedSub_Placeholder, !SharedSubUseFlag_WriteStringDigitsToHUD)		;
		%ConditionalSharedSubDefineList(SharedSub_WriteStringDigitsToHUDFormat2, SharedSub_Placeholder, !SharedSubUseFlag_WriteStringDigitsToHUD)		;
		%SetSharedSubDefine(SharedSub_MathDiv32_16)		;
		%SetSharedSubDefine(SharedSub_MathDiv)		;
		%SetSharedSubDefine(SharedSub_MathMul16_16)		;
		%SetSharedSubDefine(SharedSub_SpriteHPDamage)		;
		%SetSharedSubDefine(SharedSub_SpriteHPDamageNoAutoSwitchMeter)		;
		%SetSharedSubDefine(SharedSub_SpriteHPRemoveRecordEffect)		;
		%SetSharedSubDefine(SharedSub_SpriteHPGetSlotIndex)		;
		%SetSharedSubDefine(SharedSub_SpriteHPIntroEffect)		;
		%SetSharedSubDefine(SharedSub_HideHPMeterIfSpriteDespawns)		;
		%SetSharedSubDefine(SharedSub_SpritesTotalHPIntroEffect)		;
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.