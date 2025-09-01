	incsrc "StatusBarDefines.asm"
;Freeram settings
	;[BytesUsed = 1 + (!sprite_slots*2) + (!sprite_slots * EnabledTables)]
	;Where "EnabledTables" is how many tables you can optionally have:
	; - High bytes if you want 16-bit HP: if !Setting_SpriteHP_TwoByte == 1. This
	;   adds 2 tables, one for current HP, and the other for max HP.
	; - Bar fill animation. When !Setting_SpriteHP_DisplayGraphicalBar == 1 and
	;   !Setting_SpriteHP_BarAnimation == 1, this adds 1 table.
	; - Bar fill delay. If having all these conditions met:
	; -- !Setting_SpriteHP_DisplayGraphicalBar != 0
	; -- !Setting_SpriteHP_BarAnimation != 0
	; -- !Setting_SpriteHP_BarChangeDelay != 0
	;   then 1 table is added.
	;
	;A series of HP data stored in memory, in this order:
	;
	; - Define: !Freeram_SpriteHP_MeterState
	; -- BytesUsed: 1
	; -- Description: State of the HP meter display, mainly acting as a sprite slot selector. The values here are:
	; --- When ranging from 0 to (!sprite_slots-1), will display HP. Each value here corresponds to a sprite slot index.
	; --- When ranging from !sprite_slots to (!sprite_slots*2)-1, is the same as above, but for "IntroFill" mode (when
	;     bosses appears, meter appears initially empty and fills up). Only used if !Setting_SpriteHP_BarAnimation == 1.
	;
	; - Define: !Freeram_SpriteHP_CurrentHPLow
	; -- BytesUsed: !sprite_slots
	; -- Description: Sprite's current HP, low byte
	;
	; - Define: !Freeram_SpriteHP_MaxHPLow
	; -- BytesUsed: !sprite_slots
	; -- Description: Sprite's max HP, low byte
	;
	; - Define: !Freeram_SpriteHP_CurrentHPHi
	; -- BytesUsed: [BytesUsed = !sprite_slots * !Setting_SpriteHP_TwoByte]
	; -- Description: Sprite's current HP, high byte
	;
	; - Define: !Freeram_SpriteHP_MaxHPHi
	; -- BytesUsed: [BytesUsed = !sprite_slots * !Setting_SpriteHP_TwoByte]
	; -- Sprite's max HP, high byte
	;
	; - Define: !Freeram_SpriteHP_BarAnimationFill
	; -- BytesUsed: [BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayGraphicalBar & !Setting_SpriteHP_BarAnimation)]
	; -- Description: A secondary fill amount of the bar, apart from the sprite's current HP's fill amount. This is to
	;    briefly show previous HP fill amount prior to taking damage or healing before gradually increases or decreases
	;    to the sprite's current HP fill amount. This is also used for IntroFill animation.
	;
	; - Define: !Freeram_SpriteHP_BarAnimationTimer
	; -- BytesUsed: [BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayGraphicalBar & !Setting_SpriteHP_BarAnimation & (!Setting_SpriteHP_BarChangeDelay != 0))]
	; -- Description: delay timer (decreases itself once per frame) before !Freeram_SpriteHP_BarAnimationFill updates to
	;    the sprite's current HP fill amount. This is ignored if "IntroFill" mode is active.
	;
	;If you want to know display the RAM usage of this, have !Setting_SpriteHP_DisplaySpriteHPDataOnConsole set to 1 and
	;insert via uberasm tool. The console window will show the list of itemized used RAM.
		if !sa1 == 0
			!Freeram_SpriteHP_SpriteHPData = $7FACC4
		else
			!Freeram_SpriteHP_SpriteHPData = $400110
		endif
	;Scratch RAM settings (very likely you don't need to change these)
		!Scratchram_SpriteHP_SpriteSlotToDisplay = $8A
			;[1 byte]: This holds the current sprite slot used by various codes to determine what sprite slot the HP meter is showing.
			;This RAM address size must not be 3 bytes long (so $xx and $xxxx are okay, but $xxxxxx are not). It's basically
			;Value = !Freeram_SpriteHP_MeterState % !sprite_slots.
		;[BytesUsed = !Setting_SpriteHP_BarAnimation && UsingWendyOrLemmy]. This RAM is only used when vanilla smw boss Wendy or Lemmy koopa
		;are running. For some reason, SMW either deletes those sprites temporarily ($14C8,x == $00), or just clear all the sprite tables
		;including an unused one $1FD6. Therefore using sprite tables to determine if the introfill animation have already been played,
		;doesn't work and will replay the animation every time the koopa retreats in the pipe.
		;
		;By default, this will use the last block in the level map16 data (bottom-right corner). Very unlikely you would need to use the
		;entire level dimension for a boss room.
			if !sa1 == 0
				!Freeram_WendyLemmyIntroFlag		= $7EFFFF
			else
				!Freeram_WendyLemmyIntroFlag		= $40FFFF
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
				!Setting_SpriteHP_ExcessDigitProt = 1
					;^Maximum character write failsafe. If there are longer strings than expected, the number display routine will simply
					; not display the number.
			;Position of the numerical HP display, will occupy this position and tiles to the right
			;when set to. Only used when !Setting_SpriteHP_NumericalTextAlignment < 2.
				!Setting_SpriteHP_NumericalPos_x = 21
				!Setting_SpriteHP_NumericalPos_y = 0
			;Position for right-aligned, when !Setting_SpriteHP_NumericalTextAlignment == 2.
				!Setting_SpriteHP_NumericalPosRightAligned_x = 31
				!Setting_SpriteHP_NumericalPosRightAligned_y = 0
			;Tile properties for numbers
				!Setting_SpriteHP_Numerical_PropPage	= 0	;>Valid values: 0-3
				!Setting_SpriteHP_Numerical_PropPalette	= 6	;>Valid values: 0-7
		;Graphical bar settings
			!Setting_SpriteHP_DisplayGraphicalBar = 1
				;^0 = don't show the bar
				; 1 = display the bar
			;XY position of the bar (uses this position and tiles to the right, even when leftwards)
				!Setting_SpriteHP_GraphicalBarPos_x = 23
				!Setting_SpriteHP_GraphicalBarPos_y = 1
			;These below affect how much fill capacity the bar has. This value is equal to LeftPieces + (MiddlePieces * MiddleLength) + RightPieces.
			;If you have !Setting_SpriteHP_BarAnimation == 0, up to 255 is safe, otherwise up to 254 (255 is a special value to cancel out the animation).
				;Number of pieces on each tile
					!Setting_SpriteHP_GraphicalBar_LeftPieces                  = 3             ;\These will by default, set the RAM for the pieces for each section
					!Setting_SpriteHP_GraphicalBar_MiddlePieces                = 8             ;|(note that these apply for both levels and overworlds)
					!Setting_SpriteHP_GraphicalBar_RightPieces                 = 3             ;/
				;Length of bar (number of middle tiles). Full screen width is 32 tiles.
					!Setting_SpriteHP_GraphicalBarMiddleLength           = 7
			;Avoid percentage bar from representing 0 or full when really close but not at those values:
				!Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull	= 3
					;^0 = allow bar to display 0% when HP is very close to zero and 100% when close to max.
					; 1 = display 1 pixel of piece filled when low on HP and only 0 if HP is 0.
					; 2 = display MaxPieces-1 when nearly full.
					; 3 = Display 1 piece or MaxPieces-1 if close to 0 or MaxPieces.
			;Rounding the amount of fill settings:
				!Setting_SpriteHP_BarFillRoundDirection = 0
					; 0 = Round to nearest
					; 1 = Round down (bar may display 0 fill amount when !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull isn't 1 or 3)
					; 2 = Round up
			;Fill direction. 0 = Left-to-right, 1 = Right-to-left
				!Setting_SpriteHP_LeftwardsBar                       = 1
			;Tile properties (X-flip for leftwards bar is already handled.)
				!Setting_SpriteHP_BarProps_Page                      = 0  ;>Use only values 0-3
				!Setting_SpriteHP_BarProps_Palette                   = 6  ;>Use only values 0-7
				
			;Bar animation stuff
				!Setting_SpriteHP_BarAnimation			= 1
					;^0 = HP bar instantly updates when the enemy heals or take damage
					;     (!Freeram_SpriteHP_BarRecord is no longer used).
					; 1 = Shows animation (gradual change, rapid-flicker for previous and current HP).

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
					; Set to 0 to disable (will also disable !Freeram_SpriteHP_BarAnimationTimer
					; from being used). Remember, the game runs 60 FPS. This also applies
					; to healing should !Setting_SpriteHP_ShowHealedTransparent be enabled.

				!Setting_SpriteHP_ShowHealedTransparent		= 1
					;^0 = show sliding upwards animation (with an optional sound effect)
					; 1 = show amount healed as transparent segment.

				!Setting_SpriteHP_ShowDamageTransperent		= 1
					;^0 = show no transparent (if !Setting_SpriteHP_BarAnimation is
					;     enabled, would perform a sliding down animation as opaque)
					; 1 = show transparent.
					; This applies when the sprite takes damage.
				;Sound effect when the bar fills up (boss intro, or when enemy heals).
				;See https://www.smwcentral.net/?p=viewthread&t=6665
					!Setting_SpriteHP_FillingSFXNumb		= $23		;>Sound number (set to 0 to disable SFX)
					!Setting_SpriteHP_FillingSFXPort		= $1DFC|!addr	;>Use $1DF9, $1DFA, or $1DFC, followed by "|!addr" if you're using SA-1
	;Patching settings
		;Apply displaying HP on various vanilla SMW sprites: 0 = no, 1 = yes, again, use only mentioned values,
		;unless stated otherwise.
			!Setting_SpriteHP_ModifySMWSprites			= 1	;>Universal option if you want to not have HP meters for all vanilla SMW sprites.
			!Setting_SpriteHP_VanillaSprite_Chuck			= 1
				;^All the chucks in SMW.
			!Setting_SpriteHP_VanillaSprite_Bosses			= 1
				;^Includes:
				;-Big boo boss
				;-Wendy and Lemmy (share most of the same code)
				;-Ludwig, Morton, and Roy (same as above)
				
				
		;Amount of HP SMW sprites has. NOTE: SMW only have hit counts being an 8-bit unsigned integer stored
		;within various sprite tables (Chucks and any sprites using the 5 fireballs to kill: $1528,
		;Ludwig/Morton/Roy: $1626, Big Boo Boss, Wendy and Lemmy: $1534). This means up to 255 health and
		;damage are allowed, and those does not support 16-bit HP system.
		;This only applies if !Setting_SpriteHP_ModifySMWSprites == 1 and their respective settings being 1.
			!Setting_SpriteHP_VanillaSprite_ChuckHPAmount		= 15	;>This applies to all chuck varients.
			!Setting_SpriteHP_VanillaSprite_Chuck_StompDamage	= 5	;>Amount of HP loss when taking damage from stomp attacks
			
			!Setting_SpriteHP_VanillaSprite_BigBooBossHPAmount		= 3	;>Amount of HP Big Boo boss have.
			!Setting_SpriteHP_VanillaSprite_BigBooBossThrownItemDamage	= 1	;>Amount of damage Big Boo boss takes from any thrown sprite.
			
			!Setting_SpriteHP_VanillaSprite_WendyLemmyHPAmount	= 3
			!Setting_SpriteHP_VanillaSprite_WendyLemmyStompDamage	= 1
			;Following settings are HP and damage values for Ludwig, Morton and Roy.
			;
			;Be careful with having too much health and too little damage from stomp attacks for Roy, if its possible to stomp Roy too many times
			;(from my testing, 7 and higher) before he dies, the pillars of the arena can glitch since Nintendo didn't program a limit on how
			;far the pillars can move. To know if its possible, do the math: NumberOfStomps = ceiling(Health/StompDamage), where ceiling rounds
			;the number up to an integer.
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyHPAmount		= 12
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyStompDamage	= 4
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyFireballDamage	= 1
		;For any sprite whose tweaker $190F's bit 3 (%wcdj5sDp, takes 5 fireballs to kill) is set:
			!Setting_SpriteHP_FireballDamageAmount			= 3	;>Amount of damage sprites recieves from fireball damage.
		;Fixes and additions
			;Sound effect when the fireball hits chucks. See: https://www.smwcentral.net/?p=viewthread&t=6665
				!Setting_SpriteHP_VanillaSprite_ChuckFireDamage_SoundNumber	= $28		;>Set to 0 to disable.
				!Setting_SpriteHP_VanillaSprite_ChuckFireDamage_SoundPort	= $1DFC|!addr
			;Same but when shooting fireballs to Ludwig, Morton, and Roy.
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyDamage_SoundNumber	= $28
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoyDamage_SoundPort		= $1DFC|!addr
	;Misc settings
		!Setting_SpriteHP_DisplaySpriteHPDataOnConsole = 1
			;^0 = no
			; 1 = yes, display the HP data RAM usage on asar console.



;Don't touch these unless you know what you're doing
	if !Setting_SpriteHP_DisplayGraphicalBar == 0	;>Override to disable unused animation for the bar if the bar doesn't exist.
		!Setting_SpriteHP_BarAnimation = 0
	endif
	;Obtain addresses representing HP data
		if not(defined("MacroGuard_SpriteHPData"))
			;^Labels, structs, functions, and macros, they cannot be redefined. And includeonce fails if there are two involved
			; ASM files incsrcs with a different path to the same ASM file in which that file uses includeonce:
			; https://github.com/RPGHacker/asar/issues/287
			!AddressLocator #= !Freeram_SpriteHP_SpriteHPData
			macro MacroAssignDefineOneAfterAnother(Define_Name, Size, Define_Name_Offseter)
				;This macro assigns Define_Name to an address, then offsets (Plus Size)
				;to the first byte after the last byte of Define_Name. This is useful
				;for having multiple defines at contiguous regions by repeatedly calling
				;this macro with different Define_Name.
				!{<Define_Name>} #= !{<Define_Name_Offseter>}
				!{<Define_Name_Offseter>} #= <Size>+!<Define_Name_Offseter>
			endmacro
			
			;The following also needs to have each of them be calling macros once, else they end up being set again to another,
			;different RAM address.
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MeterState, 1, AddressLocator)
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_CurrentHPLow, !sprite_slots, AddressLocator)
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MaxHPLow, !sprite_slots, AddressLocator)
				if !Setting_SpriteHP_TwoByte
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_CurrentHPHi, !sprite_slots, AddressLocator)
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MaxHPHi, !sprite_slots, AddressLocator)
				endif
				if !Setting_SpriteHP_BarAnimation
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_BarAnimationFill, !sprite_slots, AddressLocator)
					if !Setting_SpriteHP_BarChangeDelay
						%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_BarAnimationTimer, !sprite_slots, AddressLocator)
					endif
				endif
			!MacroGuard_SpriteHPData = 1
		endif
	;Get status bar addresses
		!Setting_SpriteHP_NumericalPos_XYPos = VanillaStatusBarXYToAddress(!Setting_SpriteHP_NumericalPos_x, !Setting_SpriteHP_NumericalPos_y, !RAM_0EF9)
		!Setting_SpriteHP_NumericalPosRightAligned_XYPos = VanillaStatusBarXYToAddress(!Setting_SpriteHP_NumericalPosRightAligned_x, !Setting_SpriteHP_NumericalPosRightAligned_y, !RAM_0EF9)
		!Setting_SpriteHP_GraphicalBarPos_XYPos = VanillaStatusBarXYToAddress(!Setting_SpriteHP_GraphicalBarPos_x, !Setting_SpriteHP_GraphicalBarPos_y, !RAM_0EF9)
		if !UsingCustomStatusBar
			!Setting_SpriteHP_NumericalPos_XYPos = PatchedStatusBarXYToAddress(!Setting_SpriteHP_NumericalPos_x, !Setting_SpriteHP_NumericalPos_y, !StatusBarPatchAddr_Tile, !StatusbarFormat)
			!Setting_SpriteHP_NumericalPos_XYPosProp = PatchedStatusBarXYToAddress(!Setting_SpriteHP_NumericalPos_x, !Setting_SpriteHP_NumericalPos_y, !StatusBarPatchAddr_Prop, !StatusbarFormat)
			
			!Setting_SpriteHP_NumericalPosRightAligned_XYPos = PatchedStatusBarXYToAddress(!Setting_SpriteHP_NumericalPosRightAligned_x, !Setting_SpriteHP_NumericalPosRightAligned_y, !StatusBarPatchAddr_Tile, !StatusbarFormat)
			!Setting_SpriteHP_NumericalPosRightAligned_XYPosProp = PatchedStatusBarXYToAddress(!Setting_SpriteHP_NumericalPosRightAligned_x, !Setting_SpriteHP_NumericalPosRightAligned_y, !StatusBarPatchAddr_Prop, !StatusbarFormat)
			
			!Setting_SpriteHP_GraphicalBarPos_XYPos = PatchedStatusBarXYToAddress(!Setting_SpriteHP_GraphicalBarPos_x, !Setting_SpriteHP_GraphicalBarPos_y, !StatusBarPatchAddr_Tile, !StatusbarFormat)
			!Setting_SpriteHP_GraphicalBarPos_XYPosProp = PatchedStatusBarXYToAddress(!Setting_SpriteHP_GraphicalBarPos_x, !Setting_SpriteHP_GraphicalBarPos_y, !StatusBarPatchAddr_Prop, !StatusbarFormat)
		endif
	;Get YXPCCCTT data
		!Setting_SpriteHP_NumericalProp = GetLayer3YXPCCCTT(0, 0, 1, !Setting_SpriteHP_Numerical_PropPalette, !Setting_SpriteHP_Numerical_PropPage)
		!Setting_SpriteHP_GraphicalBarProp = GetLayer3YXPCCCTT(0, 0, 1, !Setting_SpriteHP_BarProps_Palette, !Setting_SpriteHP_BarProps_Page)
	;Graphical bar values
		!Setting_SpriteHP_GraphicalBar_LeftEndExists #= notequal(!Setting_SpriteHP_GraphicalBar_LeftPieces, 0)
		!Setting_SpriteHP_GraphicalBar_MiddleExists #= !Setting_SpriteHP_GraphicalBarMiddleLength*(notequal(!Setting_SpriteHP_GraphicalBar_MiddlePieces, 0))
		!Setting_SpriteHP_GraphicalBar_RightEndExists #= notequal(!Setting_SpriteHP_GraphicalBar_RightPieces, 0)
		!Setting_SpriteHP_GraphicalBar_TotalTiles #= !Setting_SpriteHP_GraphicalBar_LeftEndExists+!Setting_SpriteHP_GraphicalBar_MiddleExists+!Setting_SpriteHP_GraphicalBar_RightEndExists
		!Setting_SpriteHP_GraphicalBar_TotalPieces #= !Setting_SpriteHP_GraphicalBar_LeftPieces+(!Setting_SpriteHP_GraphicalBarMiddleLength*!Setting_SpriteHP_GraphicalBar_MiddlePieces)+!Setting_SpriteHP_GraphicalBar_RightPieces
	
	;Maximum string length failsafe
		!Setting_SpriteHP_MaxStringLength = !Setting_SpriteHP_MaxDigits
		if !Setting_SpriteHP_DisplayNumerical == 2
			!Setting_SpriteHP_MaxStringLength = (!Setting_SpriteHP_MaxDigits*2)+1
		endif
	if !Setting_SpriteHP_DisplaySpriteHPDataOnConsole
		print "---------------------------------------------------------------------------------"
		print "\!Freeram_SpriteHP_SpriteHPData's Total bytes used: ", dec(!AddressLocator-!Freeram_SpriteHP_SpriteHPData)
		print "Range: $", hex(!Freeram_SpriteHP_SpriteHPData), "~$", hex(!AddressLocator-1)
		print "---------------------------------------------------------------------------------"
		print "\!Freeram_SpriteHP_SpriteHPData (Address Tracker format)"
		print "---------------------------------------------------------------------------------"
		print "$", hex(!Freeram_SpriteHP_MeterState), " 1 Current index to display sprite's HP (\!Freeram_SpriteHP_MeterState)."
		print "$", hex(!Freeram_SpriteHP_CurrentHPLow), " ", dec(!sprite_slots), " Sprite current HP, low byte (\!Freeram_SpriteHP_CurrentHPLow)."
		print "$", hex(!Freeram_SpriteHP_MaxHPLow), " ", dec(!sprite_slots), " Sprite max HP, low byte (\!Freeram_SpriteHP_MaxHPLow)."
		if !Setting_SpriteHP_TwoByte
			print "$", hex(!Freeram_SpriteHP_CurrentHPHi), " ", dec(!sprite_slots), " Sprite current HP, high byte (\!Freeram_SpriteHP_CurrentHPHi)."
			print "$", hex(!Freeram_SpriteHP_MaxHPHi), " ", dec(!sprite_slots), " Sprite max HP, high byte (\!Freeram_SpriteHP_MaxHPHi)."
		endif
		if !Setting_SpriteHP_BarAnimation
			print "$", hex(!Freeram_SpriteHP_BarAnimationFill), " ", dec(!sprite_slots), " Sprite graphical bar fill amount for animation (\!Freeram_SpriteHP_BarAnimationFill)."
			if !Setting_SpriteHP_BarChangeDelay
				print "$", hex(!Freeram_SpriteHP_BarAnimationTimer), " ", dec(!sprite_slots), " Sprite graphical bar fill delay timer (\!Freeram_SpriteHP_BarAnimationTimer)."
			endif
		endif
		print "---------------------------------------------------------------------------------"
	endif
	
	!Setting_SpriteHP_TrueMaximumHPAndDamageValue = min((10**!Setting_SpriteHP_MaxDigits)-1, (2**(8*(1+!Setting_SpriteHP_TwoByte)))-1)
	