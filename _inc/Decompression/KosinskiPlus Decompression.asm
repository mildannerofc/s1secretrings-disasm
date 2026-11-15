; ---------------------------------------------------------------------------
; Kosinski Plus decompressor.
; Based on the permissively licensed implementation by Flamewing,
; vladikcomper and Clownacy, as used by Sonic1UnGit.
; ---------------------------------------------------------------------------
_KosPlus_LoopUnroll = 3

_KosPlus_ReadBit macro
	dbra	d2,.skip
	moveq	#7,d2
	move.b	(a0)+,d0
.skip:
	add.b	d0,d0
	endm

KosPlusDec:
	if _KosPlus_LoopUnroll>0
		moveq	#(1<<_KosPlus_LoopUnroll)-1,d7
	endif
	moveq	#0,d2
	bra.s	.FetchNewCode
.FetchCodeLoop:
		move.b	(a0)+,(a1)+
.FetchNewCode:
	_KosPlus_ReadBit
		bcs.s	.FetchCodeLoop
		moveq	#-1,d5
		lea	(a1),a5
	_KosPlus_ReadBit
		bcs.s	.Code_01
		move.b	(a0)+,d5
		adda.w	d5,a5
		move.b	(a5)+,(a1)+
		move.b	(a5)+,(a1)+
	_KosPlus_ReadBit
		bcc.s	.Copy_01
		move.b	(a5)+,(a1)+
		move.b	(a5)+,(a1)+
.Copy_01:
	_KosPlus_ReadBit
		bcc.s	.FetchNewCode
		move.b	(a5)+,(a1)+
		bra.s	.FetchNewCode
.Code_01:
		moveq	#0,d4
		move.b	(a0)+,d4
		move.b	d4,d5
		lsl.w	#5,d5
		move.b	(a0)+,d5
	if _KosPlus_LoopUnroll=3
		and.w	d7,d4
	else
		andi.w	#7,d4
	endif
	if _KosPlus_LoopUnroll>0
		bne.s	.StreamCopy
		move.b	(a0)+,d4
		beq.s	.Quit
		adda.w	d5,a5
		move.w	d4,d6
		not.w	d6
		and.w	d7,d6
		add.w	d6,d6
		lsr.w	#_KosPlus_LoopUnroll,d4
		jmp	.largecopy(pc,d6.w)
	else
		beq.s	.dolargecopy
	endif
.StreamCopy:
		adda.w	d5,a5
		move.b	(a5)+,(a1)+
		add.w	d4,d4
		jmp	.mediumcopy-2(pc,d4.w)
	if _KosPlus_LoopUnroll=0
.dolargecopy:
		move.b	(a0)+,d4
		beq.s	.Quit
		adda.w	d5,a5
	endif
.largecopy:
		rept (1<<_KosPlus_LoopUnroll)
			move.b	(a5)+,(a1)+
		endr
		dbra	d4,.largecopy
.mediumcopy:
		rept 8
			move.b	(a5)+,(a1)+
		endr
		bra.w	.FetchNewCode
.Quit:
		rts
