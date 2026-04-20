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
		endif
	;[Safe to Edit]
	;These below assign each subroutine JML address location to a define.
	;Afterwards, you can utilize them by having "JSL !RoutineDefineName"
	;
	;Syntax: %SetSharedSubDefine(RoutineDefineName)
	;
	;Notes
	; - The orders in JML list in sharedsub.asm and the macro define list
	;   here must match.
	; - If you run into another ASM resource whose defines conflicts with
	;   Shared Subroutines's routine defines, to restore the define names,
	;   you can re-include this define file at where you want it to be
	;   restored (rather than at the top of the ASM file).
		%SetSharedSubDefine(SharedSub_CalculateGraphicalBarPercentage)		;
		%SetSharedSubDefine(SharedSub_CalculateGraphicalBarPercentageRoundDown)		;
		%SetSharedSubDefine(SharedSub_CalculateGraphicalBarPercentageRoundUp)		;
		%SetSharedSubDefine(SharedSub_ConvertBarFillAmountToTiles)		;
		%SetSharedSubDefine(SharedSub_ConvertToRightAligned)		;
		%SetSharedSubDefine(SharedSub_ConvertToRightAlignedFormat2)		;
		%SetSharedSubDefine(SharedSub_DrawGraphicalBarSubtractionLoopEdition)		;
		%SetSharedSubDefine(SharedSub_MathDiv32_16)		;
		%SetSharedSubDefine(SharedSub_MathDiv)		;
		%SetSharedSubDefine(SharedSub_MathMul16_16)		;
		%SetSharedSubDefine(SharedSub_RemoveLeadingZeroes16Bit)		;
		%SetSharedSubDefine(SharedSub_GraphicalBarRoundAwayEmpty)		;
		%SetSharedSubDefine(SharedSub_GraphicalBarRoundAwayEmptyFull)		;
		%SetSharedSubDefine(SharedSub_GraphicalBarRoundAwayFull)		;
		%SetSharedSubDefine(SharedSub_SixteenBitHexDecDivision)		;
		%SetSharedSubDefine(SharedSub_SuppressLeadingZeros)		;
		%SetSharedSubDefine(SharedSub_WriteBarToHUD)		;
		%SetSharedSubDefine(SharedSub_WriteBarToHUDFormat2)		;
		%SetSharedSubDefine(SharedSub_WriteBarToHUDLeftwards)		;
		%SetSharedSubDefine(SharedSub_WriteBarToHUDLeftwardsFormat2)		;
		%SetSharedSubDefine(SharedSub_WriteStringDigitsToHUD)		;
		%SetSharedSubDefine(SharedSub_WriteStringDigitsToHUDFormat2)		;
		%SetSharedSubDefine(SharedSub_SpriteHPDamage)		;
		%SetSharedSubDefine(SharedSub_SpriteHPRemoveRecordEffect)		;
		%SetSharedSubDefine(SharedSub_SpriteHPGetSlotIndex)		;
		%SetSharedSubDefine(SharedSub_SpriteHPIntroEffect)		;
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
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.
		%SetSharedSubDefine(SharedSub_Placeholder)		;Dummy JSL to reserve space.