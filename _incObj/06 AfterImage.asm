; ===========================================================================
; ---------------------------------------------------------------------------
; Object 07 - After Images (Hyper Sonic trail)
; Uses Sonic 1's native position-history buffer, as in the original AfterImage
; implementation. Hyper Sonic only; positions are sampled from v_tracksonic.
; ---------------------------------------------------------------------------

AfterImage:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	AfterImage_Index(pc,d0.w),d1
		jmp	AfterImage_Index(pc,d1.w)
; ===========================================================================
AfterImage_Index:
		dc.w	AfterImage_Init-AfterImage_Index
		dc.w	AfterImage_Main-AfterImage_Index
; ===========================================================================

AfterImage_Init:
		addq.b	#2,obRoutine(a0)			; advance to AfterImage_Main
		move.l	#Map_Sonic,obMap(a0)			; use Sonic's regular mappings
		move.w	#make_art_tile(ArtTile_Sonic,0,0),obGfx(a0) ; use the standard Sonic art tile
		move.b	#2,obPriority(a0)
		move.b	#$18,obWidth(a0)
		move.b	#$18,obHeight(a0)
		move.b	#sprite_cam_field,obRender(a0)
; ===========================================================================

AfterImage_Main:
		cmpi.b	#2,(v_supersonic).w			; is Hyper Sonic active?
		bne.w	DeleteObject				; remove trail outside Hyper form
		tst.w	(v_debuguse).w				; Debug Mode suppresses the trail
		bne.s	.return

		; Match the original Sonic 1 AfterImage tracker cadence exactly.
		; The history buffer stores one X/Y pair every 4 bytes. Alternate
		; between 3 and 5 recorded positions behind Sonic ($0C/$14).
		moveq	#$0C,d1
		btst	#0,(v_framecount+1).w			; every other frame uses the longer trail
		beq.s	.evenframe
		moveq	#$14,d1

.evenframe:
		move.w	(v_trackpos).w,d0
		lea	(v_tracksonic).w,a1
		sub.b	d1,d0					; wrap naturally in the 256-byte history buffer
		lea	(a1,d0.w),a1
		move.w	(a1)+,obX(a0)				; historical X position
		move.w	(a1)+,obY(a0)				; historical Y position

		; Keep the exact current Hyper Sonic animation/render state.
		move.b	(v_player+obFrame).w,obFrame(a0)
		move.b	(v_player+obRender).w,obRender(a0)
		move.b	(v_player+obPriority).w,obPriority(a0)
		bra.w	DisplaySprite
.return:
		rts
; ===========================================================================
