	incsrc "SA1StuffDefines.asm"
	incsrc "StatusBarDefines.asm"
;Freeram settings
	;[BytesUsed = 1 + (!sprite_slots*2) + (!sprite_slots * EnabledTables)]
	;A series of HP data stored in memory, in this order:
	;
	; - [1 byte]: Current sprite slot to display HP on. $FF means neither.
	; - [BytesUsed = !sprite_slots]: Sprite's current HP, low byte
	; - [BytesUsed = !sprite_slots]: Sprite's max HP, low byte
	; - [BytesUsed = !sprite_slots * !Setting_SpriteHP_TwoByte]: Sprite's current HP, high byte
	; - [BytesUsed = !sprite_slots * !Setting_SpriteHP_TwoByte]: Sprite's max HP, high byte
	; - [BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayGraphicalBar & !Setting_SpriteHP_BarAnimation)]: Bar fill animation
	; - [BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayGraphicalBar & !Setting_SpriteHP_BarAnimation)]: Bar fill animation timer
		if !sa1 == 0
			!Setting_SpriteHP_SpriteHPData = $7FACC4
		else
			!Setting_SpriteHP_SpriteHPData = $400110
		endif
;Settings
	;HUD settings
		;Notes:
		;About XY positions:
		;Position are in units of tiles, not pixels. XY must be integers with X ranging from 0-31.
		;X increases when going rightwards, and Y increases when going downwards.
		;Y ranges depending on status bar type you using:
		; - For vanilla SMW: Y can only be 2-3. And...
		; -- When Y=2, X ranges 2-29.
		; -- When Y=3, X ranges 3-29.
		; - Super super status bar patch, Y ranges 0-4.
		; - For Minimalist status bar patches:
		; -- Top or Bottom: Y is always 0 as there is only a single row
		; -- For double, then Y is either 0 for top or 1 for bottom.
		; - For SMB3 status bar, Y is 0-3.
		
		;Size of the HP:
			;Size of the HP data:
			; - 0 = 8-bit HP (HP up to 255)
			; - 1 = 16-bit (HP up to 65535).
				!Setting_SpriteHP_TwoByte = 1
			;The maximum number of digits to be displayed. Obviously you
			;wouldn't set this above 3 for 8-bit HP and above 5 or 16-bit.
				!Setting_SpriteHP_MaxDigits	= 3
		;Number display settings
				!Setting_SpriteHP_DisplayNumerical = 2
					;^Display numerical HP?
					; - 0 = Don't display numbers
					; - 1 = Display only current HP
					; - 2 = Display Current/Max
				!Setting_SpriteHP_NumericalTextAlignment = 2
					;^Alignment of the digits display:
					; - 0 = Digits at fixed location (may have leading spaces)
					; - 1 = Left-Aligned
					; - 2 = Right-aligned (if used with !Setting_SpriteHP_DisplayNumerical == 1, will treat this as using fixed location)
			;Position of the numerical HP display, will occupy this position and tiles to the right
			;when set to. Only used when !Setting_SpriteHP_NumericalTextAlignment < 2.
				!Setting_SpriteHP_NumericalPos_x = 21
				!Setting_SpriteHP_NumericalPos_y = 0
			;Position for right-aligned, when !Setting_SpriteHP_NumericalTextAlignment == 2.
				!Setting_SpriteHP_NumericalPosRightAligned_x = 31
				!Setting_SpriteHP_NumericalPosRightAligned_y = 0
		;Graphical bar settings
			!Setting_SpriteHP_DisplayGraphicalBar = 1
				;^0 = don't show the bar
				; 1 = display the bar
			;XY position of the bar (uses this position and tiles to the right, even when leftwards)
				!Setting_SpriteHP_GraphicalBarPos_x = 23
				!Setting_SpriteHP_GraphicalBarPos_y = 1
			;Length of bar (number of middle tiles). Full screen width is 32 tiles.
				!Setting_SpriteHP_GraphicalBarMiddleLength           = 7
			;Fill direction. 0 = Left-to-right, 1 = Right-to-left
				!Setting_SpriteHP_LeftwardsBar                       = 0
			;Tile properties (X-flip for leftwards bar is already handled.)
				!Setting_SpriteHP_BarProps_Page                      = 0  ;>Use only values 0-3
				!Setting_SpriteHP_BarProps_Palette                   = 6  ;>Use only values 0-7
			;Bar animation stuff
				!Setting_SpriteHP_BarAnimation			= 1
					;^0 = HP bar instantly updates when the player heals or take damage
					;     (!Freeram_SpriteHP_BarRecord is no longer used).
					; 1 = HP bar displays a changing animation (transparent segment to
					;     indicate the amount of damage or recovery)

				!Setting_SpriteHP_FillDelayFrames				= $00
					;^Speed that the bar fills up. Only use these values:
					; $00,$01,$03,$07$,$0F,$1F,$3F or $7F. Lower values = faster

				!Setting_SpriteHP_BarFillUpPerFrame			= 0
					;^How many pieces in the bar filled per frame. This overrides
					; !Setting_SpriteHP_FillDelayFrames when 2+. Higher = faster filling animation.

				!Setting_SpriteHP_EmptyDelayFrames				= $01
					;^Speed that the bar drains after damage. Only use these values:
					; $00,$01,$03,$07$,$0F,$1F,$3F or $7F. Lower values = faster

				!Setting_SpriteHP_BarEmptyPerFrame		= 2
					;^How many pieces in the bar drained per frame. This overrides
					; !Setting_SpriteHP_EmptyDelayFrames when 2+. Higher = faster draining
					; animation.

				!Setting_SpriteHP_BarChangeDelay				= 30
					;^How many frames the record effect (transparent effect) hangs
					; before shrinking down to current HP, up to 255 is allowed.
					; Set to 0 to disable (will also disable !Freeram_Setting_SpriteHP_BarChangeDelayTmr
					; from being used,). Remember, the game runs 60 FPS. This also applies
					; to healing should !Setting_SpriteHP_ShowHealedTransparent be enabled.

				!Setting_SpriteHP_ShowHealedTransparent		= 1
					;^0 = show sliding upwards animation
					; 1 = show amount healed as transparent segment.

				!Setting_SpriteHP_ShowDamageTransperent		= 1
					;^0 = show no transparent (if !Setting_SpriteHP_BarAnimation is
					;     enabled, would perform a sliding down animation as opaque)
					; 1 = show transparent.
					; This applies when the player takes damage.
	;Misc settings
		!Setting_SpriteHP_DisplaySpriteHPDataOnConsole = 1
			;^0 = no
			; 1 = yes, display the HP data RAM usage on asar console.



;Don't touch these unless you know what you're doing
	if !Setting_SpriteHP_DisplayGraphicalBar == 0	;>Override to disable unused animation for the bar if the bar doesn't exist.
		!Setting_SpriteHP_BarAnimation = 0
	endif

	if not(defined("StructGuard_SpriteHPData"))
		;^Just like labels, functions, and macros, this cannot be redefined. And includeonce fails if there are two involved
		; ASM files incsrcs with a different path to the same ASM file in which that file uses includeonce:
		; https://github.com/RPGHacker/asar/issues/287
		struct SpriteHPDataStructure !Setting_SpriteHP_SpriteHPData
			.SpriteSlot: skip 1
			.CurrentHPLow: skip !sprite_slots
			.MaxHPLow: skip !sprite_slots
			if !Setting_SpriteHP_TwoByte
				.CurrentHPHigh: skip !sprite_slots
				.MaxHPHigh: skip !sprite_slots
			endif
			if !Setting_SpriteHP_BarAnimation
				.BarAnimationFill: skip !sprite_slots
				.BarAnimationTimer: skip !sprite_slots
			endif
		endstruct
		!StructGuard_SpriteHPData = 1
	endif
	if !Setting_SpriteHP_DisplaySpriteHPDataOnConsole
		print "---------------------------------------------------------------------------------"
		print "Sprite HP data layout (use this for Address Tracker)"
		print "---------------------------------------------------------------------------------"
		print "$", hex(SpriteHPDataStructure.SpriteSlot), " 1 Current index to display sprite's HP"
		print "$", hex(SpriteHPDataStructure.CurrentHPLow), " ", dec(!sprite_slots), " Sprite current HP, low byte."
		print "$", hex(SpriteHPDataStructure.MaxHPLow), " ", dec(!sprite_slots), " Sprite max HP, low byte."
		if !Setting_SpriteHP_TwoByte
			print "$", hex(SpriteHPDataStructure.CurrentHPHigh), " ", dec(!sprite_slots), " Sprite current HP, high byte."
			print "$", hex(SpriteHPDataStructure.MaxHPHigh), " ", dec(!sprite_slots), " Sprite max HP, high byte."
		endif
		if !Setting_SpriteHP_BarAnimation
			print "$", hex(SpriteHPDataStructure.BarAnimationFill), " ", dec(!sprite_slots), " Sprite graphical bar fill amount for animation."
			print "$", hex(SpriteHPDataStructure.BarAnimationTimer), " ", dec(!sprite_slots), " Sprite graphical bar fill delay timer."
		endif
		print "---------------------------------------------------------------------------------"
	endif
	
	!Setting_SpriteHP_TrueMaximumHPAndDamageValue = min((10**!Setting_SpriteHP_MaxDigits)-1, (2**(8*(1+!Setting_SpriteHP_TwoByte)))-1)