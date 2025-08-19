includeonce ;>Needed because functions cannot be redefined (asar will error out)

;Note: This file must be included first so that subsequent incsrc to include other define files can recognize functions.

!UsingCustomStatusBar = 1 ;>Set to 0 if you are using vanilla status bar, 1 if using custom status bar patch
!StatusBar_UsingCustomProperties = 1 ;>Set this to 0 if you don't want to modify tile properties, otherwise set to 1
	;^Note that this will also impact routines also used for the overworld border and may have incorrect
	; YXPCCCTT (seemingly garbage tiles), such as the graphical bar.
!StatusbarFormat = $02
	;^Number of grouped bytes per 8x8 tile for the status bar (not the overworld border):
	; $01 = each 8x8 tile have two bytes each separated into "tile numbers" and "tile properties" group;
	;       Minimalist/SMB3 [TTTTTTTT, TTTTTTTT]...[YXPCCCTT, YXPCCCTT] or SMW's default ([TTTTTTTT] only).
	; $02 = each 8x8 tile byte have two bytes located next to each other;
	;       Super status bar/Overworld border plus [TTTTTTTT YXPCCCTT, TTTTTTTT YXPCCCTT]...
;Base address of the status bar
	if !sa1 == 0
		!StatusBarPatchAddr_Tile = $7FA000
	else
		!StatusBarPatchAddr_Tile = $404000
	endif
	if !sa1 == 0
		!StatusBarPatchAddr_Prop = $7FA001
	else
		!StatusBarPatchAddr_Prop = $404001
	endif
;Base address of the overworld border (assuming you are using OWB+ patch)
	if !sa1 == 0
		!OverworldBorderPatchAddr_Tile = $7FEC00
	else
		!OverworldBorderPatchAddr_Tile = $41EC00
	endif
	
	if !sa1 == 0
		!OverworldBorderPatchAddr_Prop = $7FEC01
	else
		!OverworldBorderPatchAddr_Prop = $41EC01
	endif

;Don't modify unless you know what you're doing
	if not(defined("FunctionGuard_StatusBarFunctionDefined"))
		;^This if statement prevents an issue where "includeonce" is "ignored" if two ASMs files
		; incsrcs to the same ASM file with a different path due to asar not being able to tell
		; if the incsrc'ed file is the same file: https://github.com/RPGHacker/asar/issues/287
		
		;Patched status bar. Feel free to use this.
			function PatchedStatusBarXYToAddress(x, y, StatusBarTileDataBaseAddr, format) = StatusBarTileDataBaseAddr+(x*format)+(y*32*format)
			;You don't have to do STA $7FA000+StatusBarXYToByteOffset(0, 0, $02) when you can do STA PatchedStatusBarXYToAddress(0, 0, $7FA000, $02)
		
		;Vanilla SMW status bar. Again, feel free to use this.
			function VanillaStatusBarXYToAddress(x,y, SMWStatusBar0EF9) = (select(equal(y,2), SMWStatusBar0EF9+(x-2), SMWStatusBar0EF9+$1C+(x-3)))
			
			if !sa1 == 0
				!RAM_0EF9 = $0EF9
			else
				!RAM_0EF9 = $400EF9
			endif
		;YXPCCCTT calculator
			function GetLayer3YXPCCCTT(Y,X,P,CCC,TT) = ((Y<<7)+(X<<6)+(P<<5)+(CCC<<2)+TT)
		!FunctionGuard_StatusBarFunctionDefined = 1
	endif