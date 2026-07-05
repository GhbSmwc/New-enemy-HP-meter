	incsrc "StatusBarDefines.asm"
;Freeram settings
	;NOTE:
	; - If boolean operators are involved on how much bytes used, the boolean operator will output either 0 for false
	;   or 1 for true. For example:
	;    12 * (1 && 1) would be ( "&&" is an AND boolean operator):
	;    12 * 1
	;    = 12
	;    
	;    !sprite_slots = Number of sprite slots: 12 for LoROM, 22 for SA-1
	;
	;[BytesUsed = 1                                                                                                       ;>1 Byte for HP meter state
	; + (!sprite_slots*2)                                                                                                 ;>Bytes used for low bytes of current and max HP.
	; + ((!sprite_slots*2) * !Setting_SpriteHP_TwoByte)                                                                   ;>Bytes used for the high bytes of current and max HP, if !Setting_SpriteHP_TwoByte == 1
	; + (!Setting_SpriteHP_DisplayGraphicalBar * !Setting_SpriteHP_BarAnimation)                                          ;>Byte used as a secondary fill amount for animation.
	; + ((!Setting_SpriteHP_DisplayGraphicalBar * !Setting_SpriteHP_BarAnimation)*(!Setting_SpriteHP_BarAnimation != 0))] ;>Byte used as a timer of how long the secondary fill amount pauses before following current HP fill.
	; + (2 * (1 + !Setting_SpriteHP_TwoByte) * (!Setting_SpriteHP_TotalHPMode != 0))                                      ;>Bytes used to track the total HP of multiple sprites.
	;
	;A series of HP data stored in memory, in this order (placed contiguously):
	;
	; - Define: !Freeram_SpriteHP_MeterState
	; -- BytesUsed: 1
	; -- Description: State of the HP meter display, mainly acting as a sprite slot selector. The values here are:
	; --- When ranging from 0 to (!sprite_slots-1), will display HP. Each value here corresponds to a sprite slot index.
	; --- When ranging from !sprite_slots to (!sprite_slots*2)-1, is the same as above, but for "IntroFill" mode (when
	;     bosses appears, meter appears initially empty and fills up). Only used if !Setting_SpriteHP_BarAnimation == 1.
	; --- When equal to $FF, will not display the meter, which occurs when the enemy despawns or dies. Note that this
	;     will write blank tiles every frame.
	; --- When equal to $FE, will be "disabled", it will clear the tiles only this current frame, then sets itself to
	;     $FD. Make sure you don't set this to $FE every frame though.
	; --- When equal to $FD, will also be "disabled", this will not write anything on the spot the HP meter occupies
	;     (stops writing tiles here every frame, including blank tiles).
	;
	;  Disable mode is useful if you need a HUD element on that spot where the HP meter is placed on (when $FD). This
	;  also prevents IntroFill and enemy damage from displaying the HP meter.
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
	; -- BytesUsed: [BytesUsed = (!Setting_SpriteHP_DisplayGraphicalBar && !Setting_SpriteHP_BarAnimation)]
	; -- Description: A secondary fill amount of the bar, apart from the sprite's current HP's fill amount. This is to
	;    briefly show previous HP fill amount prior to taking damage or healing before gradually increases or decreases
	;    to the sprite's current HP fill amount. This is also used for IntroFill animation, it being the amount of fill
	;    as it fills up.
	;
	; - Define: !Freeram_SpriteHP_BarAnimationTimer
	; -- BytesUsed: [BytesUsed = (!Setting_SpriteHP_DisplayGraphicalBar && !Setting_SpriteHP_BarAnimation && (!Setting_SpriteHP_BarChangeDelay != 0))]
	; -- Description: Delay timer (decreases itself once per frame) before !Freeram_SpriteHP_BarAnimationFill updates to
	;    the sprite's current HP fill amount. This is ignored if "IntroFill" mode is active.
	;
	; - Define: !Freeram_SpriteHP_TotalHPOfUnloadedSprites
	; -- BytesUsed: [BytesUsed = (1 + !Setting_SpriteHP_TwoByte) * !Setting_SpriteHP_TotalHPMode]
	; -- Description: The amount of HP of sprites not currently loaded (can be used as an ambush system where total HP includes enemies that aren't
	;    loaded until later after a certain number of them are defeated). This ASM will add the HPs of the currently loaded sprite slots, then add by
	;    this value, and the final result is the total HP.
	;
	; - Define: !Freeram_SpriteHP_TotalMaxHP
	; -- BytesUsed: [BytesUsed = (1 + !Setting_SpriteHP_TwoByte) * !Setting_SpriteHP_TotalHPMode]
	; -- Description: The amount of max HP of sprites when HP meter is in "total mode".
	;
	; Summary:
	; - LoROM number of bytes used: 25 to 55.
	; - SA-1 ROM number of bytes used: 45 to 95.
	;
	;If you want to know display the RAM usage of this, have !Setting_SpriteHP_DisplaySpriteHPDataOnConsole set to 1 and
	;insert via uberasm tool. The console window will show the list of itemized used RAM, in "Address Tracker" format:
	;https://www.smwcentral.net/?p=section&a=details&id=39887.
		if !sa1 == 0
			!Freeram_SpriteHP_SpriteHPData = $7FACC4
		else
			!Freeram_SpriteHP_SpriteHPData = $418AFF
		endif
	;Scratch RAM settings (very likely you don't need to change these)
		!Scratchram_SpriteHP_SpriteSlotToDisplay = $8A
			;[1 byte]: This holds the current sprite slot used by various codes to determine what sprite slot the HP meter is showing.
			;This RAM address size must not be 3 bytes long (so $xx and $xxxx are okay, but $xxxxxx are not). It's basically
			;Value = !Freeram_SpriteHP_MeterState % !sprite_slots.
	;Qusai-freeram for miscellaneous things (flags to prevent re-triggers)
		;[BytesUsed = !Setting_SpriteHP_BarAnimation && UsingWendyOrLemmy]. This RAM is only used when vanilla smw boss Wendy or Lemmy koopa
		;are running. For some reason, SMW either deletes those sprites temporarily ($14C8,x == $00), or just clear all the dummy sprites
		;including an unused one $1FD6. Therefore using sprite tables to determine if the introfill animation have already been played,
		;doesn't work and will replay the animation every time Wendy/Lemmy retreat in their pipes.
		;By default, this will use the last block in the level map16 data (bottom-right corner). Very unlikely you would need to use the
		;entire level dimension for a 1-screen boss room. It checks if this value != $25, then play the intro effect, then sets it to $00.
		;This also means you should not place any other block here.
			if !sa1 == 0
				!Ram_WendyLemmyIntroFlag		= $7EFFFF
			else
				!Ram_WendyLemmyIntroFlag		= $40FFFF
			endif
		;[BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayHPOfSMWSprites && !Setting_SpriteHP_VanillaSprite_Chuck)].
		;This RAM is used on a code that runs every frame for Chucks to switch the HP meter to them when they instantly die (cape spins,
		;kicked shells, bounce blocks, etc.). It is used to check if the meter have already been switch to them to make it only perform once.
		;I wouldn't want to add a hijack to every instance of $14C8 getting set to any of their death values. This should only be any unused
		;sprite table by the Chucks (and therefore must be cleared
		;when they load).
			!Ram_SpriteTable_CharginChuck_InstaKillHaveDisplayedHP = !1626
		;[BytesUsed = !sprite_slots * (!Setting_SpriteHP_DisplayHPOfSMWSprites && !Setting_SpriteHP_VanillaSprite_Rex)].
		;Same as above but for Rex.
			!Ram_SpriteTable_Rex_InstaKillHaveDisplayedHP = !1626
;Settings
	;HUD settings
		;Notes:
		;About XY tile positions:
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
		;
		;XY positions are calculated to an address in StatusBarDefines.asm
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
			;Position for right-aligned, when !Setting_SpriteHP_NumericalTextAlignment == 2. This occupies
			;tiles at this position, and to the left.
				!Setting_SpriteHP_NumericalPosRightAligned_x = 31
				!Setting_SpriteHP_NumericalPosRightAligned_y = 0
			;Tile properties for numbers
				!Setting_SpriteHP_Numerical_PropPage	= 0	;>Valid values: 0-3
				!Setting_SpriteHP_Numerical_PropPalette	= 6	;>Valid values: 0-7
		;Graphical bar settings
			!Setting_SpriteHP_DisplayGraphicalBar = 1
				;^Display a bar representing percentage as fill?
				; - 0 = don't show the bar
				; - 1 = display the bar
			;XY position of the bar (uses this position and tiles to the right, even when leftwards)
				!Setting_SpriteHP_GraphicalBarPos_x = 23
				!Setting_SpriteHP_GraphicalBarPos_y = 1
			;These below affect how much fill capacity the bar has. This value is equal to LeftPieces + (MiddlePieces * MiddleLength) + RightPieces.
			;For more information, see info about graphical bar linked from "Documentations of other ASM resources" in the readme. Setting them to 0
			;will exclude the type of tile on the bar. 1-255 are valid and will include that tile on the HUD. 256+, don't use those values.
				;Number of pieces on each tile
					!Setting_SpriteHP_GraphicalBar_LeftPieces                  = 3             ;\These are the amount of fill capacity of each part of the bar.
					!Setting_SpriteHP_GraphicalBar_MiddlePieces                = 8             ;|
					!Setting_SpriteHP_GraphicalBar_RightPieces                 = 3             ;/
				;Length of bar (number of middle tiles). Full screen width is 32 tiles.
					!Setting_SpriteHP_GraphicalBarMiddleLength           = 7
			!Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull	= 3
				;^Round away from 0% and/or 100% when fill is close to such values:
				; - 0 = Allow bar to display 0% when HP is very close to zero and 100% when close to max.
				; - 1 = Display 1 pixel of piece filled when low on HP and only 0 if HP is 0.
				; - 2 = Display MaxPieces-1 when nearly full.
				; - 3 = Display 1 piece or MaxPieces-1 if close to 0 or MaxPieces.
			!Setting_SpriteHP_BarFillRoundDirection = 0
				;^Rounding to nearest integer fill amount of the bar:
				; - 0 = Round to nearest
				; - 1 = Round down (floor, bar may display 0 fill amount when close to when !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull isn't 1 or 3).
				; - 2 = Round up (ceiling, bar may display full when close to when !Setting_SpriteHP_GraphicalBar_RoundAwayEmptyFull isn't 2 or 3).
			;Fill direction. 0 = Left-to-right, 1 = Right-to-left. Note that the given XY position will occupy that position and N tiles towards
			;the right regardless of leftwards or not.
				!Setting_SpriteHP_LeftwardsBar                       = 1
			;Tile properties (X-flip for leftwards bar is already handled.)
				!Setting_SpriteHP_BarProps_Page                      = 0  ;>Use only values 0-3
				!Setting_SpriteHP_BarProps_Palette                   = 6  ;>Use only values 0-7
				
			;Bar animation stuff
				!Setting_SpriteHP_BarAnimation			= 1
					;^Show animation of the bar:
					; - 0 = HP bar instantly updates when the enemy heals or take damage
					;   (!Freeram_SpriteHP_BarRecord and introfill is no longer used).
					; - 1 = Shows animation (gradual change, rapid-flicker, transparent
					;   effect to display previous and current HP fill amounts to indicate
					;   damage and healing).

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
					; Also applies to healing animation, where the meter shows
					; a transparent part before filling that area up when enabled.
					; Set to 0 to disable (will also disable !Freeram_SpriteHP_BarAnimationTimer
					; from being used). Remember, the game runs 60 FPS. This also applies
					; to healing should !Setting_SpriteHP_ShowHealedTransparent be enabled.

				!Setting_SpriteHP_ShowHealedTransparent		= 1
					;^Show HP change effect when healing:
					; - 0 = show opaque sliding upwards animation.
					; - 1 = show amount healed as transparent segment.
					; Note that reguardless of this setting, there's an optional sound effect
					; for filling (for healing and intro-fill).

				!Setting_SpriteHP_ShowDamageTransperent		= 1
					;^- 0 = show no transparent (if !Setting_SpriteHP_BarAnimation is
					; -     enabled, would perform a sliding down animation as opaque)
					; - 1 = show transparent.
					; This applies when the sprite takes damage.
				;Sound effect when the bar fills up (boss intro and when enemy heals).
				;See https://www.smwcentral.net/?p=viewthread&t=6665
					!Setting_SpriteHP_FillingSFXNumb		= $23		;>Sound number (set to 0 to disable SFX)
					!Setting_SpriteHP_FillingSFXPort		= $1DFC|!addr	;>Use $1DF9, $1DFA, or $1DFC, followed by "|!addr" if you're using SA-1
	;Patching settings
		!Setting_SpriteHP_RemoveOrApplyPatch		= 1
			;^Option to install or remove the patch.
			; 0 = Remove patch, 1 = Install.
			; NOTE: If you make hex edits at certain addresses, and you have patch this with this option set to
			; 0, it will revert your hex edits in the process of restoring the game. This is because of the
			; restore function assumes you haven't hex edited at those addresses. The hijack locations are
			; found in "HPSystemForSMWSprites.asm", where org $xxxxxx indicates where to place data on (as well
			; as the macro calling "HijacksForFallingOffScrn").
			
		!Setting_SpriteHP_Modify5FireballsSystem = 1
			;^Make change on how fireballs work with $190F's 3 (%----X---), "takes 5 fireballs to kill":
			; - 0 = Keep vanilla (will treat $1528 as a damage counter)
			; - 1 = Deal direct damage (will use this patch's HP values directly, and no longer touches $1528)
			;Warning: This will affect all sprites using the 5-fireballs system when set to 1. The good news
			;is that in vanilla SMW, only Chucks use this, and is extremely rare for custom sprites to use this.
			;
			;NOTES:
			; - If you wish to have this set to 1 and are using Chucks in your game, then you need to have
			;   !Setting_SpriteHP_VanillaSprite_Chuck == 1 because otherwise their HP system would be broken
			;   (Having !Setting_SpriteHP_VanillaSprite_Chuck == 0 would revert chuck to use $1528 when being
			;   stomped, but the fireball damage code would not use $1528 but this patch's HP values instead,
			;   resulting in them having 2 separate HP values that they die when either one of them reaches 0).
			;
			; - If a sprite have its own built-in fireball damage handler, like Ludwig/Morton/Roy, and have
			;   $190F's "takes 5 fireballs to kill" be set, then it is possible the sprite takes both damage
			;   from the fireball's code and its own built-in.
			
		!Setting_SpriteHP_UsingCustomSprites = 1
			;^You using custom sprites (pixi)? 0 = No, 1 = Yes. This basically ignores RAM $7FAB10
			; when 0. Warning, having this set to 1 without custom sprite system installed results
			; in $7FAB10 being garbage values on certain emulators, which can cause glitches on
			; those emulators related to the HP meter system to incorrectly think sprites are
			; custom or not.
			
		;Apply (proper) HP system on various vanilla SMW sprites that are not strictly one-shot: 0 = no, 1 = yes.
		;Use only mentioned values, unless stated otherwise. Having these turned off will COMPLETELY revert back
		;to original format including the fireball and stomp damage jank (see readme under "...from a damage counter").
		;This also reverts the amount of HP a sprite has.
			!Setting_SpriteHP_VanillaSprite_Chuck		= 1
				;^Apply HP system for all chucks. Will at least fix the jank of stomp and fireball damage.
				
			!Setting_SpriteHP_VanillaSprite_Rex			= 1
				;^This will display HP of Rex:
				; - 0 = No
				; - 1 = Yes (handled via RAM $C2 as vanilla, transfers to HP RAMs used by here,
				;   cannot be over 255 even with !Setting_SpriteHP_TwoByte == 1)
				; - 2 = Yes (uses the new HP RAM directly, which allows more than 255 HP if
				;   !Setting_SpriteHP_TwoByte == 1). $C2 is now a state handler to determine if
				;   the sprite is normal, or half-squished.
			
			!Setting_SpriteHP_VanillaSprite_Pokey		= 1
				;^Show HP of Pokey (HP = how many segments, including the head)
				; - 0 = No
				; - 1 = Yes
				
			!Setting_SpriteHP_VanillaSprite_Bosses			= 1
				;^Same with bosses. It includes:
				; - Big boo boss
				; - Wendy and Lemmy (share most of the same code)
				; - Ludwig, Morton, and Roy (same as above). NOTE: Like the Chuck enemies, they also have fireball/stomp
				;   jank that needs to be fixed for a proper HP system (and to display it).
				; - Reznor (each of them). Note that this is catagorized as bosses rather than one-shot sprites.
				
			!Setting_SpriteHP_DisplayHPOfSMWSprites			= 1
				;^Simply display the HP of smw sprites?
				; - 0 = will not display HP.
				; - 1 = Will display the HP (requires !Setting_SpriteHP_RemoveOrApplyPatch == 1 and the jankfix).
				
		!Setting_SpriteHP_VanillaSprite_OneShotSprites			= 1
			;^Display HP for all one-shot enemies. Modifies various vanilla kill routines used by the vast majority
			; of enemies. 0 = No, 1 = Yes. Note that this also modifies the sprite table clearing routine (when sprite
			; spawns) due to not all sprites have an init to set its default HP.
			;
			; Notes:
			; - This includes enemies that turn into another sprite number when jumped on:
			; -- Dino Rhino are included here since jumping on them transforms it into a Dino Torch, becomming a one-shot
			;    sprite. I find it weird that if you do not wish one-shot sprites not have an HP meter and 2+ shots to have
			;    an HP meter, it would be weird that enemies spawned as a Dino Torch lack a meter, but a Dino Torch spawned
			;    after jumping on a Dino Rhino have a meter.
			; -- Winged enemies like Koopas and Galoomba.
			; -- It does not include parachute enemies (Galoomba and Bob-omb), because when they land, it would've shown
			;    that they taken damage themselves.
			; - Other enemies listed below will show the health meter in unique ways:
			; -- Enemies that don't get killed at all by stomps but instead simply change states will show no damage
			;    but will still display the meter: Wiggler, Dry Bones, Bony Beetle.
			; -- When regular Koopas Troopas are stomped, the HP meter will switch to the sprite slot of the shell, not
			;    the shell-less koopa it spawned (with the exception that you do not wish koopas get forced out of shells,
			;    see !Setting_SpriteHP_Koopas_ClassicBehavior). This is because the regular Koopa Troopas, the shell
			;    (wheather it's empty or stunned inside their shell with eyes showing) are the same sprite, just with a
			;    different state. When a shell-less koopa is launched out of the shell, that is a new sprite being spawned,
			;    and when they enter a shell, the shell-less koopa despawns and the shell becomes a koopa troopa.
			; --- That, along with the glitch of immidiately kicking the shell that the shell-less koopa just entered makes
			;     the shell an empty shell is a reason I can't have the meter not be on an empty shell.
			; - If there are enemies/sprites that shouldn't have HP meter display for them when killed, see under the
			;   label "ZeroOutHPOfOneShotSprites" in HPSystemForSMWSprites.asm. This runs once per sprite gets
			;   insta-killed.
			;
			; - For enemies that are switching states or changing sprite number from a thing that should have an HP meter
			;   and currently displayed for, into another thing that should make its HP meter disappear, see
			;   "UberASMTool/level/DisplayEnemyHP.asm" under label "...Exists". Note that this runs EVERY FRAME while the
			;   meter is active.
			;
			;   Alternatively, for custom sprites, you can simply make it hide the meter like so in its sprite code:
			;    ;[...]
			;    ;Assuming X is the current sprite slot processed
			;    JSL !SharedSub_SpriteHPGetSlotIndex
			;    TXA
			;    CMP !Scratchram_SpriteHP_SpriteSlotToDisplay ;>CPX $xxxxxx does not exists, 
			;    BNE .DontHideMeter ;>If meter is on other sprite and not this, don't suppress it.
			;    .HideHPMeter
			;     LDA #$FF
			;     STA !Freeram_SpriteHP_MeterState
			;    .DontHideHPMeter
			; - If you are using custom sprites with their own stun/death handler for one-shots (either within sprite
			;   code or pixi routine), you'll need to modify it if you wished to also make the HP meter switch to that
			;   enemy. This can be done like so:
			;    JSL !SharedSub_SpriteHPDamage
			;   If it's another sprite it interacts with, and uses the Y register for that other sprite, then do this
			;   instead:
			;    PHX
			;    TYX
			;    JSL !SharedSub_SpriteHPDamage
			;    PLX
			; - This does not include Reznor, however it is catagorized as "bosses" instead.
			
		;Amount of HP SMW sprites has. NOTE: SMW only have hit counts being an 8-bit unsigned integer stored
		;within various sprite tables (Chucks and any sprites using the 5 fireballs to kill: $1528,
		;Ludwig/Morton/Roy: $1626, Big Boo Boss, Wendy and Lemmy: $1534). This means up to 255 health and
		;damage are allowed, and those do not support 16-bit HP system (even if you set
		;!Setting_SpriteHP_TwoByte == 1). This does not include 1-shot enemies (they'll strictly be 1 HP
		;and dies instantly from any attack). That is, unless stated otherwise.
		
		;
		;This only applies if !Setting_SpriteHP_RemoveOrApplyPatch == 1 and their respective settings being 1.
		
			;Chucks. Values can be up to 65535 if these conditions are met:
			; - !Setting_SpriteHP_TwoByte == 1
			; - !Setting_SpriteHP_Modify5FireballsSystem == 1
				!Setting_SpriteHP_VanillaSprite_Chucks_HPAmount		= 15	;>This applies to all chuck variants and all sprites with "Take 5 fireballs to kill" of $190F's bit 3.
				!Setting_SpriteHP_VanillaSprite_Chucks_StompDamage	= 5	;>Amount of HP loss when taking damage from stomp attacks
			;Rex. Values can be up to 65535 if these conditions are met:
			; - !Setting_SpriteHP_VanillaSprite_Rex == 2
			; - !Setting_SpriteHP_TwoByte == 1
				!Setting_SpriteHP_VanillaSprite_Rex_HPAmount		= 2
					;^Amount of HP Rex has (only stomps, other attacks are insta-kill).
					;Note that after the first stomp attack will leave the Rex in his 1/2 height form.
				!Setting_SpriteHP_VanillaSprite_Rex_StompDamage		= 1
					;^The only nonlethal damage in the game.
			
			!Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount		= 3	;>Amount of HP Big Boo boss have.
			!Setting_SpriteHP_VanillaSprite_BigBooBoss_ThrownItemDamage	= 1	;>Amount of damage Big Boo boss takes from any thrown sprite.
			
			!Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount	= 3		;\Same as before.
			!Setting_SpriteHP_VanillaSprite_WendyLemmy_StompDamage	= 1		;/
			;Following settings are HP and damage values for Ludwig, Morton and Roy.
			;
			;Be careful with having too much health and too little damage from stomp attacks for Roy, if its possible to stomp Roy too many times
			;(from my testing, 7 and higher) before he dies, the pillars of the arena can glitch since Nintendo didn't program a limit on how
			;far the pillars can move. To know if its possible, do the math: NumberOfStomps = ceiling(Health/StompDamage), where ceiling rounds
			;the number up to an integer. A division by zero obviously means you can trigger the walls bugging out without damage.
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount	= 12
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_StompDamage	= 4
				!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_FireballDamage	= 1
		;For any sprite whose tweaker $190F's bit 3 (%wcdj5sDp, takes 5 fireballs to kill; bit 3) is set.
		;And along with other tweaker settings:
		; - $166E's bit 4 ("Disable fireball killing") to be 0 or false.
		; - $167A's bit 1 ("Invincible to star/cape/fire/bouncing bricks") to be 0 or false.
		;
		;If !Setting_SpriteHP_Modify5FireballsSystem == 1, this will directly subtract the new sprite's HP RAM instead of $1528.
		;This also applies to yoshi fireball (note that this can hit multiple times)
			!Setting_SpriteHP_FireballDamageAmount			= 3
				;^Amount of damage sprites receives from fireball damage.
				; With !Setting_SpriteHP_Modify5FireballsSystem == 0
				; this cannot be over 255. However if
				; !Setting_SpriteHP_Modify5FireballsSystem == 1 and
				; !Setting_SpriteHP_TwoByte == 1, then 65535 is the limit instead.
			
		;Fixes and additions
			;Sound effects. Setting Sound numbers to $00 will not play any sound nor suppress any existing sound effect
			;on the channel.
				;When the fireball damages enemies with the "take 5 fireballs to kill" bit being set.
				;See: https://www.smwcentral.net/?p=viewthread&t=6665
					!Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundNumber	= $28		;>Set to 0 to disable.
					!Setting_SpriteHP_VanillaSprite_5FireballsToKill_SoundPort	= $1DFC|!addr
				;Same but when shooting fireballs to Ludwig, Morton, and Roy.
					!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_Damage_SoundNumber	= $28
					!Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_Damage_SoundPort	= $1DFC|!addr
				;Sound effect when a thrown sprite hits Pokey (note that it does not count towards the consecutive
				;enemies hit by shell).
					!Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundNumber = $03 ;>Setting this to 0 will revert a hijack at $02B7DB
					!Setting_SpriteHP_VanillaSprite_Pokey_Damage_SoundPort = $1DF9|!addr
	;Size of the HP:
		;Size of the HP data:
		; - 0 = 8-bit HP (HP up to 255)
		; - 1 = 16-bit (HP up to 65535).
			!Setting_SpriteHP_TwoByte = 1
		;The maximum number of digits to be displayed. Obviously you
		;wouldn't set this above 3 for 8-bit HP and above 5 for 16-bit.
			!Setting_SpriteHP_MaxDigits	= 3
	;Misc settings
		!Setting_SpriteHP_DisplaySpriteHPDataOnConsole = 0
			;^Display RAM usage on Asar console window:
			; - 0 = No
			; - 1 = Yes, display the HP data RAM usage on asar console (would not work for pixi due to print command reserved for description).
		!Setting_SpriteHP_Koopas_ClassicBehavior = 0
			;^Koopas do what when stomped (this is because of a hijack at $01AA14):
			; - 0 = Come out of shells (vanilla).
			; - 1 = Stay in their shells (applies hex edits at $0196C6 and $01AA15).
		!Setting_SpriteHP_TotalHPMode = 1
			;^Apply a mode where the meter shows total HP across multiple sprites:
			; - 0 = No
			; - 1 = Yes


;Don't touch these unless you know what you're doing
	if !Setting_SpriteHP_DisplayGraphicalBar == 0	;>Override to disable unused animation for the bar if the bar doesn't exist.
		!Setting_SpriteHP_BarAnimation = 0
	endif
	!SpriteHP_MaxHPAndDamageValue = 255
	if !Setting_SpriteHP_TwoByte
		!SpriteHP_MaxHPAndDamageValue = 65535
	endif
	;Check if user enters over-limit values
		!SpriteHP_5FireballsMaxHPAndDamageValue = 255
		if and(notequal(!Setting_SpriteHP_Modify5FireballsSystem, 0), notequal(!Setting_SpriteHP_TwoByte, 0))
			!SpriteHP_5FireballsMaxHPAndDamageValue = 65535
		endif
		!SpriteHP_RexMaxHPAndDamageValue = 255
		if and(equal(!Setting_SpriteHP_VanillaSprite_Rex, 2), notequal(!Setting_SpriteHP_TwoByte, 0))
			!SpriteHP_RexMaxHPAndDamageValue = 65535
		endif
		
		assert !Setting_SpriteHP_VanillaSprite_Chucks_HPAmount <= !SpriteHP_5FireballsMaxHPAndDamageValue, "Chuck's HP is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_Chucks_StompDamage <= !SpriteHP_5FireballsMaxHPAndDamageValue, "Chuck's stomp damage is over the limit."
		assert !Setting_SpriteHP_FireballDamageAmount <= !SpriteHP_5FireballsMaxHPAndDamageValue, "Fireball damage is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_Rex_HPAmount <= !SpriteHP_RexMaxHPAndDamageValue, "Rex's HP is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_Rex_StompDamage <= !SpriteHP_RexMaxHPAndDamageValue, "Rex's stomp damage is over the limit."
		
		assert !Setting_SpriteHP_VanillaSprite_BigBooBoss_HPAmount <= 255, "Big Boo Boss HP over the limit."
		assert !Setting_SpriteHP_VanillaSprite_BigBooBoss_ThrownItemDamage <= 255, "Big Boo Boss thrown item damage is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_WendyLemmy_HPAmount <= 255, "Wendy and Lemmy HP is over the limit"
		assert !Setting_SpriteHP_VanillaSprite_WendyLemmy_StompDamage <= 255, "Wendy and Lemmy stomp damage is over the limit."
		
		assert !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_HPAmount <= 255, "Ludwig/Morton/Roy HP is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_StompDamage <= 255, "Ludwig/Morton/Roy stomp damage is over the limit."
		assert !Setting_SpriteHP_VanillaSprite_LudwigMortonRoy_FireballDamage <= 255, "Ludwig/Morton/Roy Fireball damage is over the limit."
		
	
	;Obtain addresses representing HP data
			!CurrentAddressToAssignDefine_SpriteHPData #= !Freeram_SpriteHP_SpriteHPData
			if not(defined("MacroGuard_SpriteHPData"))
				;This tells asar that setting these defines are done, since includeonce fails if two ASMs calls this same define file from different incsrc paths.
					!MacroGuard_SpriteHPData = 1
				;^Labels, structs, functions, and macros, they cannot be redefined. And includeonce fails if there are two involved
				; ASM files incsrcs with a different path to the same ASM file in which that file uses includeonce:
				; https://github.com/RPGHacker/asar/issues/287
				macro MacroAssignDefineOneAfterAnother(Define_Name, Size, Define_Name_Offseter)
					;This macro assigns Define_Name to an address, then offsets (Plus Size)
					;to the first byte after the last byte of Define_Name. This is useful
					;for having multiple defines at contiguous regions by repeatedly calling
					;this macro with different Define_Name.
					!{<Define_Name>} #= !{<Define_Name_Offseter>}
					!{<Define_Name_Offseter>} #= <Size>+!<Define_Name_Offseter>
				endmacro
			endif
			;Pixi does not have "!sprite_slots" but have "!SprSize" ("asm/sa1def.asm") instead at the time of making this.
				if not(defined("sprite_slots"))
					if !sa1 == 0
						!sprite_slots = 12
					else
						!sprite_slots = 22
					endif
				endif
			
			;The following also needs to have each of them be calling macros once, else they end up being set again to another,
			;different RAM address.
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MeterState, 1, CurrentAddressToAssignDefine_SpriteHPData)
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_CurrentHPLow, !sprite_slots, CurrentAddressToAssignDefine_SpriteHPData)
				%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MaxHPLow, !sprite_slots, CurrentAddressToAssignDefine_SpriteHPData)
				if !Setting_SpriteHP_TwoByte
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_CurrentHPHi, !sprite_slots, CurrentAddressToAssignDefine_SpriteHPData)
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_MaxHPHi, !sprite_slots, CurrentAddressToAssignDefine_SpriteHPData)
				endif
				if !Setting_SpriteHP_BarAnimation
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_BarAnimationFill, 1, CurrentAddressToAssignDefine_SpriteHPData)
					if !Setting_SpriteHP_BarChangeDelay
						%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_BarAnimationTimer, 1, CurrentAddressToAssignDefine_SpriteHPData)
					endif
				endif
				if !Setting_SpriteHP_TotalHPMode
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_TotalHPOfUnloadedSprites, 1+!Setting_SpriteHP_TwoByte, CurrentAddressToAssignDefine_SpriteHPData)
					%MacroAssignDefineOneAfterAnother(Freeram_SpriteHP_TotalMaxHP, 1+!Setting_SpriteHP_TwoByte, CurrentAddressToAssignDefine_SpriteHPData)
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
	;Other
		;To display HP of sprites, a modification is required:
		; - It requires fireball + stomp jank fix.
		; - It needs to take a hit/damage counter and "invert" (via HP = DamageToKill-DamageSoFar) to get HP value.
		; - It requires making sure the moment the player deals stomp damage to bosses, to have the damage apply on that
		;   frame rather than a "delay" that is until the boss switches to the next state after "damage" state.
		!Setting_ModifySprAndDisplayHPOfSMWSpr = and(!Setting_SpriteHP_RemoveOrApplyPatch, !Setting_SpriteHP_DisplayHPOfSMWSprites)
	;Debug display
		if !Setting_SpriteHP_DisplaySpriteHPDataOnConsole
			print "---------------------------------------------------------------------------------"
			print "\!Freeram_SpriteHP_SpriteHPData's Total bytes used: ", dec(!CurrentAddressToAssignDefine_SpriteHPData-!Freeram_SpriteHP_SpriteHPData)
			print "Range: $", hex(!Freeram_SpriteHP_SpriteHPData), "~$", hex(!CurrentAddressToAssignDefine_SpriteHPData-1)
			print "---------------------------------------------------------------------------------"
			print "\!Freeram_SpriteHP_SpriteHPData (Address Tracker format)"
			print "---------------------------------------------------------------------------------"
			print "$", hex(!Freeram_SpriteHP_MeterState), " 1 HP Meter state (\!Freeram_SpriteHP_MeterState)."
			print "$", hex(!Freeram_SpriteHP_CurrentHPLow), " ", dec(!sprite_slots), " Sprite current HP, low byte (\!Freeram_SpriteHP_CurrentHPLow)."
			print "$", hex(!Freeram_SpriteHP_MaxHPLow), " ", dec(!sprite_slots), " Sprite max HP, low byte (\!Freeram_SpriteHP_MaxHPLow)."
			if !Setting_SpriteHP_TwoByte
				print "$", hex(!Freeram_SpriteHP_CurrentHPHi), " ", dec(!sprite_slots), " Sprite current HP, high byte (\!Freeram_SpriteHP_CurrentHPHi)."
				print "$", hex(!Freeram_SpriteHP_MaxHPHi), " ", dec(!sprite_slots), " Sprite max HP, high byte (\!Freeram_SpriteHP_MaxHPHi)."
			endif
			if !Setting_SpriteHP_BarAnimation
				print "$", hex(!Freeram_SpriteHP_BarAnimationFill), " 1 Sprite graphical bar fill amount for animation (\!Freeram_SpriteHP_BarAnimationFill)."
				if !Setting_SpriteHP_BarChangeDelay
					print "$", hex(!Freeram_SpriteHP_BarAnimationTimer), " 1 Sprite graphical bar fill delay timer (\!Freeram_SpriteHP_BarAnimationTimer)."
				endif
			endif
			if !Setting_SpriteHP_TotalHPMode
				print "$" hex(!Freeram_SpriteHP_TotalHPOfUnloadedSprites), dec(!sprite_slots), " Total HP of sprites that are unloaded (\!Freeram_SpriteHP_TotalHPOfUnloadedSprites)."
				print "$" hex(!Freeram_SpriteHP_TotalMaxHP), dec(!sprite_slots), " Total max HP of sprites (\!Freeram_SpriteHP_TotalMaxHP)."
			endif
			print "---------------------------------------------------------------------------------"
		endif
	
	!Setting_SpriteHP_TrueMaximumHPAndDamageValue = min((10**!Setting_SpriteHP_MaxDigits)-1, (2**(8*(1+!Setting_SpriteHP_TwoByte)))-1)
	