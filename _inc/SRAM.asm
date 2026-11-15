; ===========================================================================
; ---------------------------------------------------------------------------
; SRAM save system (progress: next level, emeralds, score, speed level, XP threshold)
; Based on Plutiedev's SRAM guide. Every access is bracketed by the SRAM lock
; register, and only odd cartridge addresses are used.
;
; Current save block (26 logical bytes):
;   0-3    magic "S1SR"
;   4      format version (6)
;   5      zone (v_zone)
;   6      act (v_act)
;   7      number of emeralds (v_emeralds)
;   8-13   emerald list (v_emldlist, 6 bytes)
;   14-17  score (v_score, 4 bytes)
;   18     speed level (v_lives)
;   19     continues (v_continues; added in version 6)
;   20-23  next speed-level threshold (v_scorelife, 4 bytes)
;   24-25  checksum: sum of bytes 0-23, big-endian word
;
; Versions 3 (22 bytes), 4 and 5 are still accepted. Version 3 has no XP
; field; version 4 uses the old 1,000-point threshold scale; version 5 stores
; the 10,000-point threshold but had a reserved byte at offset 19. Older
; versions load with zero continues; the next save upgrades them to v6.

; Temporary buffers reserve SRAM_Size+2 bytes to keep SP word-aligned.
SRAM_Size:          equ 26
SRAM_ChkSize:       equ 24
SRAM_OldChkSize:    equ 20
SRAM_Version:       equ 6
SRAM_PrevVersion:   equ 5
SRAM_LegacyVersion: equ 4
SRAM_OldVersion:    equ 3
SramData:           equ $200003
SramTest:           equ SramData+2*127
sram_blank:         equ 0
sram_valid:         equ 1
sram_invalid:       equ 2

; ---------------------------------------------------------------------------
; Subroutine: read the save block from SRAM (SRAM must be unlocked)
; input: a1 = buffer (SRAM_Size bytes)
; ---------------------------------------------------------------------------

SRAM_ReadBlock:
		lea	(SramData).l,a0
		moveq	#SRAM_Size-1,d1
.loop:
		move.b	(a0),(a1)+
		addq.l	#2,a0
		dbf	d1,.loop
		rts
; End of function SRAM_ReadBlock

; ---------------------------------------------------------------------------
; Subroutine: write a buffer to the save block in SRAM (SRAM must be unlocked)
; input: a0 = buffer (SRAM_Size bytes)
; ---------------------------------------------------------------------------

SRAM_WriteBlock:
		lea	(SramData).l,a1
		moveq	#SRAM_Size-1,d1
.loop:
		move.b	(a0)+,(a1)
		addq.l	#2,a1
		dbf	d1,.loop
		rts
; End of function SRAM_WriteBlock

; ---------------------------------------------------------------------------
; Subroutine: sum d1+1 bytes of a buffer
; input: a0 = buffer, d1 = byte count minus one; output: d0.w = sum
; ---------------------------------------------------------------------------

SRAM_Sum:
		moveq	#0,d0
.loop:
		moveq	#0,d2
		move.b	(a0)+,d2
		add.w	d2,d0
		dbf	d1,.loop
		rts
; End of function SRAM_Sum

; ---------------------------------------------------------------------------
; Subroutine: read the save and set v_sram_state
; (sram_blank = nothing usable saved, sram_valid = good, sram_invalid = corrupted
;  or SRAM not working)
; ---------------------------------------------------------------------------

SRAM_CheckState:
		if EnableSRAM=0
		move.b	#sram_blank,(v_sram_state).w	; no SRAM in this build: no save, no warning
		rts
		endif
		movem.l	d0-d4/a0-a2,-(sp)		; keep the caller's registers (the object's a0 must survive)

		; --- SRAM test (guide: write, read back, lock again)
		gotoSRAM
		move.b	#$A5,(SramTest).l
		move.b	(SramTest).l,d2
		gotoROM
		cmpi.b	#$A5,d2
		bne.w	SRAM_NoSRAM			; readback differs: SRAM is not working

		lea	-(SRAM_Size+2)(sp),sp		; reserve a buffer on the stack
		movea.l	sp,a1
		gotoSRAM
		bsr.w	SRAM_ReadBlock			; read the save block into it
		gotoROM
		movea.l	sp,a0
		moveq	#0,d3				; d3 = 1 if any byte holds data
		moveq	#SRAM_Size-1,d1
.blank:
		move.b	(a0)+,d2
		cmpi.b	#$FF,d2				; erased byte?
		beq.s	.blankok
		tst.b	d2				; zero byte?
		beq.s	.blankok
		moveq	#1,d3				; this byte is real data
.blankok:
		dbf	d1,.blank
		tst.b	d3
		bne.s	.notblank
		move.b	#sram_blank,(v_sram_state).w	; garbage-free and empty: first run
		bra.w	.done

.notblank:
		movea.l	sp,a0
		cmpi.b	#'S',(a0)+
		bne.s	.nosave				; not our data (garbage or another game)
		cmpi.b	#'1',(a0)+
		bne.s	.nosave
		cmpi.b	#'S',(a0)+
		bne.s	.nosave
		cmpi.b	#'R',(a0)+
		bne.s	.nosave
		move.b	4(sp),d2				; format version
		cmpi.b	#SRAM_Version,d2
		beq.s	.checknew
		cmpi.b	#SRAM_PrevVersion,d2
		beq.s	.checknew				; version 5 has the same 26-byte layout/checksum
		cmpi.b	#SRAM_LegacyVersion,d2
		beq.s	.checknew				; version 4 also has the 26-byte layout/checksum
		cmpi.b	#SRAM_OldVersion,d2
		bne.s	.nosave				; unsupported/older save format
		movea.l	sp,a0
		moveq	#SRAM_OldChkSize-1,d1
		bsr.w	SRAM_Sum				; validate version-3 checksum
		movea.l	sp,a0
		moveq	#0,d2
		move.b	SRAM_OldChkSize(a0),d2		; old checksum, high byte
		lsl.w	#8,d2
		move.b	SRAM_OldChkSize+1(a0),d2		; old checksum, low byte
		cmp.w	d2,d0
		bne.s	.bad
		bra.s	.valid
.checknew:
		movea.l	sp,a0
		moveq	#SRAM_ChkSize-1,d1
		bsr.w	SRAM_Sum				; validate current checksum (bytes 0-23)
		movea.l	sp,a0
		moveq	#0,d2
		move.b	SRAM_ChkSize(a0),d2		; current checksum, high byte
		lsl.w	#8,d2
		move.b	SRAM_ChkSize+1(a0),d2		; current checksum, low byte
		cmp.w	d2,d0
		bne.s	.bad				; magic is ours but the data is damaged
.valid:
		move.b	#sram_valid,(v_sram_state).w
		bra.s	.done
.nosave:
		move.b	#sram_blank,(v_sram_state).w
		bra.s	.done
.bad:
		move.b	#sram_invalid,(v_sram_state).w
.done:
		lea	SRAM_Size+2(sp),sp
		movem.l	(sp)+,d0-d4/a0-a2
		rts
; End of function SRAM_CheckState

; ---------------------------------------------------------------------------
; Subroutine: save progress (act completion and Continue consumption)
; Saves the next level, emeralds, score, speed level and remaining continues.
; ---------------------------------------------------------------------------

SRAM_SaveProgress:
		if EnableSRAM=0
		rts
		endif
		movem.l	d0-d4/a0-a2,-(sp)		; keep the caller's registers
		lea	-(SRAM_Size+2)(sp),sp
		movea.l	sp,a1
		move.b	#'S',(a1)+
		move.b	#'1',(a1)+
		move.b	#'S',(a1)+
		move.b	#'R',(a1)+
		move.b	#SRAM_Version,(a1)+		; format version
		move.b	(v_zone).w,(a1)+		; next level: zone...
		move.b	(v_act).w,(a1)+			; ...and act
		move.b	(v_emeralds).w,(a1)+		; emerald count
		lea	(v_emldlist).w,a0
		moveq	#6-1,d1
.emld:
		move.b	(a0)+,(a1)+			; emerald list
		dbf	d1,.emld
		lea	(v_score).w,a0
		moveq	#4-1,d1
.score:
		move.b	(a0)+,(a1)+			; score (4 bytes)
		dbf	d1,.score
		move.b	(v_lives).w,(a1)+		; speed level
		move.b	(v_continues).w,(a1)+		; remaining continues
		move.l	(v_scorelife).w,(a1)+		; next speed-level threshold / XP progress
		movea.l	sp,a0
		moveq	#SRAM_ChkSize-1,d1
		bsr.w	SRAM_Sum				; d0 = checksum of bytes 0-23
		move.w	d0,d1
		lsr.w	#8,d0
		move.b	d0,(a1)+			; checksum, high byte
		move.b	d1,(a1)+			; checksum, low byte
		movea.l	sp,a0
		gotoSRAM				; unlock
		bsr.w	SRAM_WriteBlock
		gotoROM					; lock again
		move.b	#sram_valid,(v_sram_state).w
		lea	SRAM_Size+2(sp),sp
		movem.l	(sp)+,d0-d4/a0-a2
		rts
; End of function SRAM_SaveProgress

; ---------------------------------------------------------------------------
; Subroutine: load the saved level, score, emeralds, speed level and continues
; ---------------------------------------------------------------------------

SRAM_LoadProgress:
		if EnableSRAM=0
		rts
		endif
		movem.l	d0-d4/a0-a2,-(sp)		; keep the caller's registers
		lea	-(SRAM_Size+2)(sp),sp
		movea.l	sp,a1
		gotoSRAM
		bsr.w	SRAM_ReadBlock
		gotoROM
		move.b	5(sp),(v_zone).w		; saved zone
		move.b	6(sp),(v_act).w			; saved act
		move.w	(v_zone_act).w,d0
		cmpi.w	#id_FZ,d0			; is it a level that exists?
		bls.s	.levelok
		clr.w	(v_zone_act).w			; no: start from GHZ1
.levelok:
		move.b	7(sp),(v_emeralds).w
		lea	8(sp),a0
		lea	(v_emldlist).w,a1
		moveq	#6-1,d1
.emld:
		move.b	(a0)+,(a1)+
		dbf	d1,.emld
		lea	14(sp),a0
		lea	(v_score).w,a1
		moveq	#4-1,d1
.score:
		move.b	(a0)+,(a1)+
		dbf	d1,.score
		move.b	18(sp),(v_lives).w		; speed level
		; Continue count was added in v6. Older saves used this byte as reserved.
		clr.b	(v_continues).w
		cmpi.b	#SRAM_Version,4(sp)
		bne.s	.noContinues
		move.b	19(sp),(v_continues).w
.noContinues:
		; Clamp damaged/out-of-range level values before applying movement stats.
		moveq	#0,d0
		move.b	(v_lives).w,d0
		cmpi.w	#1,d0
		bhs.s	.levelminok
		moveq	#1,d0
		move.b	d0,(v_lives).w
.levelminok:
		cmpi.w	#99,d0
		bls.s	.levelmaxok
		moveq	#99,d0
		move.b	d0,(v_lives).w
.levelmaxok:
		cmpi.b	#SRAM_Version,4(sp)
		beq.s	.restorexp
		cmpi.b	#SRAM_PrevVersion,4(sp)
		beq.s	.restorexp				; v5 already stores the 10,000-point threshold
		; Versions 3/4 used the old 1,000-point progression scale (v3 did not
		; store XP). Preserve saved level/score and rebase to the next 10,000-point
		; boundary. v5/v6 store the correct threshold directly.
		move.l	(v_score).w,d0			; score units (10 points each)
		divu.w	#1000,d0				; divide by 1,000 units = 10,000 points
		andi.l	#$FFFF,d0				; keep quotient
		addq.l	#1,d0				; use the NEXT boundary, not the current one
		mulu.w	#1000,d0
		move.l	d0,(v_scorelife).w
		bra.s	.xpready
.restorexp:
		move.l	20(sp),(v_scorelife).w		; restore exact 10,000-point XP threshold/progress
.xpready:
		lea	SRAM_Size+2(sp),sp
		movem.l	(sp)+,d0-d4/a0-a2
		rts
; End of function SRAM_LoadProgress

; ---------------------------------------------------------------------------
; Clear the active save slot only (used by NEW GAME).
; This invalidates the previous continue data without erasing other SRAM data.
; ---------------------------------------------------------------------------

SRAM_ClearSaveBlock:
		if EnableSRAM=0
		rts
		endif
		movem.l	d0-d1/a0,-(sp)
		gotoSRAM
		lea	(SramData).l,a0
		moveq	#0,d0
		moveq	#SRAM_Size-1,d1
.loop:
		move.b	d0,(a0)
		addq.l	#2,a0
		dbf	d1,.loop
		gotoROM
		movem.l	(sp)+,d0-d1/a0
		rts
; End of function SRAM_ClearSaveBlock

; ---------------------------------------------------------------------------
; Clear all usable SRAM bytes (A+B+C on the Sega screen).
; Skip the first and last physical bytes as recommended by Plutiedev.
; The cartridge maps SRAM on odd addresses, so advance by two each byte.
; $200003-$20FFFD inclusive = 32,766 bytes.
; ---------------------------------------------------------------------------

SRAM_ClearAll:
		if EnableSRAM=0
		rts
		endif
		movem.l	d0-d1/a0,-(sp)
		gotoSRAM
		lea	($200003).l,a0
		moveq	#0,d0
		move.w	#$7FFD,d1
.loop:
		move.b	d0,(a0)
		addq.l	#2,a0
		dbf	d1,.loop
		gotoROM
		movem.l	(sp)+,d0-d1/a0
		rts
; End of function SRAM_ClearAll

; ---------------------------------------------------------------------------
; Title menu: NEW GAME (start at GHZ Act 1 while preserving saved speed level).
; The speed level is stored in v_lives. Load it from a valid save before
; PlayLevel resets the run-specific data. Do NOT clear the SRAM block here:
; selecting NEW GAME must not destroy the existing Continue save.
; ---------------------------------------------------------------------------

Tit_NewGame:
		cmpi.b	#sram_valid,(v_sram_state).w	; is there a valid saved progression?
		bne.s	.freshstart				; if not, start at speed level 1
		jsr	(SRAM_LoadProgress).l		; restore saved speed level (v_lives)
		bra.s	.start
.freshstart:
		move.b	#1,(v_lives).w			; default speed level for a new/invalid save
.start:
		move.w	#id_GHZ_act1,(v_zone_act).w	; NEW GAME always starts at GHZ Act 1
		jmp	(PlayLevel).l			; clear run stats but keep the loaded speed level
; End of function Tit_NewGame

; ---------------------------------------------------------------------------
; Title menu: CONTINUE (resumes the saved level, score, speed level and
; remaining continues; new game if there is no valid save)
; ---------------------------------------------------------------------------

Tit_Continue:
		cmpi.b	#sram_valid,(v_sram_state).w	; is there a good save?
		beq.s	.load				; if yes, load it
		jmp	(PlayLevel).l			; if not, start from the beginning
.load:
		movem.l	d7,-(sp)
		move.b	(v_levsel_cheatflags).w,d7	; remember the pending title cheats
		jsr	(SRAM_LoadProgress).l		; set the saved level, emeralds, score...
		jsr	(PlayLevel).l			; PlayLevel resets the emeralds and continues...
		jsr	(SRAM_LoadProgress).l		; ...so load the save again...
		move.b	d7,(v_levsel_cheatflags).w	; ...and grant the title cheats again
		jsr	(LevSel_ApplySoundTestCheats).l
		movem.l	(sp)+,d7
		rts
; End of function Tit_Continue

; ---------------------------------------------------------------------------
; Title menu: the SRAM warning entry is read-only, it only returns to the menu
; ---------------------------------------------------------------------------

Tit_IgnoreSRAM:
		clr.b	(v_jpadpress1).w
		jmp	(Tit_MainLoop).l
; End of function Tit_IgnoreSRAM

; ---------------------------------------------------------------------------
; SRAM is not working: the title shows the warning and the progress is not used
; ---------------------------------------------------------------------------
SRAM_NoSRAM:
		move.b	#sram_invalid,(v_sram_state).w
		movem.l	(sp)+,d0-d4/a0-a2
		rts
; End of function SRAM_NoSRAM
