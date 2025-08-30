?SpawnSmokeByExtSpr:
;This spawns a 16x16 smoke on the position centered with the extended sprite is on.
;For example, the player's fireball would have the smoke's top-left corner (origin)
;be 4 pixels left and 4 pixels up from the top-left origin of the fireball.
;
;Input:
;X = extended sprite slot number
	LDY.b #$04-1

	?.Loop
		LDA $17C0|!Base2,y		;\Check if slot is currently
		BEQ ?..SlotFound
		JMP ?..NextSlot		;/reserved.

		?..SlotFound
		?..OffScreenCheck
			?...Horizontal
				LDA $1733|!Base2,x	;\extended sprite's X position in 16-bit...
				XBA			;|
				LDA $171F|!Base2,x	;/
				REP #$20		;
				PHA			;>Save X position
				SEP #$20		;
				LDA $170B|!Base2,x	;\Check what sprite for proper centering
				CMP #$05		;/
				BEQ ?....EightByEightSpr
				;CMP #$11
				;BEQ ?....SixteenBySixteenSpr

				?....SixteenBySixteenSpr
					REP #$20
					PLA			;>Get X position back
					SEC			;\Make it centered with fireball sprite
					SBC #$0004		;/
					BRA ?...XPosScrn		;>Don't PLA again (crashes due to push 1 byte, and pull 2 bytes; a mismatch).

				?....EightByEightSpr
					REP #$20
					PLA			;>Get X position back

			?...XPosScrn
				SEC			;\Now X position on-screen (distance between extsprite and left edge of screen,
				SBC $1462|!Base2	;/signed)
				CMP #$0100		;\If >= (unsigned) than #$0100 (the width of the screen)
				SEP #$20		;|
				BCS ?.Done		;/don't draw smoke

			?...Vertical
				LDA $1729|!Base2,x	;\extended sprite's Y position in 16-bit...
				XBA			;|
				LDA $1715|!Base2,x	;/
				REP #$20		;
				PHA			;>Save Y position
				SEP #$20		;
				LDA $170B|!Base2,x	;\Check what sprite for proper centering
				CMP #$05		;/
				BEQ ?....EightByEightSpr
				;CMP #$11
				;BEQ ?....SixteenBySixteenSpr

				?....SixteenBySixteenSpr
					REP #$20
					PLA			;>Get X position back
					SEC			;\Make it centered with fireball sprite
					SBC #$0004		;/
					BRA ?...YPosScrn		;>Don't PLA again (crashes due to push 1 byte, and pull 2 bytes; a mismatch).

				?....EightByEightSpr
					REP #$20
					PLA

			?...YPosScrn
				SEC			;\...Now Y position on-screen
				SBC $1464|!Base2	;/
				CMP #$0100		;\If >= (unsigned) than #$0100 (the height of the screen
				SEP #$20		;|with 2 blocks added below)...
				BCS ?.Done		;/Don't draw smoke

				LDA #$01		;\Set smoke sprite number
				STA $17C0|!Base2,y	;/
				LDA #$1B		;\Set smoke existence timer
				STA $17CC|!Base2,y	;/

		?..SetPos
			LDA $170B|!Base2,x		;\Check what sprite for proper centering
			CMP #$05			;/
			BEQ ?...EightByEightSpr
			;CMP #$11
			;BEQ ?...SixteenBySixteenSpr

			?...EightByEightSpr
				LDA $171F|!Base2,x	;\Set X position
				SEC			;|
				SBC #$04		;|
				STA $17C8|!Base2,y	;/
				LDA $1715|!Base2,x	;\Set Y position
				SEC			;|
				SBC #$04		;|
				STA $17C4|!Base2,y	;/
				;BRA ?.Done
				RTL

			?...SixteenBySixteenSpr
				LDA $171F|!Base2,x	;\Set X position
				STA $17C8|!Base2,y	;/
				LDA $1715|!Base2,x	;\Set Y position
				STA $17C4|!Base2,y	;/
				;BRA ?.Done		;>Don't write to all other slots for a single extsprite.
				RTL

		?..NextSlot
			DEY
			BMI ?.Done
			JMP ?.Loop

	?.Done
	RTL