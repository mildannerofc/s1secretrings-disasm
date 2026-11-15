; ===========================================================================
; ---------------------------------------------------------------------------
; Object 01 - Sonic the Hedgehog
; ---------------------------------------------------------------------------
son_maxspeed:		equ	$600				; Sonic's max speed
son_acceleration:	equ	$C				; Sonic's acceleration
son_deceleration:	equ	$80				; Sonic's deceleration
son_jumpspeed:		equ	$680				; Sonic's jump speed
; ---------------------------------------------------------------------------


; ---------------------------------------------------------------------------
; Apply the persistent speed level to Sonic's movement parameters.
; Normal level 1 baseline: top speed $600, acceleration $0C, deceleration $80.
; Super level 1 baseline: top speed $A00, acceleration $30, deceleration $100.
; Each additional level adds $100 top speed and $01 to acceleration and
; deceleration for BOTH forms. The level is capped at 99 (S2SR's cap).
;
; Speed Shoes only affect normal Sonic. Super Sonic keeps his own level-scaled
; values; underwater, his top speed, acceleration and deceleration are halved.
; Preserves d0-d3 so it is safe to call from AddPoints and object routines.
; ---------------------------------------------------------------------------
Sonic_ApplyLevelStats:
		movem.l	d0-d3,-(sp)
		; Keep the ending sequence and the credits demos at Sonic's original
		; level-1 movement values, regardless of the persistent speed level.
		; Credits demos run as id_Demo with f_demo=$8001.
		cmpi.b	#id_Ending,(v_gamemode).w
		beq.w	.cutscenestats
		cmpi.b	#id_Credits,(v_gamemode).w
		beq.w	.cutscenestats
		cmpi.b	#id_Demo,(v_gamemode).w
		bne.s	.regularstats
		cmpi.w	#$8001,(f_demo).w
		beq.w	.cutscenestats

.regularstats:
		moveq	#0,d0
		move.b	(v_lives).w,d0			; v_lives stores the speed level
		cmpi.w	#1,d0
		bhs.s	.levelminok
		moveq	#1,d0				; minimum supported level
.levelminok:
		cmpi.w	#99,d0
		bls.s	.levelmaxok
		moveq	#99,d0				; maximum supported level
.levelmaxok:
		move.b	d0,(v_lives).w
		subi.w	#1,d0				; level bonus (level 1 = 0)

		tst.b	(v_supersonic).w			; use Super Sonic's own base stats?
		bne.s	.superstats
		move.w	d0,d1
		lsl.w	#8,d1
		addi.w	#son_maxspeed,d1			; normal: $600 + $100 per level
		move.w	d0,d2
		addi.w	#son_acceleration,d2		; normal: $0C + $01 per level
		move.w	d0,d3
		addi.w	#son_deceleration,d3		; normal: $80 + $01 per level

		tst.b	(v_shoes).w
		beq.s	.checkwater
		btst	#status_underwater_bit,(v_player+obStatus).w
		bne.s	.store				; Shoes underwater: use unhalved base stats
		add.w	d1,d1				; double top speed
		bpl.s	.shoespeedok
		move.w	#$7F00,d1			; prevent signed-word overflow at high levels
.shoespeedok:
		add.w	d2,d2				; double acceleration
		bra.s	.store
.checkwater:
		btst	#status_underwater_bit,(v_player+obStatus).w
		beq.s	.store
		lsr.w	#1,d1
		lsr.w	#1,d2
		lsr.w	#1,d3
		bra.s	.store
.superstats:
		move.w	d0,d1
		lsl.w	#8,d1
		addi.w	#$0A00,d1				; Super: $0A00 + $100 per level
		move.w	d0,d2
		addi.w	#$30,d2				; Super: $30 + $01 per level
		move.w	d0,d3
		addi.w	#$100,d3				; Super: $100 + $01 per level
		btst	#status_underwater_bit,(v_player+obStatus).w
		beq.s	.store
		lsr.w	#1,d1				; Super's underwater stats are halved
		lsr.w	#1,d2
		lsr.w	#1,d3
		bra.s	.store

.cutscenestats:
		; Exact original Normal Sonic stats: top speed $0600, acceleration $0C,
		; deceleration $80. This branch is limited to Ending/Credits modes.
		move.w	#son_maxspeed,d1
		move.w	#son_acceleration,d2
		move.w	#son_deceleration,d3
.store:
		move.w	d1,(v_sonspeedmax).w
		move.w	d2,(v_sonspeedacc).w
		move.w	d3,(v_sonspeeddec).w
		movem.l	(sp)+,d0-d3
		rts
; End of function Sonic_ApplyLevelStats
; Obj01:
SonicPlayer:
		cmpi.b	#$0A,obRoutine(a0)			; is Sonic waiting for the respawn camera?
		beq.s	Sonic_Normal				; keep the wait state out of Debug Mode
		tst.w	(v_debuguse).w				; is debug mode being used?
		beq.s	Sonic_Normal				; if not, branch
		jmp	(DebugMode).l				; run debug mode instead of Sonic object
; ===========================================================================

; Obj01_Normal:
Sonic_Normal:
		moveq	#0,d0					; clear d0
		move.b	obRoutine(a0),d0			; get current routine number
		move.w	Sonic_Index(pc,d0.w),d1			; find appropriate entry in jump table
		jmp	Sonic_Index(pc,d1.w)			; jump there
; ===========================================================================
; Obj01_Index:
Sonic_Index:	dc.w Sonic_Main-Sonic_Index			; 0 - object init
		dc.w Sonic_Control-Sonic_Index			; 2 - main mode
		dc.w Sonic_Hurt-Sonic_Index			; 4 - while being knocked back from damage
		dc.w Sonic_Death-Sonic_Index			; 6 - while dying and falling off screen
		dc.w Sonic_ResetLevel-Sonic_Index		; 8 - after having died and waiting for the level to restart
		dc.w Sonic_Respawning-Sonic_Index		; 10 - waiting for the respawn camera to stop

; Note: Sonic's SST aliases are defined in _Constants.asm
; ===========================================================================

; ---------------------------------------------------------------------------
; Sonic 2 Secret Rings-style respawn wait state.
; The player remains in this isolated object state while either camera axis
; still moves. It does not execute Sonic_Control or any player movement code.
; When both camera deltas are zero, it returns to normal control and starts
; the respawn blink in the same frame.
; ---------------------------------------------------------------------------
Sonic_Respawning:	; Routine 10
		tst.w	(v_scrshiftx).w			; is the camera still scrolling horizontally?
		bne.s	.wait				; if yes, keep controls locked
		tst.w	(v_scrshifty).w			; is the camera still scrolling vertically?
		bne.s	.wait				; if yes, keep controls locked
		clr.b	(f_lockctrl).w			; both camera axes stopped: unlock controls
		clr.b	(v_jpadhold2).w			; discard held input buffered during respawn
		clr.b	(v_jpadpress2).w			; discard button presses buffered during respawn
		move.b	#2,obRoutine(a0)			; return to Sonic_Control
		move.w	#2*60,flashtime(a0)		; start 2 seconds of respawn blinking
.wait:
		bsr.w	Sonic_Animate			; animate Sonic while the camera returns
		bsr.w	Sonic_LoadGfx			; keep animation graphics up to date
		bsr.w	Sonic_Display			; draw Sonic and process blink timer
		rts

; Obj01_Main:
Sonic_Main:	; Routine 0
		tst.b	(v_lastlamp).w				; no lamppost hit yet?
		bne.s	.notstart
		move.w	obX(a0),(v_respawn_x).w		; remember the level start position
		move.w	obY(a0),(v_respawn_y).w
.notstart:
		addq.b	#2,obRoutine(a0)			; set to Sonic_Control
		move.b	#sonic_height,obHeight(a0)		; set default height
		move.b	#sonic_width,obWidth(a0)		; set default width
		move.l	#Map_Sonic,obMap(a0)			; set mappings
		move.w	#ArtTile_Sonic,obGfx(a0)		; set VRAM location
		move.b	#2,obPriority(a0)			; set sprite priority
		move.b	#48/2,obActWid(a0)			; set render width
		move.b	#sprite_cam_field,obRender(a0)		; set to playfield-positioned mode
		bsr.w	Sonic_ApplyLevelStats			; initialise stats from the persistent speed level
		move.b	#id_SpinDust,(v_dustobj).w		; prepare Spin Dash dust object
		clr.b	(v_invcheckdash).w			; make sure the Dash Ring (Super) state is off
		move.w	#$003C,(v_dashdrain_timer).w		; S2SR: initialise Speed Break timer to $003C
		clr.b	(v_supersonic).w			; make sure Super Sonic is off
		clr.b	(v_supertransform_sfx_pending).w	; clear pending transformation sound
		clr.b	(v_hyperdash_flag).w			; clear Hyper Dash state
		clr.b	(v_hyperflash_timer).w			; clear Hyper flash state
		clr.b	(v_hyperflash_slowmo_frame).w
		clr.b	(v_hyperflash_hblank).w			; clear underwater flash latch
		clr.b	(v_hyperattack_pending).w		; clear deferred attack
		clr.b	(v_sonfall).w				; make sure the fall sprite is off
		clr.b	(v_supersonic_palstate).w		; clear Super palette state
; ---------------------------------------------------------------------------

; Obj01_Control:
Sonic_Control:	; Routine 2
		tst.w	(f_debugmode).w				; is debug cheat enabled?
		beq.s	.nodebug				; if not, branch
		btst	#bitB,(v_jpadpress1).w			; is button B pressed?
		beq.s	.nodebug				; if not, branch
		move.w	#1,(v_debuguse).w			; enter debug mode on the next frame (change Sonic into a ring/item)
		clr.b	(f_lockctrl).w				; unlock controls
		rts						; return
; ===========================================================================

; loc_12C58:
.nodebug:
		tst.b	(f_lockctrl).w				; are controls locked?
		bne.s	.ignorecontrols				; if yes, branch
		move.w	(v_jpadhold1).w,(v_jpadhold2).w		; enable joypad control

; loc_12C64:
.ignorecontrols:
		bsr.w	Sonic_DashRing				; Dash Ring (hold A): runs every frame, in every mode
		bsr.w	Sonic_CheckGoSuper			; manual Super Sonic transformation
		bsr.w	Sonic_AirFall				; B while jumping: fall sprite
		btst	#0,(f_playerctrl).w			; is control override flag set?
		bne.s	.ignoremodes				; if yes, don't run Sonic_Modes

		moveq	#0,d0					; clear d0
		move.b	obStatus(a0),d0				; get Sonic's status flags
		andi.w	#status_in_air|status_rolling,d0	; limit to "is in air" and "rolling" flags
		move.w	Sonic_Modes(pc,d0.w),d1			; use the those as routine counter for the correct mode
		jsr	Sonic_Modes(pc,d1.w)			; jump to that mode

; loc_12C7E:
.ignoremodes:
		bsr.s	Sonic_Display				; display Sonic sprite and handle power-up expiration
		bsr.w	Sonic_Super				; Super Sonic per-frame handler
		bsr.w	Sonic_RecordPosition			; record Sonic's previous position for the invincibility stars trail
		bsr.w	Sonic_Water				; handle Sonic while in water (LZ only)
		move.b	(v_anglebuffer).w,angleright(a0)	; update front collision hot spot
		move.b	(v_anglebuffer2).w,angleleft(a0)	; update rear collision hot spot

		tst.b	(f_wtunnelmode).w			; is Sonic in a wind tunnel? (LZ only)
		beq.s	.nowindtunnel				; if not, branch
		tst.b	obAnim(a0)				; is current animation null/id_Walk?
		bne.s	.nowindtunnel				; if not, branch
		move.b	obPrevAni(a0),obAnim(a0)		; make sure Sonic is in the correct animation while in a wind tunnel

; loc_12CA6:
.nowindtunnel:
		bsr.w	Sonic_Animate				; run Sonic's animation scripts
		tst.b	(f_playerctrl).w			; is object interactions ignore flag set?
		bmi.s	.ignoreobjcoll				; if yes, branch
		jsr	(ReactToItem).l				; handle object interaction with Sonic

; loc_12CB6:
.ignoreobjcoll:
		bsr.w	Sonic_Loops				; handle Sonic running through loops
		bsr.w	Sonic_LoadGfx				; update Sonic's graphics if necessary
		rts						; return
; End of function Sonic_Control


; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic modes table, based on whether he is currently in-air and/or rolling.
; This jump table uses Sonic's actual state bits in obStatus for the index.
; ---------------------------------------------------------------------------
; Obj01_Modes:
Sonic_Modes:	dc.w Sonic_MdNormal-Sonic_Modes			; 0 - while on the ground and not rolling
		dc.w Sonic_MdJump-Sonic_Modes			; 2 - while in the air and not rolling
		dc.w Sonic_MdRoll-Sonic_Modes			; 4 - while on the ground and rolling
		dc.w Sonic_MdJump2-Sonic_Modes			; 6 - while in the air and rolling


; ===========================================================================
; ---------------------------------------------------------------------------
; Music to play after invincibility wears off
; (This is pretty much identical to the first MusicList, so it doesn't
; really make any sense as to why invincibility gets a separate one...)
; ---------------------------------------------------------------------------
MusicList2:
		dc.b bgm_GHZ					; 00 - Green Hill Zone
		dc.b bgm_LZ					; 01 - Labyrinth Zone
		dc.b bgm_MZ					; 02 - Marble Zone
		dc.b bgm_SLZ					; 03 - Star Light Zone
		dc.b bgm_SYZ					; 04 - Spring Yard Zone
		dc.b bgm_SBZ					; 05 - Scrap Brain Zone
		zonewarning MusicList2,1
		; The ending doesn't get an entry
		even


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to display Sonic and set music
; ---------------------------------------------------------------------------

Sonic_Display:
		move.w	flashtime(a0),d0			; get Sonic's remaining invulnerability frames after getting hurt
		beq.s	.display				; if there are none, branch
		subq.w	#1,flashtime(a0)			; decrease invulnerability frames
		lsr.w	#3,d0					; don't render Sonic's sprite every...
		bcc.s	.chkinvincible				; ...3 or 4 frames

; Obj01_Display:
.display:
		jsr	(DisplaySprite).l			; display Sonic sprite normally

; Obj01_ChkInvin:
.chkinvincible:
		tst.b	(v_invinc).w				; does Sonic have invincibility?
		beq.s	.chkshoes				; if not, branch
		tst.w	invtime(a0)				; check time remaining for invincibility
		beq.s	.chkshoes				; if no time remains, branch
		subq.w	#1,invtime(a0)				; subtract 1 from time
		bne.s	.chkshoes				; if time remains, branch
		tst.b	(f_lockscreen).w			; is a boss fight active?
		bne.s	.removeinvincible			; if yes, don't change music
		cmpi.w	#12,(v_air).w				; is drowning countdown active?
		blo.s	.removeinvincible			; if yes, don't change music

		moveq	#0,d0					; clear d0
		move.b	(v_zone).w,d0				; get current zone ID
		cmpi.w	#id_LZ_act4,(v_zone_act).w		; check if level is SBZ3 (LZ4)
		bne.s	.music					; if not, branch
		moveq	#5,d0					; play SBZ music instead of LZ

; Obj01_PlayMusic:
.music:
		lea	(MusicList2).l,a1			; load music list for post-invincibility
		move.b	(a1,d0.w),d0				; get entry for current zone
		jsr	(QueueSound1).l				; resume normal level music

; Obj01_RmvInvin:
.removeinvincible:
		move.b	#0,(v_invinc).w				; cancel invincibility

; Obj01_ChkShoes:
.chkshoes:
		tst.b	(v_shoes).w				; does Sonic have speed shoes?
		beq.s	.return					; if not, branch
		tst.w	shoetime(a0)				; check time remaining
		beq.s	.return					; if there is none, branch
		subq.w	#1,shoetime(a0)				; subtract 1 from time
		bne.s	.return					; if time remains, branch
		move.b	#0,(v_shoes).w				; cancel Speed Shoes before recalculating
		bsr.w	Sonic_ApplyLevelStats			; restore this level's stats and water scaling
		move.w	#bgm_Slowdown,d0			; resume music...
		jmp	(QueueSound1).l				; ...at normal speed
; ===========================================================================

; Obj01_ExitChk:
.return:
		rts						; return
; End of function Sonic_Display


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars.
; Interestingly, this buffer is way larger than it needs to be, with just
; over a full second of space for recorded data, even though the star trail
; won't ever be that long. Specifically, it's $100/4 = $40 (64 frames).
; ---------------------------------------------------------------------------

; Sonic_RecordPos:
Sonic_RecordPosition:
		move.w	(v_trackpos).w,d0			; get current index for the tracking array
		lea	(v_tracksonic).w,a1			; load tracking array
		lea	(a1,d0.w),a1				; set pointer to current index
		move.w	obX(a0),(a1)+				; store Sonic's current X-position
		move.w	obY(a0),(a1)+				; store Sonic's current Y-position
		addq.b	#4,(v_trackbyte).w			; advance to next tracking pointer (this is a byte, so it wraps from $FC back to $00)
		rts						; return
; End of function Sonic_RecordPosition


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

Sonic_Water:
		cmpi.b	#id_LZ,(v_zone).w			; is level LZ?
		beq.s	.islabyrinth				; if yes, branch

; locret_12D80:
.return:
		rts						; return
; ===========================================================================

; Obj01_InWater:
.islabyrinth:
		move.w	(v_waterpos1).w,d0			; get current water height
		cmp.w	obY(a0),d0				; is Sonic above the water?
		bge.s	.abovewater				; if yes, branch
		bset	#status_underwater_bit,obStatus(a0)	; set underwater flag
		bne.s	.return					; was Sonic already underwater? if yes, nothing to do

		bsr.w	ResumeMusic				; replenish air (music won't resume here, we've only just entered water...)
		move.b	#id_DrownCount,(v_sonicbubbles).w	; load drown countdown object
		move.b	#$81,(v_sonicbubbles+obSubtype).w	; prepare subtype so it sets itself to Drown_Countdown
		bsr.w	Sonic_ApplyLevelStats			; apply level stats and underwater/Shoes scaling
		asr.w	obVelX(a0)				; half X-speed when entering water
		asr.w	obVelY(a0)				; divide Y-speed by 4 when entering water
		asr.w	obVelY(a0)				; (can only do one bit shift at a time on RAM)
		beq.s	.return					; if Sonic's new Y-speed is 0, don't load splash object
		move.b	#id_Splash,(v_splash).w			; load splash object
		move.w	#sfx_Splash,d0				; set splash sound
		jmp	(QueueSound2).l				; play it
; ===========================================================================

; Obj01_OutWater:
.abovewater:
		bclr	#status_underwater_bit,obStatus(a0)	; clear underwater flag
		beq.s	.return					; was Sonic already above water? if yes, nothing to do

		bsr.w	ResumeMusic				; replenish air and resume music if necessary
		bsr.w	Sonic_ApplyLevelStats			; restore current level and Speed Shoes scaling
		asl.w	obVelY(a0)				; double Y-speed while exiting water
		beq.w	.return					; if Sonic's new Y-speed is 0, don't load splash object
		move.b	#id_Splash,(v_splash).w			; load splash object
		cmpi.w	#-$1000,obVelY(a0)			; is Sonic's new upwards speed too fast for collision detection to handle? (red springs probably cause this)
		bgt.s	.belowmaxspeed				; if not, branch
		move.w	#-$1000,obVelY(a0)			; set maximum speed on leaving water

; loc_12E0E:
.belowmaxspeed:
		move.w	#sfx_Splash,d0				; set splash sound
		jmp	(QueueSound2).l				; play it
; End of function Sonic_Water


; ===========================================================================
; ---------------------------------------------------------------------------
; Modes for controlling Sonic
; ---------------------------------------------------------------------------

; Obj01_MdNormal:
Sonic_MdNormal:	; While Sonic is on the ground and not rolling
		bsr.w	Sonic_SpinDash
		bsr.w	Sonic_Jump				; check if we need to jump
		bsr.w	Sonic_SlopeResistWalk			; handle resistance from running up slopes
		bsr.w	Sonic_Move				; handle Sonic's left/right movement
		bsr.w	Sonic_Roll				; check if we need to roll
		bsr.w	Sonic_LevelBound			; make sure Sonic stays within level bounds and handle bottomless pits
		jsr	(SpeedToPos).l				; update Sonic's position based on his current velocities
		bsr.w	Sonic_AnglePos				; update Sonic's current angle as he walks along the floor
		bsr.w	Sonic_SlopeRepel			; handle Sonic detaching from walls if not fast enough
		rts
; ===========================================================================

; Obj01_MdJump:
Sonic_MdJump:	; While Sonic is in the air but not rolling
		bclr	#0,spindash_flag(a0)			; clear Spin Dash flag 
		bsr.w	Sonic_JumpHeight			; handle Sonic's jump height based on whether the jump button is still held
		bsr.w	Sonic_JumpDirection			; handle midair direction adjustments while jumping
		bsr.w	Sonic_LevelBound			; make sure Sonic stays within level bounds and handle bottomless pits
		jsr	(ObjectFall).l				; apply gravity and update Sonic's position based on his current velocities
		btst	#status_underwater_bit,obStatus(a0)	; is Sonic underwater?
		beq.s	.notunderwater				; if not, branch
		subi.w	#gravity-$10,obVelY(a0)			; reduce falling speed (ObjectFall applies $38, so this subtraction makes it $10)

; loc_12E5C:
.notunderwater:
		bsr.w	Sonic_JumpAngle				; steadily return Sonic's angle while jumping to 0
		bsr.w	Sonic_Floor				; handle collision with level while airborne
		rts						; return
; ===========================================================================

; Obj01_MdRoll:
Sonic_MdRoll:	; While Sonic is on the ground and rolling
		bsr.w	Sonic_Unroll
		bsr.w	Sonic_Jump				; check if we need to jump
		bsr.w	Sonic_SlopeResistRoll			; handle resistance from rolling up slopes
		bsr.w	Sonic_RollSpeed				; update speed as Sonic rolls
		bsr.w	Sonic_LevelBound			; make sure Sonic stays within level bounds and handle bottomless pits
		jsr	(SpeedToPos).l				; update Sonic's position based on his current velocities
		bsr.w	Sonic_AnglePos				; update Sonic's current angle as he walks along the floor
		bsr.w	Sonic_SlopeRepel			; handle Sonic detaching from walls if not fast enough
		rts
; ===========================================================================

; Obj01_MdJump2:
Sonic_MdJump2:	; While Sonic is in the air and rolling (usually, but not limited to, jumping)
		bclr	#0,spindash_flag(a0)			; clear Spin Dash flag 
		bsr.w	Sonic_JumpHeight			; handle Sonic's jump height based on whether the jump button is still held
		bsr.w	Sonic_JumpDirection			; handle midair direction adjustments while jumping
		bsr.w	Sonic_LevelBound			; make sure Sonic stays within level bounds and handle bottomless pits
		jsr	(ObjectFall).l				; apply gravity and update Sonic's position based on his current velocities
		btst	#status_underwater_bit,obStatus(a0)	; is Sonic underwater?
		beq.s	.notunderwater				; if not, branch
		subi.w	#gravity-$10,obVelY(a0)			; reduce falling speed (ObjectFall applies $38, so this subtraction makes it $10)

; loc_12EA6:
.notunderwater:
		bsr.w	Sonic_JumpAngle				; steadily return Sonic's angle while jumping to 0
		bsr.w	Sonic_Floor				; handle collision with level while airborne
		rts						; return
; End of Sonic_Modes


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to make Sonic walk/run
; ---------------------------------------------------------------------------

Sonic_Move:
		move.w	(v_sonspeedmax).w,d6			; get Sonic's current top speed
		move.w	(v_sonspeedacc).w,d5			; get Sonic's current acceleration
		move.w	(v_sonspeeddec).w,d4			; get Sonic's current deceleration

		tst.b	(f_slidemode).w				; is Sonic currently on a water slide? (LZ only)
		bne.w	Sonic_AngleSpeed			; if yes, branch
		tst.w	locktime(a0)				; is Sonic's D-Pad input temporarily locked?
		bne.w	Sonic_ResetScr				; if yes, ignore D-Pad input
		tst.b	(v_invcheckdash).w			; is the Dash Ring accelerating Sonic?
		bne.w	Sonic_AngleSpeed			; if yes, preserve inertia and bypass normal speed cap/deceleration
		btst	#bitL,(v_jpadhold2).w			; is left being held?
		beq.s	.notleft				; if not, branch
		bsr.w	Sonic_MoveLeft				; apply left side movement updates

; Obj01_NotLeft:
.notleft:
		btst	#bitR,(v_jpadhold2).w			; is right being held?
		beq.s	.notright				; if not, branch
		bsr.w	Sonic_MoveRight				; apply right side movement updates

; Obj01_NotRight:
.notright:
		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$20,d0					; rotate it 45 degrees clockwise
		andi.b	#$C0,d0					; snap to nearest multiple of 90 degrees
		bne.w	Sonic_ResetScr				; is Sonic on a slope? if yes, branch

		tst.w	obInertia(a0)				; is Sonic standing still?
		bne.w	Sonic_ResetScr				; if not, branch
		bclr	#status_pushing_bit,obStatus(a0)	; clear pushing flag
		move.b	#id_Wait,obAnim(a0)			; use "standing" animation
		btst	#status_on_object_bit,obStatus(a0)	; is Sonic standing on a platform object?
		beq.s	.chkbalance				; if not, branch

		moveq	#0,d0					; clear d0
		move.b	standonobject(a0),d0			; get OST index of object Sonic is currently standing on
		lsl.w	#object_size_bits,d0			; multiply by $40 (object_size)
		lea	(v_objspace).w,a1			; load object space
		lea	(a1,d0.w),a1				; load stood-on object
		tst.b	obStatus(a1)				; does the object block Sonic's balancing animation?
		bmi.s	Sonic_LookUp				; if yes, skip over balance check
		cmpi.w	#ArtTile_GHZ_Bridge|Tile_Pal3,obGfx(a1)	; is stood-on object a GHZ bridge?
		beq.w	Sonic_LookUp				; if yes, never show balance animation

		moveq	#0,d1					; clear d1
		move.b	obActWid(a1),d1				; get physical width of stood-on object
		cmpi.b	#16/2,d1				; is this a really small platform?
		bls.s	Sonic_LookUp				; if yes, ignore balancing (looks weird)
		move.w	d1,d2					; copy width
		add.w	d2,d2					; double it
		subq.w	#4,d2					; minus 4
		add.w	obX(a0),d1				; get Sonic's current X-position
		sub.w	obX(a1),d1				; subtract stood-on object's X-position
		cmpi.w	#4,d1					; is Sonic within 4px of the object's left edge?
		blt.s	.leftbalance				; if yes, branch
		cmp.w	d2,d1					; is Sonic within 4px of the object's right edge?
		bge.s	.rightbalance				; if yes, branch
		bra.s	Sonic_LookUp				; skip over (no balancing)
; ===========================================================================

; Sonic_Balance:
.chkbalance:
		jsr	(ObjFloorDist).l			; get distance of Sonic to nearest floor
		cmpi.w	#12,d1					; is he within 12px to floor?
		blt.s	Sonic_LookUp				; if yes, don't do balance animation (would look awkward)
		cmpi.b	#3,angleright(a0)			; is Sonic at the right edge of the floor?
		bne.s	.chkleftedge				; if not, check for the left edge

; loc_12F5A:
.rightbalance:
		bclr	#status_xflip_bit,obStatus(a0)		; clear X-flip flag (make Sonic face right)
		bra.s	.balance				; do balance animation
; ===========================================================================

; loc_12F62:
.chkleftedge:
		cmpi.b	#3,angleleft(a0)			; is Sonic at the left edge of the floor?
		bne.s	Sonic_LookUp				; if not, branch (no balancing)

; loc_12F6A:
.leftbalance:
		bset	#status_xflip_bit,obStatus(a0)		; set X-flip flag (make Sonic face left)

; loc_12F70:
.balance:
		move.b	#id_Balance,obAnim(a0)			; use "balancing" animation
		bra.s	Sonic_ResetScr				; prevent looking up/down
; ===========================================================================

Sonic_LookUp:
		btst	#bitUp,(v_jpadhold2).w			; is up being held?
		beq.s	Sonic_Duck				; if not, check for ducking instead
		move.b	#id_LookUp,obAnim(a0)			; use "looking up" animation
		addq.b	#1,(v_cam_y_delay).w			; add 1 to camera Y delay
		cmpi.b	#120,(v_cam_y_delay).w			; did we reach target wait time of 120 frames (2 seconds)?
		blo.s	Sonic_ResetScr_Part2			; if not, branch
		move.b	#120,(v_cam_y_delay).w			; cap wait time
		cmpi.w	#$C8,(v_lookshift).w			; has camera already fully moved up?
		beq.s	Sonic_CheckDpadLetGo			; if yes, don't move it up further
		addq.w	#2,(v_lookshift).w			; move camera up further
		bra.s	Sonic_CheckDpadLetGo			; skip over
; ===========================================================================

; Sonic_LookDown:
Sonic_Duck:
		btst	#bitDn,(v_jpadhold2).w			; is down being held?
		beq.s	Sonic_ResetScr				; if not, branch
		move.b	#id_Duck,obAnim(a0)			; use "ducking" animation
		addq.b	#1,(v_cam_y_delay).w			; add 1 to camera Y delay
		cmpi.b	#120,(v_cam_y_delay).w			; did we reach target wait time of 120 frames (2 seconds)?
		blo.s	Sonic_ResetScr_Part2			; if not, branch
		move.b	#120,(v_cam_y_delay).w			; cap wait time
		cmpi.w	#8,(v_lookshift).w			; has camera already fully moved down?
		beq.s	Sonic_CheckDpadLetGo			; if yes, branch
		subq.w	#2,(v_lookshift).w			; move camera down further
		bra.s	Sonic_CheckDpadLetGo			; skip over
; ===========================================================================

; Obj01_ResetScr:
Sonic_ResetScr:
		clr.b	(v_cam_y_delay).w			; reset camera Y delay timer

Sonic_ResetScr_Part2:
		cmpi.w	#$60,(v_lookshift).w			; is screen in its default position?
		beq.s	Sonic_CheckDpadLetGo			; if yes, branch
		bcc.s	.resetdown				; does camera need to go back down? if yes, branch
		addq.w	#4,(v_lookshift).w			; move camera back up (becomes 2 with the next line)

; loc_12FBE:
.resetdown:
		subq.w	#2,(v_lookshift).w			; move camera back down

; ---------------------------------------------------------------------------

; loc_12FC2:
Sonic_CheckDpadLetGo:
		move.b	(v_jpadhold2).w,d0			; get held buttons
		andi.b	#btnL+btnR,d0				; is left or right held?
		bne.s	Sonic_AngleSpeed			; if yes, branch (don't decrease speed)
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		beq.s	Sonic_AngleSpeed			; is he standing still? if yes, branch
		bmi.s	.movingleftward				; is he moving to the left? if yes, branch
		sub.w	d5,d0					; reduce current rightward speed by acceleration
		bcc.s	.stillright				; if result is still to the right, branch
		move.w	#0,d0					; reset speed to zero on sign change

; loc_12FDC:
.stillright:
		move.w	d0,obInertia(a0)			; set Sonic's new ground speed
		bra.s	Sonic_AngleSpeed			; skip over
; ===========================================================================

; loc_12FE2:
.movingleftward:
		add.w	d5,d0					; reduce current leftward speed by acceleration
		bcc.s	.stillleft				; if result is still to the left, branch
		move.w	#0,d0					; reset speed to zero on sign change

; loc_12FEA:
.stillleft:
		move.w	d0,obInertia(a0)			; set Sonic's new ground speed
; ---------------------------------------------------------------------------

; loc_12FEE:
Sonic_AngleSpeed:
		move.b	obAngle(a0),d0				; get Sonic's current angle in relation to the floor
		jsr	(CalcSine).l				; get sine and cosine values based on angle
		muls.w	obInertia(a0),d1			; multiply cosine value by current ground speed
		asr.l	#8,d1					; shift result up a byte
		move.w	d1,obVelX(a0)				; set new X-velocity
		muls.w	obInertia(a0),d0			; multiply sine value by current ground speed
		asr.l	#8,d0					; shift result up a byte
		move.w	d0,obVelY(a0)				; set new Y-velocity
; ---------------------------------------------------------------------------

; loc_1300C:
Sonic_WallSpeedAdjust:
	if FixBugs
		; This was added to S&K to prevent an issue where Sonic could run through walls
		; if he is upside-down, or moving on a wall if his angle is exactly $80. This issue
		; can be seen in S3 alone's Carnival Night Zone if you jump onto a curved ceiling.
		move.b	obAngle(a0),d0				; get Sonic's current angle in relation to the floor
		andi.b	#$3F,d0					; is he standing on a flat surface in any of the four quadrants?
		beq.s	.noearlyexit				; if yes, skip the upside-down exit below
	endif
		move.b	obAngle(a0),d0				; get Sonic's current angle in relation to the floor
		addi.b	#$40,d0					; rotate it by 90 degrees
		bmi.s	.return					; if Sonic is upside down, branch (to prevent potential collision issues with loops)

.noearlyexit:
		move.b	#$40,d1					; get angle rotation for wall collision detection
		tst.w	obInertia(a0)				; is Sonic standing still?
		beq.s	.return					; if yes, branch
		bmi.s	.negspeed				; is he moving to the left? if yes, branch
		neg.w	d1					; invert angle rotation when moving right

; loc_13024:
.negspeed:
		move.b	obAngle(a0),d0				; get Sonic's current angle
		add.b	d1,d0					; rotate it by 90 degrees depending on directional speed
		move.w	d0,-(sp)				; backup d0
		bsr.w	Sonic_CalcRoomAhead			; calculate distance to the wall in front of Sonic (if any)
		move.w	(sp)+,d0				; restore d0
		tst.w	d1					; has Sonic touched a wall?
		bpl.s	.return					; if not, branch
		asl.w	#8,d1					; convert diff to wall into 8.8 fixed point for adjusting velocity
		addi.b	#$20,d0					; rotate angle by 45 degrees clockwise
		andi.b	#$C0,d0					; snap angle to nearest multiple of 90 degrees
		beq.s	.hitdown				; if Sonic is facing down, branch
		cmpi.b	#$40,d0					; is Sonic facing left?
		beq.s	.hitleft				; if yes, branch
		cmpi.b	#$80,d0					; is Sonic facing up?
		beq.s	.hitup					; if yes, branch

.hitright:	; d0 is $C0, Sonic is facing right
		add.w	d1,obVelX(a0)				; adjust X-velocity to prevent Sonic from walking into the wall
	if FixBugs
		; Knuckles in Sonic 2 changed this code, likely to patch a bug
		; where if the player slides into a wall while trying to move
		; in the opposite direction, you'd enter the pushing animation
		; while moving away.
		move.w	#0,obInertia(a0)			; clear ground speed
		btst	#status_xflip_bit,obStatus(a0)		; is Sonic facing the wall?
		bne.s	.awayright				; if not, branch
		bset	#status_pushing_bit,obStatus(a0)	; set pushing flag

.awayright:
	else
		bset	#status_pushing_bit,obStatus(a0)	; set pushing flag
		move.w	#0,obInertia(a0)			; clear ground speed
	endif
		rts						; return
; ===========================================================================

; loc_13060:
.hitup:		; d0 is $80, Sonic is facing up
		sub.w	d1,obVelY(a0)				; adjust Y-velocity to prevent Sonic from walking into the ceiling
		rts
; ===========================================================================

; loc_13066:
.hitleft:	; d0 is $40, Sonic is facing left
		sub.w	d1,obVelX(a0)				; adjust X-velocity to prevent Sonic from walking into the wall
	if FixBugs
		; See above.
		move.w	#0,obInertia(a0)			; clear ground speed
		btst	#status_xflip_bit,obStatus(a0)		; is Sonic facing the wall?
		beq.s	.awayleft				; if not, branch
		bset	#status_pushing_bit,obStatus(a0)	; set pushing flag

.awayleft:
	else
		bset	#status_pushing_bit,obStatus(a0)	; set pushing flag
		move.w	#0,obInertia(a0)			; clear ground speed
	endif
		rts						; return
; ===========================================================================

; loc_13078:
.hitdown:	; d0 is $00, Sonic is facing down
		add.w	d1,obVelY(a0)				; adjust Y-velocity to prevent Sonic from walking into the floor

; locret_1307C:
.return:
		rts						; return
; End of function Sonic_Move


; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the left
; ---------------------------------------------------------------------------

Sonic_MoveLeft:
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		beq.s	.still					; is Sonic standing still? if yes, branch
		bpl.s	.changeddirection			; has Sonic changed direction? if yes, branch

; loc_13086:
.still:
		bset	#status_xflip_bit,obStatus(a0)		; set X-flip flag (Sonic is facing left)
		bne.s	.alreadyleft				; if he already was facing left, branch
		bclr	#status_pushing_bit,obStatus(a0)	; clear pushing flag
		move.b	#id_Run,obPrevAni(a0)			; restart Sonic's animation

; loc_1309A:
.alreadyleft:
		sub.w	d5,d0					; subtract acceleration to current ground speed
		move.w	d6,d1					; get current top speed
		neg.w	d1					; negate it for left-side check
		cmp.w	d1,d0					; is new speed above max speed?
		bgt.s	.nocap					; if not, branch
		add.w	d5,d0			; +++ remove this frame's acceleration change
		cmp.w	d1,d0			; +++ compare speed with top speed
		ble.s	.nocap			; +++ if speed was already greater than the maximum, branch
		move.w	d1,d0					; cap Sonic's ground speed

; loc_130A6:
.nocap:
		move.w	d0,obInertia(a0)			; set new ground speed
		move.b	#id_Walk,obAnim(a0)			; use walking animation
		rts						; return
; ===========================================================================

; loc_130B2:
.changeddirection:
		sub.w	d4,d0					; apply deceleration to current speed
		bcc.s	.stilldecel       			; if still decelerating, branch
		move.w	#-$80,d0        			; set minimum speed on sign change

; loc_130BA:
.stilldecel:
		move.w	d0,obInertia(a0)			; set new ground speed
	if FixBugs
		move.b	obAngle(a0),d1				; get Sonic's current angle
		addi.b	#$20,d1					; rotate by 45 degrees clockwise
		andi.b	#$C0,d1					; snap to nearest multiple of 90 degrees
	else
		; d0 should not be used here, as it results in obInertia being
		; partially overwritten! This causes Sonic's skidding animation
		; to activate at differing speeds when he's moving left or right.

		; This oversight was only corrected in Knuckles in Sonic 2. Not
		; even Sonic 3 & Knuckles itself had this fixed.
		move.b	obAngle(a0),d0				; get Sonic's current angle (and partially overwrite d0...)
		addi.b	#$20,d0					; rotate by 45 degrees clockwise
		andi.b	#$C0,d0					; snap to nearest multiple of 90 degrees
	endif
		bne.s	.nostopping				; if Sonic is on a wall or ceiling, prevent stopping animation
		cmpi.w	#$400,d0				; has Sonic changed direction while being really fast?
		blt.s	.nostopping				; if not, don't play skidding animation/sound
		move.b	#id_Stop,obAnim(a0)			; use "stopping" animation
		bclr	#status_xflip_bit,obStatus(a0)		; clear X-flip flag (Sonic is now facing right)
		move.w	#sfx_Skid,d0				; set skidding sound
		jsr	(QueueSound2).l				; play it

; locret_130E8:
.nostopping:
		rts						; return
; End of function Sonic_MoveLeft


; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the right
; ---------------------------------------------------------------------------

Sonic_MoveRight:
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		bmi.s	.changedirection			; has Sonic changed direction? if yes, branch
		bclr	#status_xflip_bit,obStatus(a0)		; clear X-flip flag (Sonic is facing right)
		beq.s	.alreadyright				; if he already was facing right, branch
		bclr	#status_pushing_bit,obStatus(a0)	; clear pushing flag
		move.b	#id_Run,obPrevAni(a0)			; restart Sonic's animation

; loc_13104:
.alreadyright:
		add.w	d5,d0					; add acceleration to current ground speed
		cmp.w	d6,d0					; is new speed above max speed?
		blt.s	.nocap					; if not, branch
		sub.w	d5,d0			; +++ remove this frame's acceleration change
		cmp.w	d6,d0			; +++ compare speed with top speed
		bge.s	.nocap			; +++ if speed was already greater than the maximum, branch
		move.w	d6,d0					; cap Sonic's ground speed

; loc_1310C:
.nocap:
		move.w	d0,obInertia(a0)			; set new ground speed
		move.b	#id_Walk,obAnim(a0)			; use walking animation
		rts						; return
; ===========================================================================

; loc_13118:
.changedirection:
		add.w	d4,d0					; apply deceleration to current speed
		bcc.s	.stilldecel				; if still decelerating, branch
		move.w	#$80,d0					; set minimum speed on sign change

; loc_13120:
.stilldecel:
		move.w	d0,obInertia(a0)			; set new ground speed
	if FixBugs
		move.b	obAngle(a0),d1				; get Sonic's current angle
		addi.b	#$20,d1					; rotate by 45 degrees clockwise
		andi.b	#$C0,d1					; snap to nearest multiple of 90 degrees
	else
		; See explanation in Sonic_MoveLeft.
		move.b	obAngle(a0),d0				; get Sonic's current angle (and partially overwrite d0...)
		addi.b	#$20,d0					; rotate by 45 degrees clockwise
		andi.b	#$C0,d0					; snap to nearest multiple of 90 degrees
	endif
		bne.s	.nostopping				; if Sonic is on a wall or ceiling, prevent stopping animation
		cmpi.w	#-$400,d0				; has Sonic changed direction while being really fast?
		bgt.s	.nostopping				; if not, don't play skidding animation/sound

		move.b	#id_Stop,obAnim(a0)			; use "stopping" animation
		bset	#status_xflip_bit,obStatus(a0)		; set X-flip flag (Sonic is now facing left)
		move.w	#sfx_Skid,d0				; set skidding sound
		jsr	(QueueSound2).l				; play it

; locret_1314E:
.nostopping:
		rts						; return
; End of function Sonic_MoveRight


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's speed as he rolls
; ---------------------------------------------------------------------------

Sonic_RollSpeed:
		move.w	(v_sonspeedmax).w,d6			; get Sonic's current max speed...
		asl.w	#1,d6					; ...doubled while rolling
		moveq	#6,d5					; fixed natural roll deceleration (so Super Sonic doesn't stop too fast)
		move.w	(v_sonspeeddec).w,d4			; get Sonic's current deceleration...
		asr.w	#2,d4					; ...divided by 4 while rolling

		tst.b	(f_slidemode).w				; is Sonic on a water slide? (LZ only)
		bne.w	Sonic_AngledRollSpeed			; if yes, branch (no rolling)
		tst.w	locktime(a0)				; is Sonic's D-Pad input temporarily locked?
		bne.s	.notright				; if yes, ignore D-Pad input
		tst.b	(v_invcheckdash).w			; is the Dash Ring accelerating Sonic?
		bne.w	Sonic_AngledRollSpeed			; if yes, bypass roll slowdown and use full boosted inertia
		btst	#bitL,(v_jpadhold2).w			; is left being held?
		beq.s	.notleft				; if not, branch
		bsr.w	Sonic_RollLeft				; apply leftside movement updates for rolling

; loc_1317C:
.notleft:
		btst	#bitR,(v_jpadhold2).w			; is right being held?
		beq.s	.notright				; if not, branch
		bsr.w	Sonic_RollRight				; apply rightward movement updates for rolling
; ---------------------------------------------------------------------------

; loc_13188:
.notright:
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		beq.s	Sonic_RollSlowdownDone			; is he standing still? if yes, branch
		bmi.s	.rollingleft				; is he moving to the left? if yes, branch
		sub.w	d5,d0					; slightly decrease Sonic's current roll speed
		bcc.s	.stillrollingright			; if still rolling, branch
		move.w	#0,d0					; reset speed to zero on sign change

; loc_13198:
.stillrollingright:
		move.w	d0,obInertia(a0)			; set new ground speed
		bra.s	Sonic_RollSlowdownDone			; skip over leftward rolling updates
; ===========================================================================

; loc_1319E:
.rollingleft:
		add.w	d5,d0					; slightly decrease Sonic's current roll speed
		bcc.s	.stillrollingleft			; if still rolling, branch
		move.w	#0,d0					; reset speed to zero on sign change

; loc_131A6:
.stillrollingleft:
		move.w	d0,obInertia(a0)			; set new ground speed
; ---------------------------------------------------------------------------

; loc_131AA:
Sonic_RollSlowdownDone:
		tst.w	obInertia(a0)				; is Sonic standing still?
		bne.s	Sonic_AngledRollSpeed			; if not, branch

		bclr	#status_rolling_bit,obStatus(a0)	; clear rolling flag
		move.b	#sonic_height,obHeight(a0)		; reset Sonic's hitbox height to default
		move.b	#sonic_width,obWidth(a0)		; reset Sonic's hitbox width to default
		move.b	#id_Wait,obAnim(a0)			; use "standing" animation
		subq.w	#sonic_height-sonic_roll_height,obY(a0)	; adjust Y-position for standing
; ---------------------------------------------------------------------------

; loc_131CC:
Sonic_AngledRollSpeed:
	if FixBugs
		; Sonic 1 does not reset the camera to its default position when
		; rolling. This oversight was corrected in Sonic 2.
		cmpi.w	#$60,(v_lookshift).w			; is screen in its default position?
		beq.s	.regularpos				; if yes, branch
		bcc.s	.resetdown				; does camera need to go back down? if yes, branch
		addq.w	#4,(v_lookshift).w			; move camera back up (becomes 2 with the next line)

.resetdown:
		subq.w	#2,(v_lookshift).w			; move camera back down

.regularpos:
	endif
		move.b	obAngle(a0),d0				; get Sonic's current angle in relation to the floor
		jsr	(CalcSine).l				; get sine and cosine values for the angle
		muls.w	obInertia(a0),d0			; multiply angle sine by ground speed
		asr.l	#8,d0					; shift result one byte down

	if FixBugs
		; Fix max roll speed not being capped for vertical momentum,
		; original code only caps for horizontal movement
		cmpi.w	#$1000,d0				; is new Y-velocity bigger than maximum screen shift speed? (downward)
		ble.s	.noPosIntCapY				; if not, branch
		move.w	#$1000,d0				; cap roll speed to screen shift speed (downward)
.noPosIntCapY:	cmpi.w	#-$1000,d0				; is new Y-velocity bigger than maximum screen shift speed? (upward)
		bge.s	.noNegIntCapY				; if not, branch
		move.w	#-$1000,d0				; cap roll speed to screen shift speed (upward)
.noNegIntCapY:
	endif
		move.w	d0,obVelY(a0)				; set new Y-velocity

		muls.w	obInertia(a0),d1			; multiply angle cosine by ground speed
		asr.l	#8,d1					; shift result one byte down
		tst.b	(v_invcheckdash).w			; is the Dash Ring accelerating Sonic?
		bne.s	.noNegIntCapX				; if yes, allow boosted horizontal speed beyond normal roll cap
		cmpi.w	#$1000,d1				; is new X-velocity bigger than maximum screen shift speed? (rightward)
		ble.s	.noPosIntCapX				; if not, branch
		move.w	#$1000,d1				; cap roll speed to screen shift speed (rightward)
; loc_131F0:
.noPosIntCapX:
		cmpi.w	#-$1000,d1				; is new X-velocity bigger than maximum screen shift speed? (leftward)
		bge.s	.noNegIntCapX				; if not, branch
		move.w	#-$1000,d1				; cap roll speed to screen shift speed (leftward)
; loc_131FA:
.noNegIntCapX:
		move.w	d1,obVelX(a0)				; set new X-velocity

		bra.w	Sonic_WallSpeedAdjust			; adjust speed variations depending on current angle, or stop at wall
; End of function Sonic_RollSpeed


; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while rolling to the left
; ---------------------------------------------------------------------------

Sonic_RollLeft:
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		beq.s	.still					; is Sonic standing still? if yes, branch
		bpl.s	.changeddirection			; has Sonic changed direction? if yes, branch

; loc_1320A:
.still:
		bset	#status_xflip_bit,obStatus(a0)		; set X-flip flag (Sonic is facing left)
		move.b	#id_Roll,obAnim(a0)			; use "rolling" animation
		rts						; return
; ===========================================================================

; loc_13218:
.changeddirection:
		sub.w	d4,d0					; apply deceleration to current speed
		bcc.s	.stilldecel				; if still decelerating, branch
		move.w	#-$80,d0				; set minimum speed on sign change

; loc_13220:
.stilldecel:
		move.w	d0,obInertia(a0)			; set new ground speed
		rts						; return
; End of function Sonic_RollLeft


; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while rolling to the right
; ---------------------------------------------------------------------------

Sonic_RollRight:
		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		bmi.s	.changedirection			; has Sonic changed direction? if yes, branch
		bclr	#status_xflip_bit,obStatus(a0)		; clear X-flip flag (Sonic is facing right)
		move.b	#id_Roll,obAnim(a0)			; use "rolling" animation
		rts						; return
; ===========================================================================

; loc_1323A:
.changedirection:
		add.w	d4,d0					; apply deceleration to current speed
		bcc.s	.stilldecel				; if still decelerating, branch
		move.w	#$80,d0					; set minimum speed on sign change

; loc_13242:
.stilldecel:
		move.w	d0,obInertia(a0)			; set new ground speed
		rts						; return
; End of function Sonic_RollRight


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's direction while jumping
; ---------------------------------------------------------------------------

; Sonic_ChgJumpDir:
Sonic_JumpDirection:
		move.w	(v_sonspeedmax).w,d6			; get Sonic's current top speed
		move.w	(v_sonspeedacc).w,d5			; get Sonic's current acceleration...
		asl.w	#1,d5					; ...doubled

;		btst	#status_rolljumping_bit,obStatus(a0)	; is Roll-Jump flag set?
;		bne.s	Sonic_RollJumpLock			; if yes, prevent midair direction change

		move.w	obVelX(a0),d0				; get Sonic's current X-velocity
		btst	#bitL,(v_jpadhold2).w			; is left being held?
		beq.s	.notleft				; if not, branch
		bset	#status_xflip_bit,obStatus(a0)		; set X-flip flag (Sonic is facing left)
		sub.w	d5,d0					; increase leftward movement speed
		move.w	d6,d1					; copy top speed
		neg.w	d1					; negate it for leftward movement check
		cmp.w	d1,d0					; is new speed exceeding maximum?
		bgt.s	.notleft				; if not, branch
		add.w	d5,d0			; +++ remove this frame's acceleration change
		cmp.w	d1,d0			; +++ compare speed with top speed
		ble.s	.notleft		; +++ if speed was already greater than the maximum, branch
		move.w	d1,d0					; cap leftward X-speed to maximum

; loc_13278:
.notleft:
		btst	#bitR,(v_jpadhold2).w			; is right being held?
		beq.s	Sonic_JumpMove				; if not, branch
		bclr	#status_xflip_bit,obStatus(a0)		; clear X-flip flag (Sonic is facing right)
		add.w	d5,d0					; increase rightward movement speed
		cmp.w	d6,d0					; is new speed exceeding maximum?
		blt.s	Sonic_JumpMove				; if not, branch
		sub.w	d5,d0			; +++ remove this frame's acceleration change
		cmp.w	d6,d0			; +++ compare speed with top speed
		bge.s	Sonic_JumpMove		; +++ if speed was already greater than the maximum, branch
		move.w	d6,d0					; cap rightward X-speed to maximum

; Obj01_JumpMove:
Sonic_JumpMove:
		move.w	d0,obVelX(a0)				; update Sonic's horizontal speed
; ---------------------------------------------------------------------------

; Obj01_ResetScr2:
Sonic_RollJumpLock:
		cmpi.w	#$60,(v_lookshift).w			; is screen in its default position?
		beq.s	Sonic_AirDrag				; if yes, branch
		bcc.s	.resetdown				; does camera need to go back down? if yes, branch
		addq.w	#4,(v_lookshift).w			; move camera back up (becomes 2 with the next line)

; loc_132A0:
.resetdown:
		subq.w	#2,(v_lookshift).w			; move camera back down
; ---------------------------------------------------------------------------

; loc_132A4:
Sonic_AirDrag:
		tst.b	(v_invcheckdash).w			; is the Dash Ring accelerating Sonic?
		bne.s	.return				; if yes, do not apply normal air drag
		cmpi.w	#-$400,obVelY(a0)			; is Sonic moving faster than -$400 upwards?
		blo.s	.return					; if yes, branch (skip air drag)

		move.w	obVelX(a0),d0				; get current X-velocity
		move.w	d0,d1					; copy it
		asr.w	#5,d1					; divide that copy by $20
		beq.s	.return					; if result is zero, branch
		bmi.s	.jumpingleftward			; if speed is negative, branch
		sub.w	d1,d0					; slightly reduce speed (air drag)
		bcc.s	.stillright				; if result is still rightward, branch
		move.w	#0,d0					; reset speed on sign change

; loc_132C0:
.stillright:
		move.w	d0,obVelX(a0)				; set new X-speed
		rts						; return
; ===========================================================================

; loc_132C6:
.jumpingleftward:
		sub.w	d1,d0					; slightly reduce speed (air drag)
		bcs.s	.stillleft				; if result is still leftward, branch
		move.w	#0,d0					; reset speed on sign change

; loc_132CE:
.stillleft:
		move.w	d0,obVelX(a0)				; set new X-speed

; locret_132D2:
.return:
		rts						; return
; End of function Sonic_JumpDirection


; ===========================================================================
	if UnusedOptimization=0
; ---------------------------------------------------------------------------
; Unused subroutine to squash Sonic into the ceiling. When Sonic gets stuck
; in a ceiling, this would zero all his momentum and set his animation to
; be the vertical "warping" sprite, which is also unused. The purpose of
; this routine isn't known, though it possibly was for troubleshooting
; collision errors in which Sonic would somehow clip through ceilings.
; ---------------------------------------------------------------------------

Sonic_SquashUnused:
		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$20,d0					; rotate it by 45 degrees
		andi.b	#$C0,d0					; snap angle to nearest multiple of 90 degrees
		bne.s	.return					; if Sonic is standing on a wall/ceiling, branch (must be standing on a floor)
		bsr.w	Sonic_FindCeiling			; find Sonic's distance to the ceiling
		tst.w	d1					; is he below it?
		bpl.s	.return					; if yes, branch (this should always happen unless he clipped through)

		move.w	#0,obInertia(a0)			; clear Sonic's ground speed
		move.w	#0,obVelX(a0)				; clear Sonic's horizontal speed
		move.w	#0,obVelY(a0)				; clear Sonic's vertical speed
		move.b	#id_Warp3,obAnim(a0)			; use "warping" animation

; locret_13302:
.return:
		rts						; return
; End of function Sonic_SquashUnused
	endif

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to prevent Sonic leaving the left/right boundaries of a level,
; dying to bottomless pits, and handling the transition from SBZ2 to SBZ3.
; This routine does not do anything about the top boundary.
; ---------------------------------------------------------------------------

Sonic_LevelBound:
		move.l	obX(a0),d1				; get Sonic's current X-position
		move.w	obVelX(a0),d0				; get Sonic's current X-velocity
		ext.l	d0					; sign-extend X-velocity
		asl.l	#8,d0					; shift upper byte of velocity to upper word
		add.l	d0,d1					; add to previous X-position
		swap	d1					; move new absolute pixel position to lower word

		move.w	(v_limitleft2).w,d0			; load level's left boundary
		addi.w	#16,d0					; add 16px of leeway
		cmp.w	d1,d0					; has Sonic touched the left level boundary?
		bhi.s	.sides					; if yes, branch

		move.w	(v_limitright2).w,d0			; load level's right boundary
		addi.w	#320-24,d0				; add screen width - 24px of leeway
		tst.b	(f_lockscreen).w			; is a boss fight active?
		bne.s	.screenlocked				; if yes, branch
		addi.w	#64,d0					; increase leeway by 64px outside of boss fights

; loc_13332:
.screenlocked:
		cmp.w	d1,d0					; has Sonic touched the right level boundary?
		bls.s	.sides					; if yes, branch

; loc_13336:
.chkbottom:
		move.w	(v_limitbtm2).w,d0			; load current target bottom level boundary
	if FixBugs
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in GHZ act 1 fast enough can kill Sonic.
		move.w	(v_limitbtm1).w,d1			; load current actual bottom level boundary
		cmp.w	d0,d1					; is target bottom level boundary higher than current real one?
		blo.s	.skipboundaryoverride			; if not, branch
		move.w	d1,d0					; use target level boundary while it's moving down to prevent unfair deaths
.skipboundaryoverride:
	endif
		addi.w	#224,d0					; add screen height
		cmp.w	obY(a0),d0				; has Sonic touched the bottom boundary?
		blt.s	.bottom					; if yes, branch
		rts						; return
; ===========================================================================

; Boundary_Bottom:
.bottom:
	if FixBugs
		; See below...
		cmpi.w	#id_SBZ_act2,(v_zone_act).w		; is level SBZ2?
		bne.s	JumpTo_KillSonic			; if not, kill Sonic
		cmpi.w	#$2000,(v_player+obX).w			; is Sonic far enough into the level?
		blo.s	JumpTo_KillSonic			; if not, kill Sonic
	else
		cmpi.w	#id_SBZ_act2,(v_zone_act).w		; is level SBZ2?
		bne.w	KillSonic				; if not, kill Sonic
		cmpi.w	#$2000,(v_player+obX).w			; is Sonic far enough into the level?
		blo.w	KillSonic				; if not, kill Sonic
	endif

		; Transition from SBZ2 to SBZ3
		clr.b	(v_lastlamp).w				; clear lamppost counter
		move.w	#1,(f_restart).w			; restart the level
		move.w	#id_LZ_act4,(v_zone_act).w		; set level to SBZ3 (LZ4)
		rts						; return
; ===========================================================================

; Boundary_Sides:
.sides:
		move.w	d0,obX(a0)				; prevent Sonic from leaving the side boundary
		move.w	#0,obSubpixelX(a0)			; clear subpixel portion
		move.w	#0,obVelX(a0)				; clear X-velocity
		move.w	#0,obInertia(a0)			; clear ground speed
		bra.s	.chkbottom				; check for bottom boundary collision as well
; ===========================================================================

	if FixBugs
; Jump-redirect to the KillSonic subroutine, as it otherwise results in an out-of-range error
; just from enabling FixBugs. This is also a very common beginner's trap
JumpTo_KillSonic:
		jmp	(KillSonic).l				; kill Sonic
	endif
; End of function Sonic_LevelBound


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to roll when he's moving
; ---------------------------------------------------------------------------

Sonic_Roll:
		tst.b	(f_slidemode).w				; is Sonic currently on a water slide?
		bne.s	.noroll					; if yes, don't allow rolling

		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		bpl.s	.ispositive				; is it positive? if yes, branch
		neg.w	d0					; otherwise, make it positive
; loc_13392:
.ispositive:
		cmpi.w	#$80,d0					; is Sonic moving at $80 speed or faster?
		blo.s	.noroll					; if not, branch
		move.b	(v_jpadhold2).w,d0			; get held buttons
		andi.b	#btnL+btnR,d0				; is left/right being held?
		bne.s	.noroll					; if yes, prevent rolling (some kind of fat-fingering convenience feature?)
		btst	#bitDn,(v_jpadhold2).w			; is down being held?
		bne.s	Sonic_ChkRoll				; if yes, branch

; Obj01_NoRoll:
.noroll:
		rts						; return
; ===========================================================================

; Obj01_ChkRoll:
Sonic_ChkRoll:
		btst	#status_rolling_bit,obStatus(a0)		; is Sonic already rolling?
		beq.s	.roll					; if not, branch to initiate a roll
		rts						; otherwise, do nothing
; ===========================================================================

; Obj01_DoRoll:
.roll:
		bset	#status_rolling_bit,obStatus(a0)	; set rolling flag
		move.b	#sonic_roll_height,obHeight(a0)		; set Sonic's hitbox height to rolling size
		move.b	#sonic_roll_width,obWidth(a0)		; set Sonic's hitbox width to rolling size
		move.b	#id_Roll,obAnim(a0)			; use "rolling" animation
	if FixBugs
		; Sonic_Animate doesn't take effect until one frame later, causing
		; him to briefly enter his standing animation when at a stop. We'll
		; fix this by forcing him into his first rolling frame.
		move.b	#fr_Roll1,obFrame(a0)			; force Sonic into his first rolling frame
	endif
		addq.w	#sonic_height-sonic_roll_height,obY(a0)	; adjust Y-position to align Sonic to the floor
		move.w	#sfx_Roll,d0				; set rolling sound
		jsr	(QueueSound2).l				; play it

		tst.w	obInertia(a0)				; is current speed zero?
		bne.s	.ismoving				; if not, branch
		move.w	#$200,obInertia(a0)			; force forward movement (this is used for the S-tunnels in GHZ to not get stuck)

; locret_133E8:
.ismoving:
		rts						; return
; End of function Sonic_Roll

Sonic_Unroll:
		btst	#bitUp,(v_jpadpress2).w
		beq.s	.return
		clr.b	obAnim(a0)
		bclr	#status_rolling_bit,obStatus(a0)	; clear ball flag
		move.b	#sonic_height,obHeight(a0)		; set Sonic's hitbox height to standing
		move.b	#sonic_width,obWidth(a0)		; set Sonic's hitbox width to standing
		subq.w	#sonic_height-sonic_roll_height,obY(a0)	; raise Sonic up 5 pixels so he's not inside the ground

.return:
		rts

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to jump
; ---------------------------------------------------------------------------

Sonic_Jump:
		move.b	(v_jpadpress2).w,d0			; get pressed buttons
		andi.b	#btnC,d0				; is C pressed? (jump button)
		beq.w	.return					; if not, branch

		moveq	#0,d0					; clear d0
		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$80,d0					; rotate 180 degrees for ceiling collision check
		bsr.w	Sonic_CalcHeadroom			; calculate pixels above Sonic's head
		cmpi.w	#6,d1					; are there less than 6px between Sonic and the ceiling?
		blt.w	.return					; if yes, prevent jumping

		move.w	#son_jumpspeed,d2	; set initial jump force
		tst.b	(v_supersonic).w	; is Sonic Super?
		beq.s	.notsuper		; if not, skip
		move.w	#son_jumpspeed+$180,d2		; Super Sonic jumps higher
.notsuper:
		btst	#6,obStatus(a0)	; is Sonic underwater?
		beq.s	.notunderwater
		move.w	#$380,d2	; set underwater jump force
.notunderwater:
		moveq	#0,d0					; clear d0
		move.b	obAngle(a0),d0				; get Sonic's current angle
		subi.b	#$40,d0					; rotate it perpendicularly for jump trajectory
		jsr	(CalcSine).l				; find the direction Sonic should jump
		muls.w	d2,d1					; apply jump force to the cosine angle
		asr.l	#8,d1					; shift it to upper word
		add.w	d1,obVelX(a0)				; apply to X speed
		muls.w	d2,d0					; apply jump force to the sine angle
		asr.l	#8,d0					; shift it to upper word
		add.w	d0,obVelY(a0)				; apply to Y speed
		bset	#status_in_air_bit,obStatus(a0)		; set in-air flag
		bclr	#status_pushing_bit,obStatus(a0)	; clear pushing flag
		addq.l	#4,sp					; run in-air subroutines when we return
		move.b	#1,jumping(a0)				; set jump flag
		clr.b	sticktoconvex(a0)			; detach Sonic from the gears in SBZ
		move.w	#sfx_Jump,d0				; set jump sound
		jsr	(QueueSound2).l				; play jumping sound
	if (FixBugs=0)&(UnusedOptimization=0)
		; This sets Sonic's hitbox to standing size when roll-jumping.
		; A leftover from the victory animation in prototypes.
		move.b	#sonic_height,obHeight(a0)		; set height to standing size
		move.b	#sonic_width,obWidth(a0)		; set width to standing size
	endif

		btst	#status_rolling_bit,obStatus(a0)	; is Sonic already in a ball state?
		bne.s	.return				; if so, branch
		move.b	#sonic_roll_height,obHeight(a0)		; set height to rolling size
		move.b	#sonic_roll_width,obWidth(a0)		; set width to rolling size
		move.b	#id_Roll,obAnim(a0)			; use "jumping" animation
		bset	#status_rolling_bit,obStatus(a0)	; set rolling flag
		addq.w	#sonic_height-sonic_roll_height,obY(a0)	; adjust Y-position to align Sonic to the floor

; locret_1348E:
.return:
		rts						; return

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine controlling Sonic's jump height/duration
; ---------------------------------------------------------------------------

Sonic_JumpHeight:
		tst.b	jumping(a0)				; is Sonic airborne specifically from a jump?
		beq.s	.capyvel				; if not, just cap Y speed normally
		move.w	#-$400,d1				; set max jump height
		btst	#status_underwater_bit,obStatus(a0)	; is Sonic underwater?
		beq.s	.notunderwater				; if not, continue
		move.w	#-$200,d1				; set underwater jump height

; loc_134AE:
.notunderwater:
		cmp.w	obVelY(a0),d1				; get current y speed
		ble.s	.return					; is Sonic moving up slower than the cap speed? if yes, branch
		move.b	(v_jpadhold2).w,d0			; get currently held buttons
		andi.b	#btnC,d0				; is C still held after jumping?
		bne.s	.return					; if yes, branch
		move.w	d1,obVelY(a0)				; otherwise, cap Sonic's maximum jump height

; locret_134C2:
.return:
	if FixBugs=0
		; This prevents the max Y-vel cap from running while jumping
		rts						; return
	endif
; ===========================================================================

; loc_134C4:
.capyvel:
		cmpi.w	#-$FC0,obVelY(a0)			; is Sonic moving up just below the maximum screen scroll speed? (-$1000)
		bge.s	.return2				; if not, branch
		move.w	#-$FC0,obVelY(a0)			; force Sonic to stay below maximum screen scroll speed

; locret_134D2:
.return2:
	if FixBugs
		; The above vertical speed cap doesn't account for falling
		cmpi.w	#$FC0,obVelY(a0)			; is Sonic moving down just below the maximum screen scroll speed? ($1000)
		ble.s	.return3				; if not, branch
		move.w	#$FC0,obVelY(a0)			; force Sonic to stay below maximum screen scroll speed
.return3:
	endif
		rts						; return
; End of function Sonic_JumpHeight


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to adjust Sonic's speed while walking up/down slopes
; ---------------------------------------------------------------------------

; Sonic_SlopeResist:
Sonic_SlopeResistWalk:
		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$60,d0					; rotate it by 135 degrees
		cmpi.b	#$C0,d0					; is Sonic on a steep enough slope?
		bhs.s	.return					; if no, don't do slope resist

		move.b	obAngle(a0),d0				; get Sonic's current angle
		jsr	(CalcSine).l				; get sine and cosine values for angle
		muls.w	#$20,d0					; multiply by resist force while walking
		asr.l	#8,d0					; shift down a byte

		tst.w	obInertia(a0)				; check Sonic's ground speed
		beq.s	.return					; if he's standing still, branch
		bmi.s	.left					; if he's walking leftward, branch
		tst.w	d0					; is resist force zero?
		beq.s	.noresist				; if yes, branch
		add.w	d0,obInertia(a0)			; add resist force to Sonic's speed while walking up a right slope

; locret_13502:
.noresist:
		rts						; return
; ===========================================================================

; loc_13504:
.left:
		add.w	d0,obInertia(a0)			; add resist force to Sonic's speed while walking up a left slope

; locret_13508:
.return:
		rts						; return
; End of function Sonic_SlopeResist


; ---------------------------------------------------------------------------
; ; Subroutine to adjust Sonic's speed while rolling up/down slopes
; ---------------------------------------------------------------------------

; Sonic_RollRepel:
Sonic_SlopeResistRoll:
		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$60,d0					; rotate it by 135 degrees
		cmpi.b	#$C0,d0					; is Sonic on a steep enough slope?
		bhs.s	.return					; if no, don't do slope resist

		move.b	obAngle(a0),d0				; get Sonic's current angled
		jsr	(CalcSine).l				; get sine and cosine values for angle
		muls.w	#$50,d0					; multiply by resist force while rolling (2.5x larger than walking)
		asr.l	#8,d0					; shift down a byte

		tst.w	obInertia(a0)				; check Sonic's current ground speed
		bmi.s	.left					; he's rolling to the left, branch
		tst.w	d0					; is resist force zero or positive?
		bpl.s	.resistright				; if yes, branch (descending from slope rolls faster)
		asr.l	#2,d0					; reduce resist force while ascending a slope

; loc_13534:
.resistright:
		add.w	d0,obInertia(a0)			; add resist force to Sonic's speed while rolling up a right slope
		rts						; return
; ===========================================================================

; loc_1353A:
.left:
		tst.w	d0					; is resist force negative?
		bmi.s	.resistleft				; if yes, branch (descending from slope rolls faster)
		asr.l	#2,d0					; reduce resist force while ascending a slope

; loc_13540:
.resistleft:
		add.w	d0,obInertia(a0)			; add resist force to Sonic's speed while walking up a left slope

; locret_13544:
.return:
		rts						; return
; End of function Sonic_RollRepel


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to detach Sonic from steep slopes if he's too slow
; ---------------------------------------------------------------------------

Sonic_SlopeRepel:
		nop						; (probably replaced with an rts during development to stick to walls)
		tst.b	sticktoconvex(a0)			; is Sonic on an SBZ gear?
		bne.s	.return					; if yes, branch
		tst.w	locktime(a0)				; are left/right controls temporarily locked?
		bne.s	.decrementlocktime			; if yes, branch

		move.b	obAngle(a0),d0				; get Sonic's current angle
		addi.b	#$20,d0					; rotate it by 45 degrees
		andi.b	#$C0,d0					; snap to nearest multiple of 90 degrees
		beq.s	.return					; if Sonic is not on a wall or ceiling, branch

		move.w	obInertia(a0),d0			; get Sonic's current ground speed
		bpl.s	.posinertia				; is it positive? if yes, branch
		neg.w	d0					; otherwise, make it positive

; loc_1356A:
.posinertia:
		cmpi.w	#$280,d0				; is Sonic's ground speed high enough?
		bhs.s	.return					; if yes, branch
		clr.w	obInertia(a0)				; clear ground speed
		bset	#status_in_air_bit,obStatus(a0)		; set in-air flag to detach Sonic from wall
		move.w	#30,locktime(a0)			; disable left/right input for half a second

; locret_13580:
.return:
		rts						; return
; ===========================================================================

; loc_13582:
.decrementlocktime:
		subq.w	#1,locktime(a0)				; decrement left/right disable timer
		rts						; return
; End of function Sonic_SlopeRepel


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to return Sonic's angle to 0 as he jumps
; ---------------------------------------------------------------------------

Sonic_JumpAngle:
		move.b	obAngle(a0),d0				; get Sonic's angle
		beq.s	.return					; if already 0, branch
		bpl.s	.decrease				; if higher than 0, branch
		addq.b	#2,d0					; increase angle
		bcc.s	.dontclear				; if the angle's still below 0, don't clear the angle
		moveq	#0,d0					; set angle to d0

; loc_13596:
.dontclear:
		bra.s	.applyangle				; skip over to update angle
; ===========================================================================

; loc_13598:
.decrease:
		subq.b	#2,d0					; decrease angle
		bcc.s	.applyangle				; if the angle's still above 0, don't clear the angle
		moveq	#0,d0					; set angle to 0

; loc_1359E:
.applyangle:
		move.b	d0,obAngle(a0)				; set new angle value

; locret_135A2:
.return:
		rts						; return
; End of function Sonic_JumpAngle


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic to interact with the floor after jumping/falling.
; To save on resources, the game will only check one out of four quadrants,
; depending on which direction Sonic moving toward the most.
; This routine contains various writes to unused variables, likely used
; during development to debug the collision system while in air.
; ---------------------------------------------------------------------------

Sonic_Floor:
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	SonAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	Sonic_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	Sonic_FloorRight			; if so, branch
		bra.w	Sonic_FloorUp				; we are moving upwards
; ===========================================================================

SonAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	Sonic_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	Sonic_FloorLeft				; if so, branch
		; otherwise, we know we're falling down (fall-through...)


; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being downward
; ---------------------------------------------------------------------------

Sonic_FloorDown:
		bsr.w	Sonic_FindWallLeft_Quick_UsePos		; check Sonic's distance to nearest left wall
		tst.w	d1					; is Sonic grazing a wall to the left while falling?
		bpl.s	.noleftgraze				; if not, branch
		sub.w	d1,obX(a0)				; align Sonic with the wall
		move.w	#0,obVelX(a0)				; clear horizontal speed

; loc_135F0:
.noleftgraze:
		bsr.w	Sonic_FindWallRight_Quick_UsePos	; check Sonic's distance to nearest right wall
		tst.w	d1					; is Sonic grazing a wall to the right while falling?
		bpl.s	.norightgraze				; if not, branch
		add.w	d1,obX(a0)				; align Sonic with the wall
		move.w	#0,obVelX(a0)				; clear horizontal speed

; loc_13602:
.norightgraze:
		bsr.w	Sonic_FindFloor				; find distance between Sonic and floor
	if UnusedOptimization=0
		move.b	d1,(v_unused6).w			; (unused) store distance to floor
	endif
		tst.w	d1					; has Sonic touched the floor again?
	if FixBugs=0
		bpl.s	.return					; if not, branch
	else
		bpl.w	.return					; if not, branch

		; The floor depth check should only be done if the floor is top solid,
		; not fully solid. Otherwise, if Sonic manages to clip into a fully
		; solid floor (i.e. the Lava Reef Zone stairs clip in Sonic & Knuckles),
		; Sonic could potentially fall right through.

		; Note that modifications to FindWall, FindFloor, Sonic_FindFloor,
		; Sonic_FindWallRight, Sonic_FindCeiling, Sonic_FindWallLeft, and
		; Sonic_FindSmaller are needed for this fix to work.
		btst	#$E,d4					; is the floor fully solid?
		bne.s	.landed					; if so, branch
	endif
		move.b	obVelY(a0),d2				; get Sonic's fall speed at the time of impact (upper byte only, pixel delta)
		addq.b	#8,d2					; increase it by one tile
		neg.b	d2					; mirror it
		cmp.b	d2,d1					; is result bigger than distance to floor?
		bge.s	.landed					; if yes, branch
		cmp.b	d2,d0					; is result bigger than distance to floor? (sloped variant)
		blt.s	.return					; if not, branch

; loc_1361E:
.landed:
		add.w	d1,obY(a0)				; fix Sonic to floor
		move.b	d3,obAngle(a0)				; update Sonic's angle for the landed-on floor
		bsr.w	Sonic_ResetOnFloor			; reset various flags and states back to standing state
		move.b	#id_Walk,obAnim(a0)			; set to "walking" animation

	if FixBugs
		; Fix angle inconsistencies on sloped surfaces
		move.b	d3,d0					; get floor angle
		bpl.s	.checkupper				; if it's in the left half, branch
		neg.b	d0					; if if's in the right half, mirror it
	.checkupper:
		btst	#6,d0					; is it in the lower half?
		beq.s	.checkslope				; if so, branch
		subi.b	#$80,d0					; if it's in the upper half...
		neg.b	d0					; ...mirror it
	.checkslope:
		cmpi.b	#$20,d0					; are we landing on a steep slope?
		bhs.s	.steepslope				; if so, branch
		cmpi.b	#$11,d0					; are we landing on a shallow slope?
		blo.s	.flatsurface				; if not, branch
	else
		move.b	d3,d0					; get landing angle
		addi.b	#$20,d0					; rotate it by 45 degrees clockwise
		andi.b	#$40,d0					; are we landing on a steep slope?
		bne.s	.steepslope				; if yes, branch
		move.b	d3,d0					; get landing angle
		addi.b	#$10,d0					; rotate it by 22.5 degrees clockwise
		andi.b	#$20,d0					; are we landing on a shallow slope?
		beq.s	.flatsurface				; if not, branch
	endif
		asr.w	obVelY(a0)				; halve Sonic's vertical speed when landing on a shallow slope
		bra.s	.noslopecap				; skip over
; ===========================================================================

; loc_1364E:
.flatsurface:
		move.w	#0,obVelY(a0)				; completely clear Sonic's vertical speed when landing on a flat surface
		move.w	obVelX(a0),obInertia(a0)		; convert in-air horizontal speed to ground speed when landing
		rts						; return
; ===========================================================================

; loc_1365C:
.steepslope:
		move.w	#0,obVelX(a0)				; completely clear Sonic's horizontal speed when landing on a steep slope
		cmpi.w	#$FC0,obVelY(a0)			; is Sonic's fall speed almost at the maximum screen shift speed?
		ble.s	.noslopecap				; if not, branch
		move.w	#$FC0,obVelY(a0)			; otherwise, cap it to not exceed maximum screen shift speed

; loc_13670:
.noslopecap:
		move.w	obVelY(a0),obInertia(a0)		; convert in-air vertical speed to ground speed when landing
		tst.b	d3					; is slope (when viewed left-to-right in game) ascending?
		bpl.s	.return					; if not, branch
		neg.w	obInertia(a0)				; negate converted ground speed for ascending slopes

; locret_1367E:
.return:
		rts						; return
; End of function Sonic_FloorDown


; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being to the left
; ---------------------------------------------------------------------------

; loc_13680:
Sonic_FloorLeft:
		bsr.w	Sonic_FindWallLeft_Quick_UsePos		; check Sonic's distance to nearest left wall
		tst.w	d1					; is Sonic grazing a wall to the left while falling?
		bpl.s	.noleftgraze				; if not, branch
		sub.w	d1,obX(a0)				; align Sonic to the wall
		move.w	#0,obVelX(a0)				; clear horizontal speed
		move.w	obVelY(a0),obInertia(a0)		; convert in-air vertical speed to ground speed when landing
		rts						; return
; ===========================================================================

; loc_1369A:
.noleftgraze:
		bsr.w	Sonic_FindCeiling			; check if Sonic's distance to the ceiling
		tst.w	d1					; is Sonic touching the ceiling?
		bpl.s	.noceiling				; if not, branch
		sub.w	d1,obY(a0)				; align Sonic with the ceiling
		tst.w	obVelY(a0)				; is vertical speed positive? (going down)
		bpl.s	.noyspeedreset				; if yes, branch
		move.w	#0,obVelY(a0)				; if going up, reset it to zero

; locret_136B2:
.noyspeedreset:
		rts						; return
; ===========================================================================

; loc_136B4:
.noceiling:
		tst.w	obVelY(a0)				; is Sonic going up?
		bmi.s	.return					; if yes, branch
		bsr.w	Sonic_FindFloor				; find Sonic's distance to floor
		tst.w	d1					; has Sonic touched the floor?
		bpl.s	.return					; if not, branch
	if FixBugs
		; See explanation in .norightgraze under Sonic_FloorDown
		btst	#$E,d4					; is the floor fully solid?
		bne.s	.landed					; if so, branch

		; When Sonic is moving down and a floor collision is detected, there exists
		; a check that makes it so that he doesn't clip on top of a surface that
		; he's too far below from. However, said check doesn't exist for when Sonic
		; is moving left or right. The effects of this can easily be seen if you
		; place a solid object on a top solid surface and hit the object from the bottom,
		; where Sonic's Y movement will be cancelled out, causing him to start checking
		; for floor collision, which makes him clip onto the surface.
		move.b	obVelY(a0),d2				; get Sonic's fall speed at the time of impact (upper byte only, pixel delta)
		addq.b	#8,d2					; increase it by one tile
		neg.b	d2					; mirror it
		cmp.b	d2,d1					; is result bigger than distance to floor?
		bge.s	.landed					; if yes, branch
		cmp.b	d2,d0					; is result bigger than distance to floor? (sloped variant)
		blt.s	.return					; if not, branch

.landed:
	endif
		add.w	d1,obY(a0)				; align Sonic with floor
		move.b	d3,obAngle(a0)				; update Sonic's angle for the landed-on floor
		bsr.w	Sonic_ResetOnFloor			; reset various flags and states back to standing state
		move.b	#id_Walk,obAnim(a0)			; set to "walking" animation
		move.w	#0,obVelY(a0)				; completely clear Sonic's vertical speed when landing on a flat surface
		move.w	obVelX(a0),obInertia(a0)		; convert in-air horizontal speed to ground speed when landing

; locret_136E0:
.return:
		rts						; return
; End of function Sonic_FloorLeft


; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being upward
; ---------------------------------------------------------------------------

; loc_136E2:
Sonic_FloorUp:
		bsr.w	Sonic_FindWallLeft_Quick_UsePos		; check Sonic's distance to nearest left wall
		tst.w	d1					; is Sonic grazing a wall to the left while going up?
		bpl.s	.noleftgraze				; if not, branch
		sub.w	d1,obX(a0)				; align Sonic to wall
		move.w	#0,obVelX(a0)				; clear horizontal speed

; loc_136F4:
.noleftgraze:
		bsr.w	Sonic_FindWallRight_Quick_UsePos	; check Sonic's distance to nearest right wall
		tst.w	d1					; is Sonic grazing a wall to the right while going up?
		bpl.s	.norightgraze				; if not, branch
		add.w	d1,obX(a0)				; align Sonic to wall
		move.w	#0,obVelX(a0)				; clear horizontal speed

; loc_13706:
.norightgraze:
		bsr.w	Sonic_FindCeiling			; find Sonic's distance to the ceiling
		tst.w	d1					; is Sonic touching the ceiling?
		bpl.s	.return					; if not, branch
		sub.w	d1,obY(a0)				; align Sonic with the ceiling
		move.b	d3,d0					; get Sonic's landing angle
		addi.b	#$20,d0					; rotate it by 45 degrees
		andi.b	#$40,d0					; are we bumping against an angled ceiling?
		bne.s	.angledceiling				; if yes, branch
		move.w	#0,obVelY(a0)				; clear vertical speed when bumping against a flat ceiling
		rts						; return
; ===========================================================================

; loc_13726:
.angledceiling:
		move.b	d3,obAngle(a0)				; update Sonic's angle for the landed-on floor
		bsr.w	Sonic_ResetOnFloor			; reset various flags and states back to standing state
		move.w	obVelY(a0),obInertia(a0)		; convert in-air vertical speed to ground speed when landing
		tst.b	d3					; is slope (when viewed left-to-right in game) ascending?
		bpl.s	.return					; if not, branch
		neg.w	obInertia(a0)				; negate converted ground speed for ascending slopes

; locret_1373C:
.return:
		rts						; return
; End of function Sonic_FloorUp


; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being towards the right
; ---------------------------------------------------------------------------

; loc_1373E:
Sonic_FloorRight:
		bsr.w	Sonic_FindWallRight_Quick_UsePos	; check Sonic's distance to nearest right wall
		tst.w	d1					; is Sonic grazing a wall to the right while falling?
		bpl.s	.norightgraze				; if not, branch
		add.w	d1,obX(a0)				; align Sonic to the wall
		move.w	#0,obVelX(a0)				; clear horizontal speed
		move.w	obVelY(a0),obInertia(a0)		; convert in-air vertical speed to ground speed when landing
		rts						; return
; ===========================================================================

; loc_13758:
.norightgraze:
		bsr.w	Sonic_FindCeiling			; check if Sonic's distance to the ceiling
		tst.w	d1					; is Sonic touching the ceiling?
		bpl.s	.noceiling				; if not, branch
		sub.w	d1,obY(a0)				; align Sonic with the ceiling
		tst.w	obVelY(a0)				; is vertical speed positive? (going down)
		bpl.s	.noyspeedreset				; if yes, branch
		move.w	#0,obVelY(a0)				; if going up, reset it to zero

; locret_13770:
.noyspeedreset:
		rts						; return
; ===========================================================================

; loc_13772:
.noceiling:
		tst.w	obVelY(a0)				; is Sonic going up?
		bmi.s	.return					; if yes, branch
		bsr.w	Sonic_FindFloor				; find Sonic's distance to floor
		tst.w	d1					; has Sonic touched the floor?
		bpl.s	.return					; if not, branch
	if FixBugs
		; See explanation in .norightgraze under Sonic_FloorDown
		btst	#$E,d4					; is the floor fully solid?
		bne.s	.landed					; if so, branch

		; See explanation in .noceiling under Sonic_FloorLeft
		move.b	obVelY(a0),d2				; get Sonic's fall speed at the time of impact (upper byte only, pixel delta)
		addq.b	#8,d2					; increase it by one tile
		neg.b	d2					; mirror it
		cmp.b	d2,d1					; is result bigger than distance to floor?
		bge.s	.landed					; if yes, branch
		cmp.b	d2,d0					; is result bigger than distance to floor? (sloped variant)
		blt.s	.return					; if not, branch

.landed:
	endif
		add.w	d1,obY(a0)				; align Sonic with floor
		move.b	d3,obAngle(a0)				; update Sonic's angle for the landed-on floor
		bsr.w	Sonic_ResetOnFloor			; reset various flags and states back to standing state
		move.b	#id_Walk,obAnim(a0)			; set to "walking" animation
		move.w	#0,obVelY(a0)				; completely clear Sonic's vertical speed when landing on a flat surface
		move.w	obVelX(a0),obInertia(a0)		; convert in-air horizontal speed to ground speed when landing

; locret_1379E:
.return:
		rts						; return
; End of function Sonic_FloorRight
; End of function Sonic_Floor (as a whole)


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to reset Sonic's mode when he lands on the floor
; ---------------------------------------------------------------------------

Sonic_ResetOnFloor:
		clr.b	(v_hyperdash_flag).w			; landed: the Hyper Dash is available again
		clr.b	(v_hyperattack_pending).w
;		btst	#status_rolljumping_bit,obStatus(a0)	; is Sonic roll-jumping?
;		beq.s	.notrolljump				; if not, skip
;		nop						; unknown removed code
;		nop						; (some extra feature of the roll-jump lock?)
;		nop						; (we will never know...)
;
; loc_137AE:
;.notrolljump:
		bclr	#status_pushing_bit,obStatus(a0)	; clear push flag
		bclr	#status_in_air_bit,obStatus(a0)		; clear in-air flag
;		bclr	#status_rolljumping_bit,obStatus(a0)	; clear roll-jump flag
	if FixBugs
		; This line was placed too late into the routine,
		; occasionally causing Sonic "sliding" on the floor
		move.b	#id_Walk,obAnim(a0)			; use running/walking animation
	endif
		btst	#status_rolling_bit,obStatus(a0)	; check if Sonic is in a ball state
		beq.s	.notball				; if not, skip
		bclr	#status_rolling_bit,obStatus(a0)	; clear ball flag
		move.b	#sonic_height,obHeight(a0)		; set Sonic's hitbox height to standing
		move.b	#sonic_width,obWidth(a0)		; set Sonic's hitbox width to standing
	if FixBugs=0
		move.b	#id_Walk,obAnim(a0)			; use running/walking animation
	endif
		subq.w	#sonic_height-sonic_roll_height,obY(a0)	; raise Sonic up 5 pixels so he's not inside the ground

; loc_137E4:
.notball:
		move.b	#0,jumping(a0)				; clear jump flag
		move.w	#0,(v_itembonus).w			; clear enemy score chain
		rts						; return
; End of function Sonic_ResetOnFloor


; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he gets hurt
; ---------------------------------------------------------------------------

; Obj01_Hurt:
Sonic_Hurt:	; Routine 4
	if FixBugs
		; Fix not being able to enter debug mode from a hurt state.
		; This was added for Sonic 2.
		tst.w	(f_debugmode).w				; is debug cheat enabled?
		beq.s	.nodebug				; if not, branch
		btst	#bitB,(v_jpadpress1).w			; is button B pressed?
		beq.s	.nodebug				; if not, branch
		move.w	#1,(v_debuguse).w			; enter debug mode on the next frame (change Sonic into a ring/item)
		clr.b	(f_lockctrl).w				; unlock controls
		rts						; return
.nodebug:
	endif

		jsr	(SpeedToPos).l				; update Sonic's current position based on his velocities
		addi.w	#gravity-8,obVelY(a0)			; apply gravity (this is 8 less than the normal gravity of $38)
		btst	#status_underwater_bit,obStatus(a0)	; is Sonic underwater?
		beq.s	.notunderwater				; if not, branch
		subi.w	#gravity-$18,obVelY(a0)			; reduce gravity to be only $10 while underwater
; loc_1380C:
.notunderwater:
		bsr.w	Sonic_HurtStop				; check if Sonic has landed again after taking damage and revert to normal state
	if FixBugs
		; Fix water not being acknowledged during a hurt state
		bsr.w	Sonic_Water				; handle Sonic while in water (LZ only)
	endif
		bsr.w	Sonic_LevelBound			; make sure Sonic stays within level bounds and handle bottomless pits
		bsr.w	Sonic_RecordPosition			; record Sonic's previous position for the invincibility stars trail
		bsr.w	Sonic_Animate				; run Sonic's animation scripts
		bsr.w	Sonic_LoadGfx				; update Sonic's graphics if necessary
		jmp	(DisplaySprite).l			; display Sonic's sprites
; End of function Sonic_Hurt


; ---------------------------------------------------------------------------
; Subroutine to stop Sonic falling after he's been hurt
; ---------------------------------------------------------------------------

Sonic_HurtStop:
		move.w	(v_limitbtm2).w,d0			; get current target bottom level boundary
	if FixBugs
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(v_limitbtm1).w,d1			; get current real bottom level boundary
		cmp.w	d0,d1					; is target bottom boundary lower than real one?
		blo.s	.skip					; if not, branch
		move.w	d1,d0					; use target bottom boundary for check to prevent unfair deaths
.skip:
	endif
		addi.w	#224,d0					; add screen height
		cmp.w	obY(a0),d0				; has Sonic touched the bottom level boundary?
	if FixBugs
		blt.w	JumpTo_KillSonic			; if yes, kill Sonic (signed check to not die while leaving the top screen)
	else
		; This would cause Sonic to die from the upper/top boundary of the level, while in hurt state.
		; Also, the above branch goes out of range just from enabling FixBugs.
		blo.w	KillSonic				; if yes, kill Sonic (unsigned, this will kill Sonic if leaving the top screen)
	endif

		bsr.w	Sonic_Floor				; handle Sonic landing on the floor again
		btst	#status_in_air_bit,obStatus(a0)		; is Sonic still in the air?
		bne.s	.continuehurt				; if yes, branch

		moveq	#0,d0					; clear d0
		move.w	d0,obVelY(a0)				; set Y-speed to 0
		move.w	d0,obVelX(a0)				; set X-speed to 0
		move.w	d0,obInertia(a0)			; set ground speed to 0
		move.b	#id_Walk,obAnim(a0)			; set to walking animation
		subq.b	#2,obRoutine(a0)			; set routine back to Sonic_Control
		move.w	#2*60,flashtime(a0)			; set flash time to 2 seconds of invulnerability frames

; locret_13860:
.continuehurt:
		rts						; return
; End of function Sonic_HurtStop


; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he dies (triggered from "KillSonic" in ReactToItem and when drowning)
; ---------------------------------------------------------------------------

; Obj01_Death:
Sonic_Death:	; Routine 6
	if FixBugs
		; Fix not being able to enter debug mode from a dying state.
		; This was added for Sonic 2.
		tst.w	(f_debugmode).w				; is debug cheat enabled?
		beq.s	.nodebug				; if not, branch
		btst	#bitB,(v_jpadpress1).w			; is button B pressed?
		beq.s	.nodebug				; if not, branch
		move.w	#1,(v_debuguse).w			; enter debug mode on the next frame (change Sonic into a ring/item)
		clr.b	(f_lockctrl).w				; unlock controls
		rts						; return
.nodebug:
	endif

		bsr.w	Sonic_HandleDeath			; handle Sonic falling, deducting a life, and maybe triggering game over
		jsr	(ObjectFall).l				; apply gravity
		bsr.w	Sonic_RecordPosition			; record Sonic's previous position for the invincibility stars trail (kinda pointless here...)
		bsr.w	Sonic_Animate				; run Sonic's animation scripts
		bsr.w	Sonic_LoadGfx				; update Sonic's graphics if necessary
		jmp	(DisplaySprite).l			; display Sonic's sprite
; End of function Sonic_Death


; ---------------------------------------------------------------------------
; Subroutine to check if Sonic has gone below the screen after dying, and
; update lives, restart the level, and potentially run game over
; ---------------------------------------------------------------------------

; GameOver: <-- old misnomer (this routine ALSO handles game overs, but not just)
Sonic_HandleDeath:
	if FixBugs
		; Fix the death boundary bug
		; https://info.sonicretro.org/SCHG_How-to:Fix_the_death_boundary_bug
		move.w	(v_screenposy).w,d0			; get current Y screen position
		addi.w	#$100,d0				; go $100 pixels lower
		cmp.w	obY(a0),d0				; has Sonic's death animation gone below the screen?
		bge.w	.return					; if not, branch
	else
		move.w	(v_limitbtm2).w,d0			; get current bottom boundary position
		addi.w	#$100,d0				; go $100 pixels lower
		cmp.w	obY(a0),d0				; has Sonic's death animation gone below the screen?
		bhs.w	.return					; if not, branch
	endif

		; Bottom reached, remove a life and check if game over was triggered
		move.w	#-gravity,obVelY(a0)			; set to -$38 to cancel ObjectFall gravity (freeze Sonic in place)
		addq.b	#2,obRoutine(a0)			; go to Sonic_ResetLevel
		; Keep the stage timer running during the death delay and respawn.
		addq.b	#1,(f_lifecount).w			; update lives counter
		; speed level is kept on death (no decrement): Sonic respawns at the level start or at the last checkpoint
		bra.s	.extraLivesRemaining			; always continue

		; GAME OVER
		move.w	#0,restartime(a0)			; set to not restart the level
		move.b	#id_GameOverCard,(v_gameovertext1).w	; load GAME object
		move.b	#id_GameOverCard,(v_gameovertext2).w	; load OVER object
		move.b	#1,(v_gameovertext2+obFrame).w		; set OVER object to correct frame
		clr.b	(f_timeover).w				; clear time over flag
	if FixBugs
		; If a Game Over is triggered while the title cards aren't fully unloaded yet,
		; the objects make fail to initialize properly as they share the same ROM space.
		clr.b	(v_gameovertext1+obRoutine).w		; make sure "GAME"/"TIME" object initializes properly
		clr.b	(v_gameovertext2+obRoutine).w		; make sure "OVER" object initializes properly
	endif

; loc_138C2:
.gameOverBgmAndPatterns:
		move.w	#bgm_GameOver,d0			; set GAME OVER music
		jsr	(QueueSound1).l				; play it
		moveq	#plcid_GameOver,d0			; set game over patterns
		jmp	(AddPLC).l				; load them
; ===========================================================================

; loc_138D4:
.extraLivesRemaining:
		move.w	#60,restartime(a0)			; set reset level delay to 1 second
		tst.b	(f_timeover).w				; is TIME OVER tag set?
		beq.s	.return					; if not, branch
		move.w	#0,restartime(a0)			; set to not restart the level
		move.b	#id_GameOverCard,(v_gameovertext1).w	; load GAME object
		move.b	#id_GameOverCard,(v_gameovertext2).w	; load OVER object
		move.b	#2,(v_gameovertext1+obFrame).w		; set GAME frame to TIME
		move.b	#3,(v_gameovertext2+obFrame).w		; set OVER frame to OVER (different frame ID, but looks identical)
		bra.s	.gameOverBgmAndPatterns			; play music and load patterns
; ===========================================================================

; locret_13900:
.return:
		rts						; return
; End of function Sonic_HandleDeath


; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic after having died and fallen off the bottom of the screen
; ---------------------------------------------------------------------------

; Obj01_ResetLevel:
Sonic_ResetLevel: ; Routine 8
		tst.w	restartime(a0)				; was no restart time set? (game over / time over)
		beq.s	.return					; if yes, don't restart level
		subq.w	#1,restartime(a0)			; subtract 1 from time delay
		bne.s	.return					; if time remains, branch
		bsr.w	Sonic_Respawn				; respawn Sonic (no level reload)

; locret_13914:
.return:
		rts						; return
; End of function Sonic_ResetLevel


; ---------------------------------------------------------------------------

Sonic_Respawn:
		tst.b	(f_timeover).w				; time over? the level is reloaded, as before
		beq.s	.respawn
		move.w	#1,(f_restart).w
		rts
.respawn:
		tst.w	(v_air).w				; drowned? (air went below 0): the variables reset, the level does not restart
		bpl.s	.notdrown
		jsr	(Sonic_RestoreLevelMusic).l		; the level's music again
		bra.s	.shoesdone
.notdrown:
		tst.b	(v_shoes).w				; speed shoes were on when Sonic died: the Slowdown music
		beq.s	.shoesdone
		move.w	#bgm_Slowdown,d0
		jsr	(QueueSound1).l
.shoesdone:
		; Only while the boss is active (arena locked, f_lockscreen): respawn at that arena's fixed position.
		; Outside the boss fight the respawn is the normal one (lamppost / start).
		tst.b	(f_lockscreen).w				; boss fight active?
		beq.s	.notboss
		move.w	(v_zone_act).w,d0
		lea	(Sonic_BossRespawnPos).l,a1
.bossfind:
		move.w	(a1)+,d1
		bmi.s	.notboss					; end of the table: not a boss act
		cmp.w	d0,d1
		beq.s	.bossfound
		addq.w	#4,a1					; next entry
		bra.s	.bossfind
.bossfound:
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		clr.w	(v_rings).w				; rings are not restored at the boss respawn
		bra.w	.setstate
.notboss:
		tst.b	(v_lastlamp).w				; respawning from a lamppost?
		beq.s	.start
		move.w	(v_lamp_xpos).w,obX(a0)
		move.w	(v_lamp_ypos).w,obY(a0)
		clr.w	(v_rings).w				; rings are not restored at the checkpoint
		; Do not roll the timer back to the value saved at the lamppost.
		bra.s	.setstate
.start:
		move.w	(v_respawn_x).w,obX(a0)
		move.w	(v_respawn_y).w,obY(a0)
		clr.w	(v_rings).w
		; Preserve elapsed time even when respawning at the initial position.
.setstate:
		move.b	#1,(v_respawn_zoneblock).w		; respawned: the zone-end trigger waits until Sonic leaves its area
		bclr	#7,obGfx(a0)			; restore Sonic to normal (low) priority after respawn
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.w	obInertia(a0)
		move.b	#0,obStatus(a0)
		move.b	#id_Wait,obAnim(a0)		; S2SR: keep Sonic standing during every respawn instead of walking
		clr.b	(f_playerctrl).w			; clear drowning/object control override
		move.b	#1,(f_lockctrl).w			; lock player input until the camera finishes the respawn scroll
		clr.b	(v_jpadhold2).w			; discard stale duplicated joypad state
		clr.b	(v_jpadpress2).w
		clr.b	(f_nobgscroll).w			; plane scrolling back on (it is turned off while drowning)
		move.w	#30,(v_air).w				; air refilled
		clr.w	(v_cam_x_delay).w			; discard any Spin Dash camera delay from before the death
		clr.b	(v_cam_y_delay).w			; discard any old look-up/down delay
		move.w	#$60,(v_lookshift).w			; restore the default vertical camera target
		clr.w	(v_scrshiftx).w			; discard stale horizontal camera delta from the death frame
		clr.w	(v_scrshifty).w			; discard stale vertical camera delta from the death frame
		move.b	#$0A,obRoutine(a0)			; wait in the camera-respawn state (Sonic 2 style)
		clr.w	restartime(a0)
		move.b	#1,(f_timecount).w			; the time counter runs again
		; reset what a level restart resets (Level_SkipClr), so nothing carries over from before the death
		tst.b	(v_supersonic).w				; was Super Sonic active?
		beq.s	.nosuper
		move.b	#2,(v_supersonic_palstate).w		; fade the Super palette back to normal
		move.b	#5*2*4,(v_supersonic_palframe).w
.nosuper:
		clr.b	(v_shield).w
		clr.b	(v_invinc).w				; no invincibility after respawning (as a level restart)
		clr.b	(v_invcheckdash).w			; stop the Dash Ring
		move.w	#$003C,(v_dashdrain_timer).w		; reset Speed Break timer like S2SR player init
		clr.b	(v_supersonic).w
		clr.b	(v_ssframe).w
		clr.b	(v_hyperdash_flag).w
		clr.b	(v_hyperflash_timer).w
		clr.b	(v_hyperflash_slowmo_frame).w
		clr.b	(v_hyperflash_hblank).w
		clr.b	(v_hyperattack_pending).w
		clr.b	(v_sonfall).w
		clr.b	(v_shoes).w				; speed shoes off
		clr.b	(v_starsobj1).w			; remove the invincibility stars
		clr.b	(v_starsobj2).w
		clr.b	(v_starsobj3).w
		clr.b	(v_starsobj4).w
		; Restore movement stats from the persistent speed level. This also
		; removes Super/Shoes modifiers without forcing level 1 defaults.
		bsr.w	Sonic_ApplyLevelStats		; preserve the current speed level after respawn
		; the invincibility timer is kept (it resumes when the Dash Ring makes Sonic invincible)
		move.b	#$80,(f_ringcount).w			; redraw the ring counter

		; no camera jump: the camera scrolls to Sonic at its normal speed (depends on his speed)
		rts
; End of function Sonic_Respawn

; Respawn positions in the boss acts (X, Y), from the level data
Sonic_BossRespawnPos:
		dc.w	id_GHZ_act3,$2983,$03AC
		dc.w	id_LZ_act3,$1C5D,$05EC
		dc.w	id_MZ_act3,$1834,$02AC
		dc.w	id_SYZ_act3,$2C2B,$055E
		dc.w	id_SLZ_act3,$2045,$02CC
		dc.w	id_LZ_act4,$2464,$05AC			; Scrap Brain 3 (final boss)
		dc.w	-1					; end of the table
		even

; ---------------------------------------------------------------------------
; Subroutine: the level music (the same list used after invincibility wears off;
; the boss music during a boss fight)
; ---------------------------------------------------------------------------

Sonic_RestoreLevelMusic:
		tst.b	(f_lockscreen).w				; boss fight?
		beq.s	.notboss
		move.w	#bgm_Boss,d0
		jmp	(QueueSound1).l
.notboss:
		moveq	#0,d0
		move.b	(v_zone).w,d0			; zone
		cmpi.w	#id_LZ_act4,(v_zone_act).w		; SBZ3 (LZ4) uses the SBZ music
		bne.s	.music
		moveq	#5,d0
.music:
		lea	(MusicList2).l,a1
		move.b	(a1,d0.w),d0
		jmp	(QueueSound1).l
; End of function Sonic_RestoreLevelMusic



; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to make Sonic run around loops (GHZ/SLZ).
; The visual effect of rendering Sonic behind the loop is handled through
; bit 6 in obRender, of which Sonic is the only object in the entire game
; to use it. The effect itself is handled in "FindNearestTile".
; ---------------------------------------------------------------------------

Sonic_Loops:
		cmpi.b	#id_SLZ,(v_zone).w			; is level SLZ?
		beq.s	.levelhasloops				; if yes, check for loop chunks
		tst.b	(v_zone).w				; is level GHZ?
		bne.w	.return					; if not, return (level has no loops, so no need to check for them)

; loc_13926: .isstarlight:
.levelhasloops:
		move.w	obY(a0),d0				; get Sonic's current Y-position
		lsr.w	#1,d0					; halve it (level layouts have FG and BG interlaced)
		andi.w	#$380,d0				; mask out irrelevant bits for Y-position
		move.b	obX(a0),d1				; get Sonic's current X-position
		andi.w	#$7F,d1					; mask out irrelevant bits for X-position
		add.w	d1,d0					; combine the two (this is now the index to get the current 256x256 chunk in the level)
		lea	(v_lvllayout_fg).w,a1			; load foreground level layout
		move.b	(a1,d0.w),d1				; load ID of 256x256 chunk Sonic is currently standing on

		cmp.b	(v_256roll1).w,d1			; is Sonic on a "roll tunnel" tile? (type A, entrance from the left)
		beq.w	Sonic_ChkRoll				; if yes, force Sonic into a rolling state
		cmp.b	(v_256roll2).w,d1			; is Sonic on a "roll tunnel" tile? (type B, exit to the right)
		beq.w	Sonic_ChkRoll				; if yes, force Sonic into a rolling state

		cmp.b	(v_256loop1).w,d1			; is Sonic on a loop tile? (type A, entering from/exiting to the left)
		beq.s	.chkifleft				; if yes, branch
		cmp.b	(v_256loop2).w,d1			; is Sonic on a loop tile? (type B, entering from/exiting to the right)
		beq.s	.chkifinair				; if yes, branch

		bclr	#sprite_looping_bit,obRender(a0)	; clear loop flag (return Sonic to high plane)
		rts
; ===========================================================================

; loc_13966:
.chkifinair:
		btst	#status_in_air_bit,obStatus(a0)		; is Sonic in the air?
		beq.s	.chkifleft				; if not, branch

		bclr	#sprite_looping_bit,obRender(a0)	; clear loop flag (return Sonic to high plane)
		rts
; ===========================================================================

; loc_13976:
.chkifleft:
		move.w	obX(a0),d2				; get Sonic's current X position
		cmpi.b	#44,d2					; is Sonic past the first couple pixels of the loop? (byte check)
		bhs.s	.chkifright				; if yes, branch

		bclr	#sprite_looping_bit,obRender(a0)	; clear loop flag (return Sonic to high plane)
		rts						; return
; ===========================================================================

; loc_13988:
.chkifright:
		cmpi.b	#224,d2					; is Sonic past the last couple pixels of the loop? (byte check)
		blo.s	.chkangle1				; if not, branch

		bset	#sprite_looping_bit,obRender(a0)	; set loop flag (send Sonic to low plane)
		rts						; return
; ===========================================================================

; loc_13996:
.chkangle1:
		btst	#sprite_looping_bit,obRender(a0) 	; is loop flag already set?
		bne.s	.chkangle2				; if yes, branch

		move.b	obAngle(a0),d1				; get Sonic's current angle
		beq.s	.return					; if Sonic is on the flat surface of the loop, branch
		cmpi.b	#$80,d1					; has Sonic crossed the apex of the loop (i.e. is he upside-down)?
		bhi.s	.return					; if yes, branch
		bset	#sprite_looping_bit,obRender(a0)	; set loop flag (send Sonic to low plane)
		rts						; return
; ===========================================================================

; loc_139B2:
.chkangle2:
		move.b	obAngle(a0),d1				; get Sonic's current angle
		cmpi.b	#$80,d1					; has Sonic crossed the apex of the loop (i.e. is he upside-down)?
		bls.s	.return					; if not, branch
		bclr	#sprite_looping_bit,obRender(a0)	; clear loop flag (return Sonic to high plane)

; locret_139C2:
.return:
		rts						; return
; End of function Sonic_Loops


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to animate Sonic's sprites
; ---------------------------------------------------------------------------

Sonic_Animate:
		tst.b	(v_sonfall).w			; is the fall sprite active?
		beq.s	.nofall				; if not, branch
		btst	#status_in_air_bit,obStatus(a0)	; still in the air?
		beq.s	.nofall				; if not, use normal animations
		cmpi.b	#id_Fall,obAnim(a0)		; still the fall animation? (not hurt/dead/spring)
		bne.s	.clearfall			; if not, forget the fall sprite
		move.b	obStatus(a0),d1			; get Sonic's status bitfield
		andi.b	#status_xflip,d1		; keep only the X-flip flag
		andi.b	#~(sprite_xflip|sprite_yflip),obRender(a0) ; clear X-flip and Y-flip render flags
		or.b	d1,obRender(a0)			; set new X-flip flag state
		
		; --- Verifica se é o Super Sonic para trocar o frame de queda ---
		tst.b	(v_supersonic).w		; o Super Sonic está ativado?
		bne.s	.issuperfall			; se sim, desvia para o frame do Super
		move.b	#fr_Fall,obFrame(a0)		; senão, usa o frame de queda normal do Sonic
		rts
.issuperfall:
		move.b	#fr_SuperFall,obFrame(a0)	; mostra o novo sprite de queda do Super Sonic
		rts
.clearfall:
		clr.b	(v_sonfall).w
.nofall:
		tst.w	(v_air).w				; is Sonic in the drowning state (air counter below zero)?
		bpl.s	.notdrowning				; if not, keep the current animation
		move.b	#id_Drown,obAnim(a0)		; keep the static drowning pose instead of a walking animation
.notdrowning:
		lea	(Ani_Sonic).l,a1			; load Sonic's animation scripts
		tst.b	(v_supersonic).w				; is Sonic Super?
		beq.s	.notsuper				; if not, branch
		lea	(Ani_SuperSonic).l,a1			; use Super Sonic's animation scripts
.notsuper:
		moveq	#0,d0					; clear d0
		move.b	obAnim(a0),d0				; get Sonic's currently set animation ID
		cmp.b	obPrevAni(a0),d0			; does it differ from the previous animation? (i.e. has animation changed?)
		beq.s	.do					; if not, branch
		move.b	d0,obPrevAni(a0)			; remember new animation
		move.b	#0,obAniFrame(a0)			; restart animation from beginning
		move.b	#0,obTimeFrame(a0)			; reset animation frame duration
	if FixBugs
		; This fixes the occasional "pushing air" bug
		bclr	#status_pushing_bit,obStatus(a0)	; clear pushing flag
	endif

; SAnim_Do:
.do:
		add.w	d0,d0					; double animation ID for word-based indexing
		adda.w	(a1,d0.w),a1				; jump to appropriate animation script
		move.b	(a1),d0					; load frame interval for this animation
		bmi.s	.walkrunroll				; if frame interval is negative, this is a special walk/run/roll/jump animation, branch

		move.b	obStatus(a0),d1				; get Sonic's status bitfield
		andi.b	#status_xflip,d1			; mask out everything but the X-flip flag
		andi.b	#~(sprite_xflip|sprite_yflip),obRender(a0) ; clear X-flip and Y-flip flags in Sonic's render flags
		or.b	d1,obRender(a0)				; set new X-flip flag state

		subq.b	#1,obTimeFrame(a0)			; subtract 1 from frame duration
		bpl.s	.delay					; if time remains, branch
		move.b	d0,obTimeFrame(a0)			; reset frame duration

; SAnim_Do2:
.loadframe:
		moveq	#0,d1					; clear d1
		move.b	obAniFrame(a0),d1			; load current frame number
		move.b	1(a1,d1.w),d0				; read sprite number from script
		cmpi.b	#afChange,d0		; MJ: is it a flag from FD to FF?
		bhs.s	.end_FF			; MJ: if so, branch to flag routines

; SAnim_Next:
.next:
		move.b	d0,obFrame(a0)				; load sprite number
		addq.b	#1,obAniFrame(a0)			; next frame number

; SAnim_Delay:
.delay:
		rts						; return
; ===========================================================================

; SAnim_End_FF:
.end_FF:
		addq.b	#1,d0					; is this the afEnd flag ($FF)?
		bne.s	.end_FE					; if not, branch
		move.b	#0,obAniFrame(a0)			; restart the animation
		move.b	1(a1),d0				; read sprite number
		bra.s	.next					; set new frame
; ===========================================================================

; SAnim_End_FE
.end_FE:
		addq.b	#1,d0					; is this the afBack flag ($FE)?
		bne.s	.end_FD					; if not, branch
		move.b	2(a1,d1.w),d0				; read the next byte in the script
		sub.b	d0,obAniFrame(a0)			; jump back d0 bytes in the script
		sub.b	d0,d1					; adjust sprite index
		move.b	1(a1,d1.w),d0				; read new sprite number
		bra.s	.next					; set new frame
; ===========================================================================

; SAnim_End_FD:
.end_FD:
		addq.b	#1,d0					; is this the afChange flag ($FD)?
		bne.s	.end					; if not, branch
		move.b	2(a1,d1.w),obAnim(a0)			; read next byte, run that animation

; SAnim_End:
.end:
		rts						; return
; ===========================================================================

; SAnim_WalkRun:
.walkrunroll:
		subq.b	#1,obTimeFrame(a0)			; subtract 1 from frame duration
		bpl.s	.delay					; if time remains, branch
		addq.b	#1,d0					; is animation walking/running?
		bne.w	.rolljump				; if not, branch
		moveq	#0,d1					; clear d1 (do not alter flip flags)
		move.b	obAngle(a0),d0				; get Sonic's angle
	if FixBugs
		; Fix off-by-one-radian error (this was implemented in S2/S3K)
		ble.s	.notoffbyone				; on a flat surface or ascending slope? if yes, branch
		subq.b	#1,d0					; adjust off-by-one angle on descending slopes
.notoffbyone:
	endif
		move.b	obStatus(a0),d2				; get Sonic's current status bitfield
		andi.b	#status_xflip,d2			; mask out anything but the X-flip flag
		bne.s	.flip					; is Sonic mirrored horizontally? if yes, branch
		not.b	d0					; reverse angle
; loc_13A70:
.flip:
		addi.b	#$10,d0					; add $10 to angle
		bpl.s	.noinvert				; if angle is $0-$7F, branch
		moveq	#sprite_xflip|sprite_yflip,d1		; invert both flip flags
; loc_13A78:
.noinvert:
		andi.b	#~(sprite_xflip|sprite_yflip),obRender(a0) ; clear current flip flags
		eor.b	d1,d2					; invert flip flags depending on current angle
		or.b	d2,obRender(a0)				; set new flip flags

		btst	#status_pushing_bit,obStatus(a0)	; is Sonic pushing something?
		bne.w	.push					; if yes, branch

		lsr.b	#4,d0					; divide angle by $10
		andi.b	#6,d0					; angle must be 0, 2, 4 or 6 (this is now the octant modifier)
		move.w	obInertia(a0),d2			; get Sonic's ground speed
		bpl.s	.nomodspeed				; if it's positive, branch
		neg.w	d2					; otherwise, make it positive

; loc_13A9C:
.nomodspeed:
		tst.b	(v_supersonic).w		; is Sonic Super?
		beq.s	.normalwalkrun			; if not, use normal animations
		lea	(SupSonAni_Run).l,a1		; set running animation
		cmpi.w	#$800,d2			; is Super Sonic at running speed?
		bhs.s	.superrun			; if yes, branch
		lea	(SupSonAni_Walk).l,a1		; set walking animation
		bra.s	.superwalk			; proceed with walking routine
.normalwalkrun:
		lea	(SonAni_Run).l,a1		; use running animation
		cmpi.w	#$600,d2			; is Sonic at running speed?
		bhs.s	.running			; if yes, branch
		lea	(SonAni_Walk).l,a1		; use walking animation instead
.superwalk:
		move.b	d0,d1				; make octant modifier a multiple of 3
		lsr.b	#1,d1
		add.b	d1,d0
.running:
		add.b	d0,d0				; multiply octant modifier by 2
.superrun:
		move.b	d0,d3
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	.belowmax
		moveq	#0,d2
.belowmax:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		bsr.w	.loadframe
		add.b	d3,obFrame(a0)
		rts
; ===========================================================================

; SAnim_RollJump:
.rolljump:
		addq.b	#1,d0					; is animation rolling/jumping?
		bne.s	.push					; if not, branch
		move.w	obInertia(a0),d2			; get Sonic's speed
		bpl.s	.nomodspeed2				; is it positive? if yes, branch
		neg.w	d2					; otherwise, make it positive

; loc_13ADE:
.nomodspeed2:
		lea	(SonAni_Roll2).l,a1			; use fast rolling animation
		cmpi.w	#$600,d2				; is Sonic moving fast?
		bhs.s	.rollfast				; if yes, branch
		lea	(SonAni_Roll).l,a1			; use slower rolling animation instead

; loc_13AF0:
.rollfast:
		neg.w	d2					; make speed negative
		addi.w	#$400,d2				; add a significant amount of speed (-$200+$400 >> 8 would result in a frame interval of 2)
		bpl.s	.belowmax2				; if result is positive, use that as frame interval
		moveq	#0,d2					; otherwise, set maximum animation speed

; loc_13AFA:
.belowmax2:
		lsr.w	#8,d2					; shift down a byte
		move.b	d2,obTimeFrame(a0)			; modify frame duration

		move.b	obStatus(a0),d1				; get Sonic's current status flags
		andi.b	#status_xflip,d1			; mask out everything but the X-flip flag
		andi.b	#~(sprite_xflip|sprite_yflip),obRender(a0) ; clear Sonic's current flip flags
		or.b	d1,obRender(a0)				; set new X-flip flag
		bra.w	.loadframe				; update current frame
; ===========================================================================

; SAnim_Push:
.push:
		move.w	obInertia(a0),d2			; get Sonic's speed
		bmi.s	.negspeed				; if it's negative, branch
		neg.w	d2					; otherwise, make it negative

; loc_13B1E:
.negspeed:
		addi.w	#$800,d2				; add a significant amount of speed (-$100+$700 >> 6 would result in a frame interval of 7)
		bpl.s	.belowmax3				; if result is positive, use that as frame interval
		moveq	#0,d2					; otherwise, set maximum animation speed (with pushing, this shouldn't ever happen...)

; loc_13B26:
.belowmax3:
		lsr.w	#6,d2					; shift down a byte and further multiply frame interval by 4
		move.b	d2,obTimeFrame(a0)			; modify frame duration

		lea	(SonAni_Push).l,a1			; load Sonic's animation script for pushing

		move.b	obStatus(a0),d1				; get Sonic's current status flags
		andi.b	#status_xflip,d1			; mask out everything but the X-flip flag
		andi.b	#~(sprite_xflip|sprite_yflip),obRender(a0) ; clear Sonic's current flip flags
		or.b	d1,obRender(a0)				; set new X-flip flag
		tst.b	(v_supersonic).w				; is Sonic Super?
		beq.w	.notsuperpush				; if not, branch
		lea	(SupSonAni_Push).l,a1			; use Super Sonic push sprites
.notsuperpush:
		bra.w	.loadframe				; update current frame
; End of function Sonic_Animate

; ---------------------------------------------------------------------------
; Animation scripts - Sonic (also includes constants for frame IDs)
; SonicAniData:
		include	"_anim/Sonic.asm"
		include	"_anim/Super Sonic.asm"
; ---------------------------------------------------------------------------


; ---------------------------------------------------------------------------
; Sonic DPLC loading subroutine
; ---------------------------------------------------------------------------

; LoadSonicDynPLC:
Sonic_LoadGfx:
		move.b	obFrame(a0),d0				; get Sonic's current frame
		cmp.b	(v_sonframenum).w,d0			; has the frame changed?
		beq.s	.end					; if not, nothing to do
		move.b	d0,(v_sonframenum).w			; update cached frame number
		lea	(SonicDynPLC).l,a2			; load Sonic DPLC table
		move.w	#ArtTile_Sonic*tile_size,d4		; starting VRAM tile
		move.l	#Art_Sonic,d6				; base Sonic art pointer
		jmp	(LoadDynPLC).l				; load DPLC
.end:
		rts						; return
; End of function Sonic_LoadGfx

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to charge and release a Spin Dash
; ---------------------------------------------------------------------------

Sonic_SpinDash:
		btst	#0,spindash_flag(a0)			; is Spin Dash flag already set?
		bne.s	Sonic_UpdateSpindash			; if yes, branch to alternate routine
		cmpi.b	#id_Duck,obAnim(a0)			; is Sonic in his ducking animation?
		bne.s	.end					; if not, branch
		moveq	#btnBC,d0					; is B or C... (A is the Dash Ring button)
		and.b	(v_jpadpress2).w,d0			; ...currently pressed? (not held)
		beq.w	.end					; if not, branch

		move.b	#id_SpinDash,obAnim(a0)			; change Sonic's animation to Spin Dashing
		move.w	#sfx_SpinDash,d0			; set Spin Dash sound
		jsr	(QueueSound2).l				; play it
		addq.l	#4,sp					; skip previous stack entry (i.e. don't do anything else in Sonic_MdNormal)
		bset	#0,spindash_flag(a0)			; set the Spin Dash flag
		clr.w	spindash_count(a0)			; set the Spin Dash counter to start at 0

		bsr.w	Sonic_LevelBound			; because we skipped the stack pointer...
		bsr.w	Sonic_AnglePos				; ...we need to manually run some Sonic stuff
.end:
		rts
; ===========================================================================

Sonic_UpdateSpindash:
		btst	#bitDn,(v_jpadhold2).w			; is down (still) held?
		bne.w	Sonic_ChargingSpindash			; if yes, keep charging Spin Dash

Sonic_ReleaseSpindash:
		bclr	#0,spindash_flag(a0)			; unset Spin Dash flag
		move.b	#sonic_roll_height,obHeight(a0)		; set Sonic's hitbox height to rolling size
		move.b	#sonic_roll_width,obWidth(a0)		; set Sonic's hitbox width to rolling size
		addq.w	#sonic_height-sonic_roll_height,obY(a0)	; add the difference between Sonic's rolling and standing heights
		move.b	#id_Roll,obAnim(a0)			; set Sonic's animation to rolling
		bset	#2,obStatus(a0)				; set Sonic's rolling flag
		move.w	#sfx_Teleport,d0			; set Spin Dash zoom sound
		jsr	(QueueSound2).l 			; play it

		moveq	#0,d0					; clear d0
		move.b	spindash_count(a0),d0			; get number of Spin Dash revs that were performed
		lsl.w	#7,d0					; multiply by $80 for each rev
		move.w	d0,d1					; copy for camera-delay calculation
		addi.w	#$800,d0				; add base speed of $800

		btst	#0,obStatus(a0)				; is Sonic looking to the left?
		beq.s	.not_left				; if not, branch
		neg.w	d0					; negate charge direction
.not_left:	move.w	d0,obInertia(a0)			; apply final speed

		; Camera delay
		add.w	d1,d1					; double 0-based speed
		andi.w	#$1F00,d1				; limit result
		neg.w	d1					; make result negative
		addi.w	#$2000,d1				; add a static base delay against it
		move.w	d1,(v_cam_x_delay).w			; set the final value as camera delay

		; Set new velocties immediately
		move.b	obAngle(a0),d0				; get Sonic's current floor angle
		jsr	(CalcSine).l				; calculate the sine and cosine
		muls.w	obInertia(a0),d1			; multiply sine by release speed
		asr.l	#8,d1					; divide by $100
		move.w	d1,obVelX(a0)				; set new X velocity
		muls.w	obInertia(a0),d0			; multiply cosine by release speed
		asr.l	#8,d0					; divide by $100
		move.w	d0,obVelY(a0)				; set new Y velocity

		bra.s	Sonic_Spindash_ResetScr			; skip
; ===========================================================================

Sonic_ChargingSpindash:
		move.b	#id_SpinDash,obAnim(a0)			; make sure Spin Dash animation stays

		; Charge decay
		tst.w	spindash_count(a0)			; were any revs done?
		beq.s	.no_rev					; if not, branch
		move.w	spindash_count(a0),d0			; get current number of revs
		lsr.w	#5,d0					; divide that number by 32
		sub.w	d0,spindash_count(a0)			; subtract that number from the stored revs (basically a decay)
		bhs.s	.no_rev					; if result is still positive, branch
		clr.w	spindash_count(a0)			; if we underflowed, reset rev counter to 0
.no_rev:
		moveq	#btnBC,d0					; is B or C... (A is the Dash Ring button)
		and.b	(v_jpadpress2).w,d0			; ...currently pressed? (not held)
		beq.w	Sonic_Spindash_ResetScr			; if not, branch
		move.w	#(id_SpinDash<<8),obAnim(a0)		; restart Spin Dash animation
		move.w	#sfx_SpinDash,d0			; set Spin Dash charge sound
		jsr	(QueueSound2).l				; play it
		addi.w	#$200,spindash_count(a0)		; increase rev counter by 2
		cmpi.w	#$800,spindash_count(a0)		; did we exceed the maximum?
		blo.s	Sonic_Spindash_ResetScr			; if not, branch
		move.w	#$800,spindash_count(a0)		; cap charge counter at maximum

Sonic_Spindash_ResetScr:
		addq.l	#4,sp					; skip previous stack entry (i.e. don't do anything else in Sonic_MdNormal)
		cmpi.w	#(224/2)-16,(v_lookshift).w		; is vertical camera offset at base level?
		beq.s	.resetscr_end				; if yes, branch
		bhs.s	.pull_cam_up				; if not and the camera is offset downwards, branch
		addq.w	#2,(v_lookshift).w			; move camera down
		bra.s	.resetscr_end				; skip over
.pull_cam_up:	subq.w	#2,(v_lookshift).w			; move camera up

.resetscr_end:
		bsr.w	Sonic_LevelBound			; because we skipped the stack pointer...
		bra.w	Sonic_AnglePos				; ...we need to manually run some Sonic stuff
; End of function Sonic_SpinDash

; ===========================================================================
; ---------------------------------------------------------------------------
; Dash Ring (hold A) - based on Sonic 2 Secret Rings Edition
;
; While A is held (and Sonic is not under object control):
;   - Sonic is invincible (the invincibility stars show, unless Super Sonic)
;   - left/right are ignored and Sonic is pushed forward at least at dash_speed
;   - one ring is drained using the S2SR timer ($3C minus 4 per active frame)
; Releasing A pauses the timer; it is preserved when A is pressed again.
; Running out of rings ends the dash. Monitor/Super invincibility is preserved.
; The dash requires at least one ring and does not consume one on activation.
; ---------------------------------------------------------------------------

dash_speed:             equ $1000       ; S2SR minimum speed (8.8 fixed point)
dash_drain_reload:       equ $3C         ; S2SR timer reload: 60 units
dash_drain_step:         equ 4           ; S2SR subtracts 4 units per active frame

Sonic_DashRing:
        btst    #0,(f_playerctrl).w             ; under object control (tube, spring...)?
        bne.w   .release
        tst.b   (f_lockctrl).w                  ; controls locked (end of act...)?
        bne.w   .release
        tst.b   (f_timecount).w                 ; time stopped (act finished)?
        beq.w   .release
        btst    #bitA,(v_jpadhold2).w           ; A held?
        beq.w   .release

        tst.b   (v_invcheckdash).w              ; is Speed Break already active?
        bne.w   .active

        ; S2SR start check: Speed Break cannot start with zero rings.
        ; Do NOT initialise the timer here. S2SR initialises it to $003C
        ; when Sonic is created, then preserves its remainder when A is released.
        tst.w   (v_rings).w
        beq.w   .return

        move.b  #1,(v_invcheckdash).w           ; activate Speed Break
        btst    #status_in_air_bit,obStatus(a0) ; in the air?
        bne.w   .startsound                     ; keep current animation
        btst    #status_rolling_bit,obStatus(a0); rolling?
        bne.w   .startsound                     ; keep roll animation
        clr.b   obAnim(a0)                      ; on ground: use walking animation
.startsound:
        move.w  #sfx_SuperTransformation,d0               ; Sonic 1 equivalent of S2SR Speed Break sound
        jsr     (QueueSound2).l

.active:
        ; No rings means no boost. This also protects against rings removed
        ; by another gameplay event while Speed Break is active.
        tst.w   (v_rings).w
        beq.w   .release

        ; Invincibility while boosting; Super Sonic keeps its own visual state.
        move.b  #1,(v_invinc).w
        tst.b   (v_supersonic).w
        bne.w   .drain
        tst.b   (v_starsobj1).w
        bne.w   .drain
        bsr.w   Sonic_DashStars

.drain:
        ; Exact S2SR timer behavior:
        ;   timer starts at $3C
        ;   subtract 4 on every frame A is held and the dash is active
        ;   BPL skips ring drain while result >= 0
        ;   once result is negative, reload $3C and spend one ring
        ; Use the same 16-bit operation and sign test as the S2SR ROM.
        subq.w  #dash_drain_step,(v_dashdrain_timer).w
        bpl.w   .setspeed

        move.w  #dash_drain_reload,(v_dashdrain_timer).w
        tst.w   (v_rings).w
        beq.w   .release

        ; Refresh the Sonic 1 ring HUD, then consume exactly one ring.
        move.b  #$80,(f_ringcount).w
        subq.w  #1,(v_rings).w
        tst.w   (v_rings).w                     ; was that the last ring?
        beq.w   .release                        ; stop immediately at zero

.setspeed:
        ; S2SR removes left/right input while Speed Break is active.
        andi.b  #$FF-btnL-btnR,(v_jpadhold2).w
        andi.b  #$FF-btnL-btnR,(v_jpadpress2).w

        ; S2SR does NOT add acceleration every frame and does NOT impose an
        ; upper speed cap. It only enforces a minimum of $1000 in the facing
        ; direction, preserving any greater existing inertia/velocity.
        btst    #status_xflip_bit,obStatus(a0)  ; facing left?
        bne.w   .left

        cmpi.w  #dash_speed,obInertia(a0)
        bge.w   .rightvel
        move.w  #dash_speed,obInertia(a0)
.rightvel:
        cmpi.w  #dash_speed,obVelX(a0)
        bge.w   .return
        move.w  #dash_speed,obVelX(a0)
.return:
        rts

.left:
        cmpi.w  #-dash_speed,obInertia(a0)
        ble.w   .leftvel
        move.w  #-dash_speed,obInertia(a0)
.leftvel:
        cmpi.w  #-dash_speed,obVelX(a0)
        ble.w   .return
        move.w  #-dash_speed,obVelX(a0)
        rts

; ---------------------------------------------------------------------------
; Release Speed Break (A released, controls locked, or no rings).
; S2SR clears only the active flag here. The drain timer is NOT reset, so
; autofire pauses the timer and the next A pulse resumes the remaining time.
; ---------------------------------------------------------------------------
.release:
        tst.b   (v_invcheckdash).w
        beq.w   .return
        clr.b   (v_invcheckdash).w

        tst.b   (v_supersonic).w                ; Super Sonic keeps invincibility
        bne.w   .return
        tst.w   invtime(a0)                     ; preserve monitor invincibility
        bne.w   .return
        clr.b   (v_invinc).w
        rts
; End of function Sonic_DashRing

; ---------------------------------------------------------------------------
; Subroutine to load the 4 invincibility stars
; ---------------------------------------------------------------------------

Sonic_DashStars:
		move.b	#id_ShieldItem,(v_starsobj1).w
		move.b	#1,(v_starsobj1+obAnim).w
		move.b	#id_ShieldItem,(v_starsobj2).w
		move.b	#2,(v_starsobj2+obAnim).w
		move.b	#id_ShieldItem,(v_starsobj3).w
		move.b	#3,(v_starsobj3+obAnim).w
		move.b	#id_ShieldItem,(v_starsobj4).w
		move.b	#4,(v_starsobj4+obAnim).w
		rts
; End of function Sonic_DashStars

; ---------------------------------------------------------------------------
; Manual Super Sonic transformation (no speed boost forced on Sonic)
; Press B or C while in the air with enough rings (and all 6 emeralds).
; ---------------------------------------------------------------------------

super_min_rings:	equ 50			; rings needed to transform
super_need_emeralds:	equ 1			; 1 = needs all 6 emeralds, 0 = no emerald needed

; ---------------------------------------------------------------------------
; Hyper Dash (Hyper Sonic, state 2): ported from Sonic 3 & Knuckles' Sonic_HyperDash.
; Used in the air. The D-pad sets the direction (8 directions); with no direction
; Sonic dashes forward ($800). Once per jump (v_hyperdash_flag, cleared on landing).
; The dash destroys visible badniks/bosses, flashes the full CRAM palette white,
; and spawns four outward attack sparks using Hyper Sonic's expanding mappings.
; ---------------------------------------------------------------------------
Sonic_HyperDash:
		move.b	#1,(v_hyperdash_flag).w		; one Hyper Dash per jump
		move.b	#HyperFlashFrames,(v_hyperflash_timer).w	; configurable attack-flash duration
		clr.b	(v_hyperflash_slowmo_frame).w		; reset pause-step marker
		move.b	#1,(v_hyperattack_pending).w	; process enemies after their collision entries are registered
		jsr	(HyperStars_CreateSparks).l		; create the four outward Hyper sparks
		move.w	#sfx_Teleport,d0			; dash sound (S3K: sfx_Dash)
		jsr	(QueueSound2).l
		move.b	(v_jpadhold1).w,d0			; held D-pad (up 1, down 2, left 4, right 8)
		andi.b	#$0F,d0
		beq.s	.noinput
		cmpi.b	#$B,d0				; $B and above: both opposite directions (invalid)
		bhs.s	.noinput
		lsl.w	#2,d0
		lea	Sonic_HyperDash_Velocities-4(pc,d0.w),a1
		move.w	(a1)+,d0
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		move.w	(a1)+,d0
		move.w	d0,obVelY(a0)
		bra.s	.setCameraDelay
.noinput:
		move.w	#$800,d0				; forward...
		btst	#0,obStatus(a0)			; ...or backward if Sonic faces left
		beq.s	.applyvel
		neg.w	d0
.applyvel:
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		clr.w	obVelY(a0)
.setCameraDelay:
		; Match the base Spin Dash camera lag for a horizontal $800 dash.
		; MoveScreenHoriz consumes $100 per frame from this $2000 timer.
		tst.w	obVelX(a0)
		beq.s	.return
		move.w	#$2000,(v_cam_x_delay).w
.return:
		rts
; ---------------------------------------------------------------------------
Sonic_HyperDash_Velocities:
		dc.w	0,-$800				; up
		dc.w	0,$800				; down
		dc.w	0,0					; up + down (invalid)
		dc.w	-$800,0				; left
		dc.w	-$800,-$800			; left + up
		dc.w	-$800,$800			; left + down
		dc.w	0,0					; left + up + down (invalid)
		dc.w	$800,0				; right
		dc.w	$800,-$800			; right + up
		dc.w	$800,$800			; right + down
; ---------------------------------------------------------------------------

Sonic_CheckGoSuper:
		; Choose the transformation SFX from the active form.
		; Super Sonic keeps D2; Hyper Sonic uses the dedicated D3 command.
		tst.b	(v_supertransform_sfx_pending).w ; is the transformation sound pending?
		beq.s	.checkHyperState
		clr.b	(v_supertransform_sfx_pending).w ; queue it only once		
	if HyperSonic
		cmpi.b	#2,(v_supersonic).w		; did this transformation enter Hyper state?
		beq.s	.hyperTransformSFX
	endif
		move.w	#sfx_SuperTransformation,d0	; regular Super transformation (D2)
	if HyperSonic
		bra.s	.queueTransformSFX
.hyperTransformSFX:
		move.w	#sfx_HyperTransformation,d0	; Hyper transformation (D3)
.queueTransformSFX:
	endif
		jsr	(QueueSound2).l			; play after the transformation music has started

.checkHyperState:
		cmpi.b	#2,(v_supersonic).w		; is Hyper Sonic active?
		beq.s	.tryHyperDash
		tst.b	(v_supersonic).w			; is regular Super Sonic active?
		bne.w	.return				; regular Super has no Hyper Dash
		bra.s	.checkTransform

.tryHyperDash:
		btst	#status_in_air_bit,obStatus(a0)	; must be airborne
		beq.w	.return
		tst.b	jumping(a0)			; reject falling off ledges: this flag is set only by Sonic_Jump
		beq.w	.return
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.w	.return
		btst	#0,(f_playerctrl).w			; skip dash while transformation/object control is active
		bne.w	.return
		tst.b	(v_hyperdash_flag).w			; already used in this jump?
		bne.w	.return
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnC,d0				; only C starts the Hyper Dash
		beq.w	.return
		bra.w	Sonic_HyperDash

.checkTransform:
		btst	#status_in_air_bit,obStatus(a0)	; is Sonic in the air?
		beq.w	.return				; if not, branch
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.w	.return				; if yes, branch
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnC,d0				; C starts the normal Super transformation
		beq.w	.return				; if not, branch
	if super_need_emeralds
		cmpi.b	#6,(v_emeralds).w		; all 6 Chaos Emeralds?
		bne.w	.return				; if not, branch
	endif
		cmpi.w	#super_min_rings,(v_rings).w	; enough rings?
		blo.w	.return				; if not, branch
		tst.b	(f_timecount).w			; is the act timer still running?
		beq.w	.return				; if not, block the transformation
		bra.w	Sonic_DoSuperTransform
.return:
		rts
; End of function Sonic_CheckGoSuper

; ---------------------------------------------------------------------------
; Shared Super Sonic transformation sequence.
; Called by Sonic_CheckGoSuper after its checks, or directly by the S monitor.
; Input: a0 = player object.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Hyper Sonic (v_supersonic = 2): the Hyper state starts the After Images trail.
; Not triggered yet: the trigger and the Hyper palette start are still to be
; analysed from the Hyper ROM (Super Sonic stays as state 1, unchanged).
; ---------------------------------------------------------------------------
Sonic_GoHyper:
	if HyperSonic
		move.b	#2,(v_supersonic).w			; Hyper state
		move.b	#id_AfterImage,(v_afterimage).w	; After Images trail
	endif
		rts

Sonic_DoSuperTransform:
		andi.b	#$FF-%00010100,obStatus(a0)	; clear rolling and roll-jumping
		move.b	#sonic_height,obHeight(a0)	; standing hitbox
		move.b	#sonic_width,obWidth(a0)
		move.b	#1,(v_supersonic).w		; set Super Sonic flag
	if HyperSonic
		move.b	#2,(v_supersonic).w		; HyperSonic option: the transformation goes straight to Hyper (state 2)
		clr.b	(v_shield).w				; Hyper stars replace shield graphics in the shared VRAM slot
		clr.b	(v_shieldobj).w			; remove any active shield object before uploading Hyper-star art
		clr.b	(v_hyperdash_flag).w
		clr.b	(v_hyperflash_timer).w
		clr.b	(v_hyperflash_slowmo_frame).w
		clr.b	(v_hyperflash_hblank).w
		clr.b	(v_hyperattack_pending).w
		move.b	#id_AfterImage,(v_afterimage).w	; Hyper trail: load the After Images object
		clr.b	(v_afterimage+obRoutine).w		; fixed object slot may contain stale routine data
		clr.b	(v_afterimage+obColType).w
		clr.b	(v_afterimage+obBossHits).w
		clr.b	(v_afterimage+obStatus).w
		move.b	#48/2,(v_afterimage+obActWid).w
		move.l	#Art_HyperStars,d1			; Hyper stars art to VRAM
		move.w	#ArtTile_HyperStars*tile_size,d2
		move.w	#(Art_HyperStarsend-Art_HyperStars)/2,d3	; QueueDMATransfer expects word count, not byte count
		jsr	(QueueDMATransfer).l
		move.b	#id_HyperStars,(v_hyperstars).w	; Hyper stars object
		clr.b	(v_hyperstars+obRoutine).w		; fixed object slot may contain stale routine data
		clr.b	(v_hyperstars+obColType).w
		clr.b	(v_hyperstars+obBossHits).w
		clr.b	(v_hyperstars+obStatus).w
		move.b	#48/2,(v_hyperstars+obActWid).w
	endif
		clr.b	(v_ssframe).w
		bsr.w	Sonic_ApplyLevelStats		; apply this level's Super stats immediately
		
		; === CHECAGEM DE SEGURANÇA DO SUPER SONIC ===
		; Só aciona o estado da paleta se o Super Sonic estiver ativo de fato
		tst.b	(v_supersonic).w		; está realmente Super?
		beq.s	.skip_palstate			; se não estiver, pula
		move.b	#1,(v_supersonic_palstate).w	; begin palette fade-in
.skip_palstate:
		move.b	#$F,(v_supersonic_paltimer).w
		clr.b	(v_supersonic_palframe).w
		move.b	#1,(f_playerctrl).w		; lock movement during the transformation
		move.b	#id_Transform,obAnim(a0)	; play transformation animation
		move.w	#0,invtime(a0)			; cancel any invincibility timer
		move.b	#1,(v_invinc).w			; invincible
		clr.b	(v_starsobj1).w			; Super Sonic has no invincibility stars: remove any that exist
		clr.b	(v_starsobj2).w
		clr.b	(v_starsobj3).w
		clr.b	(v_starsobj4).w
	if HyperSonic=0
		move.b	#id_SuperSonicStar,(v_starsobj1).w	; load Super Sonic's stars object (Hyper uses the Hyper stars instead)
		clr.b	(v_starsobj1+obRoutine).w		; clear routine counter
	endif
		move.b	#1,(v_supertransform_sfx_pending).w ; play the transformation SFX on the next frame
		move.w	#bgm_SuperSonic,d0		; start Super Sonic music first
		jmp	(QueueSound1).l
; End of function Sonic_DoSuperTransform

; ===========================================================================
; ---------------------------------------------------------------------------
; Press B while jumping: stop the vertical speed and show the fall sprite
; (no sound). Sonic keeps the jump (ball) animation ID so he still hurts enemies.
; ---------------------------------------------------------------------------

Sonic_AirFall:
		cmpi.b	#2,(v_supersonic).w		; B remains the normal fall input; Hyper Dash is bound to C
		bne.s	.checkInAir
		tst.b	(v_hyperdash_flag).w
		bne.s	.return
.checkInAir:
		btst	#status_in_air_bit,obStatus(a0)	; is Sonic in the air?
		beq.s	.clear				; if not, forget the fall sprite
		cmpi.b	#id_Fall,obAnim(a0)		; is Sonic already falling?
		beq.s	.return				; if yes, only once per jump
		cmpi.b	#id_Roll,obAnim(a0)		; is Sonic jumping (ball)?
		bne.s	.clear				; if not, forget the fall sprite
		btst	#0,(f_playerctrl).w		; is Sonic controlled by an object / transforming?
		bne.s	.return				; if yes, do nothing
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.s	.return				; if yes, do nothing
		tst.b	(v_sonfall).w			; was the fall already used in this jump?
		bne.s	.return				; if yes, only once per jump
		btst	#bitB,(v_jpadpress2).w		; was B just pressed?
		beq.s	.return				; if not, branch
		move.b	#1,(v_sonfall).w		; show the fall sprite
		move.b	#id_Fall,obAnim(a0)		; leave the rolling animation: falling Sonic doesn't attack
		cmpi.w	#$340,obVelY(a0)		; fall speed is at least $340 (as in Sonic 2 Secret Rings Edition)
		bgt.s	.keepfallspeed			; if already faster, keep it
		move.w	#$340,obVelY(a0)			; otherwise set the fall speed to $340
.keepfallspeed:
		asr.w	obVelX(a0)				; horizontal speed divided by 4 (two shifts, as in the ROM)
		asr.w	obVelX(a0)
.return:
		rts
.clear:
		clr.b	(v_sonfall).w
		rts
; End of function Sonic_AirFall

; ---------------------------------------------------------------------------
; Super Sonic per-frame handler: drains 1 ring per second, reverts at 0 rings
; ---------------------------------------------------------------------------

Sonic_Super:
		tst.b	(v_supersonic).w		; is Sonic Super?
		beq.w	.exit				; if not, do nothing
		tst.b	(f_timecount).w			; is the act timer still running?
		beq.s	.revert				; if not (act ended), revert

		; keep invincibility and apply Super's level-scaled movement stats
		move.b	#1,(v_invinc).w
		bsr.w	Sonic_ApplyLevelStats
		subq.b	#1,(v_ssframe).w		; count down the ring-drain timer
		bhi.s	.exit				; not expired yet
		move.b	#60,(v_ssframe).w		; reset to 60 frames (1 second)
		tst.w	(v_rings).w			; any rings remaining?
		beq.s	.revert				; if none, revert
		move.b	#$80,(f_ringcount).w		; redraw the ring counter (so it can show 0)
		subq.w	#1,(v_rings).w			; take 1 ring
		bne.s	.exit				; if rings remain, branch
.revert:
		cmpi.b	#2,(v_supersonic).w		; was the expiring form Hyper Sonic?
		bne.s	.clearSuperState
		clr.b	(v_shield).w				; never carry a normal shield out of Hyper form
		clr.b	(v_shieldobj).w				; remove any shield object left in its fixed slot
.clearSuperState:
		move.b	#0,(v_supersonic).w
		cmpi.b	#1,(v_supersonic_palstate).w	; was the fade-in still running?
		beq.s	.palkeep
		move.b	#5*2*4,(v_supersonic_palframe).w
.palkeep:
		move.b	#2,(v_supersonic_palstate).w	; begin palette fade-out
		move.b	#0,(f_playerctrl).w		; never leave Sonic locked
		move.b	#id_Run,obPrevAni(a0)		; force animation to restart
		tst.b	(v_invcheckdash).w		; is the Dash Ring still active?
		bne.s	.restorespeed			; if yes, it keeps Sonic invincible
		tst.w	invtime(a0)			; monitor invincibility running?
		bne.s	.restorespeed
		move.w	#1,invtime(a0)			; expire invincibility next frame (zone music returns)
.restorespeed:
		bsr.w	Sonic_ApplyLevelStats			; revert to this speed level, including water scaling
.exit:
		rts
; End of function Sonic_Super
