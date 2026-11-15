; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to add points to the score counter.
; 
; Input:
;	d0 = points to add / 10 (rightmost digit in HUD is a fake 0)
; ---------------------------------------------------------------------------
; - In REV00, a copy of the score is kept in a separate RAM value.
; - In this hack's REV01 path, the score threshold drives speed-level
;   progression: every 10,000 points grants one level, up to level 99.
; ---------------------------------------------------------------------------

AddPoints:
		move.b	#1,(f_scorecount).w			; set score counter to update

	if Revision=0
		lea	(v_scorecopy).w,a2			; load copy of score count (unused, REV00 only)
		lea	(v_score).w,a3				; load current score count
		add.l	d0,(a3)					; add d0*10 to the score
		move.l	#999999,d1				; set maximum score count to 9999990
		cmp.l	(a3),d1					; has score exceeded the maximum?
		bhi.w	.belowmax				; if not, branch
		move.l	d1,(a3)					; cap score to 9999990
		move.l	d1,(a2)					; cap unused score copy

.belowmax:
		move.l	(a3),d0					; get new score count
		cmp.l	(a2),d0					; is it lower than the copy?
		blo.w	.return					; if yes, branch
		move.l	d0,(a2)					; update copy

	else

		lea	(v_score).w,a3				; load current score count
		add.l	d0,(a3)					; add d0*10 to the score
		move.l	#999999,d1				; set maximum score count to 9999990
		cmp.l	(a3),d1					; has score exceeded the maximum?
		bhi.s	.belowmax				; if not, branch
		move.l	d1,(a3)					; cap score to 9999990

.belowmax:
		move.l	(a3),d0					; get new score count (units of 10)
		cmp.l	(v_scorelife).w,d0			; reached the next 10,000-point milestone?
		blo.s	.return					; not yet

.levelup:
		cmpi.b	#99,(v_lives).w			; already at the S2SR level cap?
		bhs.s	.return					; no further level-ups
		addi.l	#1000,(v_scorelife).w			; next milestone (+10,000 points)
		addq.b	#1,(v_lives).w			; speed level +1
		cmpi.b	#99,(v_lives).w			; did this award reach level 99?
		bhs.s	.applylevel				; apply the final level's stats
		cmp.l	(v_scorelife).w,d0			; did a large tally cross another milestone?
		bhs.s	.levelup					; award each level already earned
.applylevel:
		jsr	(Sonic_ApplyLevelStats).l		; apply new top speed, acceleration and braking
		addq.b	#1,(f_lifecount).w			; refresh the level/life counter display
		move.w	#bgm_ExtraLife,d0			; level-up jingle
		jmp	(QueueSound1).l				; play it
	endif

.return:
		rts						; return
; End of function AddPoints
; ===========================================================================