; ---------------------------------------------------------------------------
; Object 02 - Lag-o-Meter (inspired by Hivebrain's S1Squared implementation)
; ---------------------------------------------------------------------------

LagOMeter_Object:
	if LagOMeter=0
		; make sure they only get displayed when the flag is on
		jmp	(DeleteObject).l
	endif

		tst.b	obRoutine(a0)
		bne.s	LagOMeter_Display
		addq.b	#2,obRoutine(a0)
		move.w	#$80+320,obX(a0)
		move.w	#$80,obScreenY(a0)
		move.l	#Map_Ring,obMap(a0)
		move.b	#3,obFrame(a0)

		move.w	#make_art_tile(ArtTile_Ring,1,1),obGfx(a0) ; yellow
		cmpi.l	#v_lagometer_red,a0
		bne.s	LagOMeter_Display
		move.w	#make_art_tile(ArtTile_Ring,0,1),obGfx(a0) ; red

LagOMeter_Display:
		moveq	#0,d0
		move.b	objoff_30(a0),d0
		addi.w	#$80,d0
		move.w	d0,obScreenY(a0)
		jmp	(DisplaySprite).l