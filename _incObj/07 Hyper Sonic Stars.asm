; ===========================================================================
; ---------------------------------------------------------------------------
; Object 04 - Hyper Sonic stars. Ported from the Hyper Sonic 1.1.1v ROM.
; Init (routine 0): makes 4 child stars at angles $00,$40,$80,$C0, then deletes itself.
; Each child orbits Sonic: its angle advances $F0 per frame, the sine/cosine of the
; angle (x8) is accumulated into objoff_30/objoff_34, and the star is placed at Sonic's
; position plus the high byte of the accumulator (mirrored if Sonic faces left).
; The animation cycles mapping frames 0..2, and the accumulators restart each cycle.
; The stars exist only while Hyper Sonic is active (v_supersonic >= 2).
; ---------------------------------------------------------------------------

HyperStars:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	HyperStars_Index(pc,d0.w),d1
		jmp	HyperStars_Index(pc,d1.w)
; ===========================================================================
HyperStars_Index:
		dc.w	HyperStars_Init-HyperStars_Index
		dc.w	HyperStars_Timer-HyperStars_Index
		dc.w	HyperStars_Update-HyperStars_Index
		dc.w	HyperStars_Spark-HyperStars_Index
; ===========================================================================

HyperStars_Init:
		; FindFreeObj uses d0 as its scan counter. Keep the orbit angle in d3,
		; otherwise all four stars inherit the allocator's counter instead of
		; the intended $00/$40/$80/$C0 phase offsets.
		moveq	#3,d1					; create four orbiting stars
		moveq	#0,d3					; first star angle $00
		moveq	#1,d2					; stagger startup by 1..4 frames
.spawn:
		jsr	(FindFreeObj).l
		bne.s	.done
		move.b	#id_HyperStars,obID(a1)
		move.b	#2,obRoutine(a1)			; child begins in the startup timer
		move.b	d3,obAngle(a1)
		move.b	d2,obTimeFrame(a1)
		move.l	#Map_HyperStars,obMap(a1)
		move.w	#ArtTile_HyperStars,obGfx(a1)
		move.b	#sprite_cam_field,obRender(a1)
		move.b	#1,obPriority(a1)
		move.b	#48/2,obActWid(a1)
		clr.b	obColType(a1)				; stars are visual-only objects
		clr.b	obBossHits(a1)
		clr.b	obStatus(a1)
		clr.b	obFrame(a1)				; always begin on mapping frame 0
		clr.l	obX(a1)					; clear old integer/fractional coordinates
		clr.l	obY(a1)
		move.w	(v_player+obX).w,obX(a1)		; start at Sonic rather than an old object position
		move.w	(v_player+obY).w,obY(a1)
		clr.w	objoff_30(a1)			; clear accumulated X offset in reused object RAM
		clr.w	objoff_34(a1)			; clear accumulated Y offset in reused object RAM
		clr.w	obVelX(a1)				; clear stale movement data
		clr.w	obVelY(a1)
		addi.b	#$40,d3					; next star is 90 degrees apart
		addq.b	#1,d2
		dbf	d1,.spawn
.done:
		jmp	(DeleteObject).l			; the four child objects now own the visual effect
; ===========================================================================

HyperStars_Timer:
		subq.b	#1,obTimeFrame(a0)
		bne.s	.return
		move.b	#1,obTimeFrame(a0)			; 2-frame star animation cadence
		clr.b	obFrame(a0)
		clr.w	objoff_30(a0)
		clr.w	objoff_34(a0)
		move.b	#4,obRoutine(a0)			; now orbiting
		bra.w	HyperStars_Update			; begin orbit on this frame, as in S3K
.return:
		rts
; ===========================================================================

HyperStars_Update:
		cmpi.b	#2,(v_supersonic).w			; Hyper Sonic still active?
		bhs.s	.active
		jmp	(DeleteObject).l
.active:
		subq.b	#1,obTimeFrame(a0)			; animate mappings 0..2
		bpl.s	.noframe
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		cmpi.b	#3,obFrame(a0)
		bcs.s	.noframe
		clr.b	obFrame(a0)				; restart orbit at the first frame
		clr.w	objoff_30(a0)
		clr.w	objoff_34(a0)
.noframe:
		move.b	obAngle(a0),d0				; orbit: angle advances -$10 per frame
		addi.b	#$F0,obAngle(a0)
		jsr	(CalcSine).l				; d0 = sine, d1 = cosine
		asl.w	#3,d0
		asl.w	#3,d1
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		add.w	d0,objoff_30(a0)
		add.w	d1,objoff_34(a0)
		move.b	objoff_30(a0),d2			; high byte of accumulator = X offset
		ext.w	d2
		btst	#0,(v_player+obStatus).w		; mirror X when Sonic faces left
		beq.s	.noflip
		neg.w	d2
.noflip:
		move.b	objoff_34(a0),d3
		ext.w	d3
		add.w	(v_player+obX).w,d2
		add.w	(v_player+obY).w,d3
		move.w	d2,obX(a0)
		move.w	d3,obY(a0)
		andi.w	#$7FFF,obGfx(a0)
		tst.b	(v_player+obGfx).w			; follow Sonic's sprite priority
		bpl.s	.nopri
		ori.w	#$8000,obGfx(a0)
.nopri:
		jmp	(DisplaySprite).l
; ===========================================================================

; Hyper Dash sparks. Use only the first two Hyper-star mapping frames, matching
; the compact two-frame sparkle used by the Sonic 3 Hyper Dash effect. Four copies
; travel outward on diagonal velocities; the oversized expansion frames are unused.
HyperStars_CreateSparks:
		movem.l	d0-d3/d7/a2,-(sp)
		lea	HyperStars_SparkVelocities(pc),a2
		moveq	#4-1,d7
.spawn:
		jsr	(FindFreeObj).l
		bne.s	.done
		move.b	#id_HyperStars,obID(a1)
		move.b	#6,obRoutine(a1)			; spark routine
		move.l	#Map_HyperStars,obMap(a1)
		move.w	#ArtTile_HyperStars,obGfx(a1)
		move.b	#sprite_cam_field,obRender(a1)
		move.b	#1,obPriority(a1)
		move.b	#48/2,obActWid(a1)
		clr.b	obStatus(a1)
		clr.b	obBossHits(a1)
		clr.l	obX(a1)					; clear fractional position from a reused object slot
		clr.l	obY(a1)
		move.w	(v_player+obX).w,obX(a1)
		move.w	(v_player+obY).w,obY(a1)
		move.w	(a2)+,obVelX(a1)
		move.w	(a2)+,obVelY(a1)
		clr.b	obFrame(a1)				; begin on the first small sparkle frame
		move.b	#1,obTimeFrame(a1)			; alternate the first two frames
		move.w	#12,objoff_30(a1)			; short outward burst lifetime
		clr.b	obColType(a1)				; spark object has no collision
		dbf	d7,.spawn
.done:
		movem.l	(sp)+,d0-d3/d7/a2
		rts
; ---------------------------------------------------------------------------

HyperStars_Spark:
		cmpi.b	#2,(v_supersonic).w			; discard sparks after Hyper ends
		bhs.s	.active
		jmp	(DeleteObject).l
.active:
		jsr	(SpeedToPos).l				; move outward from Sonic
		subq.w	#1,objoff_30(a0)			; count down the short burst
		bmi.s	.delete
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.display
		move.b	#1,obTimeFrame(a0)
		eori.b	#1,obFrame(a0)				; alternate mapping frames 0 and 1 only
.display:
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

HyperStars_SparkVelocities:
		dc.w	-$200,-$200
		dc.w	 $200,-$200
		dc.w	-$200, $200
		dc.w	 $200, $200

; ===========================================================================

