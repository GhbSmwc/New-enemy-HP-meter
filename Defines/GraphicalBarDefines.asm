;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This ASM file contains defines relating only to the subroutines.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SA-1 handling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Only include this if there is no SA-1 detection, such as including this
;in a (seperate) patch.
if defined("sa1") == 0
	!dp = $0000
	!addr = $0000
	!sa1 = 0
	!gsu = 0

	if read1($00FFD6) == $15
		sfxrom
		!dp = $6000
		!addr = !dp
		!gsu = 1
	elseif read1($00FFD5) == $23
		sa1rom
		!dp = $3000
		!addr = $6000
		!sa1 = 1
	endif
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Graphical bar defines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Ram stuff (note that ram banks $7E/$7F cannot be accessed when
	;sa-1 mode is running, so use banks $40/$41).
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;Bar attributes. These are RAM addresses that sets the number of pieces
		;and length of the middle. Not to be confused with default values
		;in StatusBarSettings where it mentions (excluding the outer brackets):
		;-[Tile settings (length does not apply to [ExtendLeftwards.asm] as that is variable in-game)]
		;Since that is the actual number of pieces, while this is the RAM address locations that stores
		;them in case if you have 2+ bars with different attributes.
			if !sa1 == 0
				!Scratchram_GraphicalBar_LeftEndPiece   = $60		;>normal ROM
			else
				!Scratchram_GraphicalBar_LeftEndPiece   = $60	;>SA-1 ROM
			endif
				;^[1 byte] number of pieces on the left end byte/8x8 tile.

			if !sa1 == 0
				!Scratchram_GraphicalBar_MiddlePiece    = $61
			else
				!Scratchram_GraphicalBar_MiddlePiece    = $61
			endif
				;^[1 byte] number of pieces on each middle byte/8x8 tile.

			if !sa1 == 0
				!Scratchram_GraphicalBar_RightEndPiece  = $62
			else
				!Scratchram_GraphicalBar_RightEndPiece  = $62
			endif
				;^[1 byte] number of pieces on the right end byte/8x8 tile.

			if !sa1 == 0
				!Scratchram_GraphicalBar_TempLength  = $7F8449
			else
				!Scratchram_GraphicalBar_TempLength  = $404140
			endif
				;^[1 byte] how many middle bytes/8x8 to be written on the bar. This is
				;basically the length of the bar.
		;Fill byte table:
			if !sa1 == 0
				!Scratchram_GraphicalBar_FillByteTbl = $7F844A
			else
				!Scratchram_GraphicalBar_FillByteTbl = $404141
			endif
				;^[>= 4 bytes] Used to hold the fill amount for each
				; byte to be converted into tile numbers to be used for display.
				; The amount of bytes used is:
				;
				; BytesUsed = LeftExist + (MiddleExist*Length) + RightExist
				;
				; where any variable with "exist" in name is either 0
				; (pieces is 0) or 1 (pieces is nonzero).
				;
				; Also used for calculating the percentage:
				;  +$00 to +$01 = quantity
				;  +$02 to +$03 = max quantity
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Graphical bar Settings
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		!Setting_GraphicalBar_IndexSize = 0
			;^0 = 8-bit indexing for byte table, 1 = 16-bit. Only set this to 1
			; if you, somehow wanted to have a middle length of 255 middle bytes/8x8
			; (which is extremely unlikely), and have any bar ends enabled
			; (this would have the index value being at $0100 or $0101).
			;
			; each byte/tile consumes an index, so if this is 0, and you have both ends
			; enabled, your actual middle's maximum is 253 (because 253 middle bytes
			; plus 2 ends = 255 total bytes used up).
			;
			; Do note that most routines would assume there are no more than 255 tile bytes,
			; reasons being:
			; -The loops' end uses BPL, so it will end if the index value is #$80-#$FF.
			; -If you are using a 2 adjacent bytes per 8x8 tile (!StatusBarFormat = $02),
			;  the tile processing uses ASL (multiply index by 2) and therefore "overflow"
			;  should the number being multiplyed by 2 be >= #$80. Thus the limit, along
			;  above limitation, is 64 tile bytes (indexes $00 to $3F).
			;
			; But this is highly unlikely as the screen is 32 8x8 tiles wide.

		!Setting_GraphicalBar_SNESMathOnly = 0
			;^Info follows:
			;-Set this to 0 if your code calls the graphical bar routines under the SA-1 processor on SA-1
			; ROM. Otherwise set it to 1 if it only calls it under the SNES CPU.
			;
			; As an important note: certain emulators follows a rule that only the correct CPU can access
			; the registers of the matching type (e.g. SA-1 registers can only be used by SA-1 CPU, not SNES).
		!GraphicalBar_OAMSlot = 4
			;^Starting slot number to use (increments of 1) for checking, not to be confused with index (which increments by 4). Use only values 0-127 ($00-$7F).
;Print descriptions (if you have trouble tracking your RAM address)
	!Setting_GraphicalBar_Debug_DisplayRAMUsage = 0
		;^0 = no, 1 = display RAM usage on console window.
	
	;print onto console window
		if !Setting_GraphicalBar_Debug_DisplayRAMUsage != 0
			print ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;"
			print ";Graphical bar routine RAM usage"
			print ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;"
			print "-Left end piece: $", hex(!Scratchram_GraphicalBar_LeftEndPiece)
			print "-Middle piece: $", hex(!Scratchram_GraphicalBar_MiddlePiece)
			print "-Right end piece: $", hex(!Scratchram_GraphicalBar_RightEndPiece)
			print "-Middle length: $", hex(!Scratchram_GraphicalBar_TempLength)
			print "-Fill byte table: $", hex(!Scratchram_GraphicalBar_FillByteTbl), " to $", hex(!Scratchram_GraphicalBar_FillByteTbl+31), " (at max length)"
		endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Don't touch.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;Determine should registers be SNES (0) or SA-1 (1)
	!CPUMode = 0
	if (and(equal(!sa1, 1),equal(!Setting_GraphicalBar_SNESMathOnly, 0)))
		!CPUMode = 1
	endif