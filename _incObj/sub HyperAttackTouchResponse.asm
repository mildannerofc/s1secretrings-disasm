; ===========================================================================
; Hyper Sonic attack: destroy all visible, registered badniks and damage bosses.
; This intentionally does not bounce Sonic or process items/hurt/special objects.
; The queue stores a byte count (two bytes per registered object), followed by
; 16-bit object RAM addresses, as built by ExecuteObjects.
; ---------------------------------------------------------------------------
HyperAttackTouchResponse:
		movem.l	d0-d7/a0-a4,-(sp)
		lea	(v_registeredcollision).w,a4
		move.w	(a4)+,d6				; number of bytes used by the collision queue
		beq.w	HyperTouch_Exit

HyperTouch_Loop:
		move.w	(a4)+,d0				; next object's RAM address
		beq.s	HyperTouch_Next
		movea.w	d0,a1
		tst.b	obRender(a1)				; object must be visible/on-screen
		bpl.s	HyperTouch_Next
		moveq	#0,d0
		move.b	obColType(a1),d0			; get collision class
		beq.s	HyperTouch_Next			; no collision
		andi.b	#$C0,d0				; ignore items, hazards and special collision objects
		bne.s	HyperTouch_Next
		tst.b	obBossHits(a1)				; boss objects use this as their HP counter
		beq.s	HyperTouch_DestroyBadnik

		; Boss: register one hit without repelling or bouncing Hyper Sonic.
		move.b	#col_none,obColType(a1)
		subq.b	#1,obBossHits(a1)
		bne.s	HyperTouch_Next
		bset	#status_defeated_bit,obStatus(a1)
		bra.s	HyperTouch_Next

HyperTouch_DestroyBadnik:
		bset	#status_defeated_bit,obStatus(a1)
		moveq	#0,d0
		move.w	(v_itembonus).w,d0			; preserve Sonic 1's enemy combo scoring
		addq.w	#2,(v_itembonus).w
		cmpi.w	#6,d0
		blo.s	HyperTouch_GetPoints
		moveq	#6,d0
HyperTouch_GetPoints:
		move.w	d0,exitem_pointsframe(a1)
		lea	(React_PointsCombo).l,a2
		move.w	(a2,d0.w),d0
		cmpi.w	#16*2,(v_itembonus).w
		blo.s	HyperTouch_AddPoints
		move.w	#1000,d0				; 10000 points after the 16th enemy
		move.w	#10,exitem_pointsframe(a1)
HyperTouch_AddPoints:
		jsr	(AddPoints).l
		_move.b	#id_ExplosionItem,obID(a1)	; reuse Sonic 1's normal explosion/animal sequence
		move.b	#0,obRoutine(a1)

HyperTouch_Next:
		subq.w	#2,d6				; two bytes per object pointer
		bne.w	HyperTouch_Loop
HyperTouch_Exit:
		movem.l	(sp)+,d0-d7/a0-a4
		rts
; ===========================================================================
