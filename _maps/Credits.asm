; ---------------------------------------------------------------------------
; Sprite mappings - "SONIC TEAM PRESENTS" and credits
; ---------------------------------------------------------------------------
Map_Cred_internal:	mappingsTable
	mappingsTableEntry.w	.staff
	mappingsTableEntry.w	.gameplan
	mappingsTableEntry.w	.program
	mappingsTableEntry.w	.character
	mappingsTableEntry.w	.design
	mappingsTableEntry.w	.soundproduce
	mappingsTableEntry.w	.soundprogram
	mappingsTableEntry.w	.thanks
	mappingsTableEntry.w	.presentedby
	mappingsTableEntry.w	.tryagain
	mappingsTableEntry.w	.sonicteampresents ; shown before the title screen
	mappingsTableEntry.w	.sramdeleted	; shown after clearing SRAM with A+B+C
	mappingsTableEntry.w	.sraminvalid	; shown when SRAM validation fails

.staff:	spriteHeader	; SONIC TEAM STAFF
	spritePiece	-$78, -8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	-$68, -8, 2, 2, $26, 0, 0, 0, 0		; O
	spritePiece	-$58, -8, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	-$48, -8, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	-$40, -8, 2, 2, $1E, 0, 0, 0, 0		; C

	spritePiece	-$28, -8, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	-$18, -8, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	-8, -8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	8, -8, 3, 2, 8, 0, 0, 0, 0		; M

	spritePiece	$28, -8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	$38, -8, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	$48, -8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$58, -8, 2, 2, $5C, 0, 0, 0, 0		; F
	spritePiece	$68, -8, 2, 2, $5C, 0, 0, 0, 0		; F
.staff_End

.gameplan:	spriteHeader	; GAME PLAN CAROL YAS
	spritePiece	-$80, -$28, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	-$70, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$60, -$28, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	-$4C, -$28, 2, 2, $E, 0, 0, 0, 0	; E

	spritePiece	-$30, -$28, 2, 2, $12, 0, 0, 0, 0	; P
	spritePiece	-$20, -$28, 2, 2, $16, 0, 0, 0, 0	; L
	spritePiece	-$10, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	0, -$28, 2, 2, $1A, 0, 0, 0, 0		; N

	spritePiece	-$38, 8, 2, 2, $1E, 0, 0, 0, 0		; C
	spritePiece	-$28, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$18, 8, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	-8, 8, 2, 2, $26, 0, 0, 0, 0		; O
	spritePiece	8, 8, 2, 2, $16, 0, 0, 0, 0		; L

	spritePiece	$20, 8, 2, 2, $2A, 0, 0, 0, 0		; Y
	spritePiece	$30, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$44, 8, 2, 2, $2E, 0, 0, 0, 0		; S
.gameplan_End

.program:	spriteHeader	; PROGRAM YU 2
	spritePiece	-$80, -$28, 2, 2, $12, 0, 0, 0, 0	; P
	spritePiece	-$70, -$28, 2, 2, $22, 0, 0, 0, 0	; R
	spritePiece	-$60, -$28, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	-$50, -$28, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	-$40, -$28, 2, 2, $22, 0, 0, 0, 0	; R
	spritePiece	-$30, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$20, -$28, 3, 2, 8, 0, 0, 0, 0		; M

	spritePiece	-$18, 8, 2, 2, $2A, 0, 0, 0, 0		; Y
	spritePiece	-8, 8, 2, 2, $32, 0, 0, 0, 0		; U
	spritePiece	8, 8, 2, 2, $36, 0, 0, 0, 0		; 2
.program_End

.character:	spriteHeader	; CHARACTER DESIGN BIGISLAND
	spritePiece	-$78, -$28, 2, 2, $1E, 0, 0, 0, 0	; C
	spritePiece	-$68, -$28, 2, 2, $3A, 0, 0, 0, 0	; H
	spritePiece	-$58, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$48, -$28, 2, 2, $22, 0, 0, 0, 0	; R
	spritePiece	-$38, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$28, -$28, 2, 2, $1E, 0, 0, 0, 0	; C
	spritePiece	-$18, -$28, 2, 2, $3E, 0, 0, 0, 0	; T
	spritePiece	-8, -$28, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	8, -$28, 2, 2, $22, 0, 0, 0, 0		; R

	spritePiece	$20, -$28, 2, 2, $42, 0, 0, 0, 0	; D
	spritePiece	$30, -$28, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	$40, -$28, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	$50, -$28, 1, 2, $46, 0, 0, 0, 0	; I
	spritePiece	$58, -$28, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	$68, -$28, 2, 2, $1A, 0, 0, 0, 0	; N

	spritePiece	-$40, 8, 2, 2, $48, 0, 0, 0, 0		; B
	spritePiece	-$30, 8, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	-$28, 8, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	-$18, 8, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	-$10, 8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	0, 8, 2, 2, $16, 0, 0, 0, 0		; L
	spritePiece	$10, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$20, 8, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	$30, 8, 2, 2, $42, 0, 0, 0, 0		; D
.character_End

.design:	spriteHeader	; DESIGN JINYA PHENIX RIE
	spritePiece	-$60, -$30, 2, 2, $42, 0, 0, 0, 0	; D
	spritePiece	-$50, -$30, 2, 2, $E, 0, 0, 0, 0	; E
	spritePiece	-$40, -$30, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	-$30, -$30, 1, 2, $46, 0, 0, 0, 0	; I
	spritePiece	-$28, -$30, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	-$18, -$30, 2, 2, $1A, 0, 0, 0, 0	; N

	spritePiece	-$18, 0, 2, 2, $4C, 0, 0, 0, 0		; J
	spritePiece	-8, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	4, 0, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	$14, 0, 2, 2, $2A, 0, 0, 0, 0		; Y
	spritePiece	$24, 0, 2, 2, 4, 0, 0, 0, 0		; A

	spritePiece	-$30, $20, 2, 2, $12, 0, 0, 0, 0	; P
	spritePiece	-$20, $20, 2, 2, $3A, 0, 0, 0, 0	; H
	spritePiece	-$10, $20, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	0, $20, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	$10, $20, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	$18, $20, 2, 2, $50, 0, 0, 0, 0		; X

	spritePiece	$30, $20, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	$40, $20, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	$48, $20, 2, 2, $E, 0, 0, 0, 0		; E
.design_End

.soundproduce:	spriteHeader	; SOUND PRODUCE MASATO NAKAMURA
	spritePiece	-$68, -$28, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	-$58, -$28, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	-$48, -$28, 2, 2, $32, 0, 0, 0, 0	; U
	spritePiece	-$38, -$28, 2, 2, $1A, 0, 0, 0, 0	; N
	spritePiece	-$28, -$28, 2, 2, $54, 0, 0, 0, 0	; D

	spritePiece	-8, -$28, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	8, -$28, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	$18, -$28, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	$28, -$28, 2, 2, $42, 0, 0, 0, 0	; D
	spritePiece	$38, -$28, 2, 2, $32, 0, 0, 0, 0	; U
	spritePiece	$48, -$28, 2, 2, $1E, 0, 0, 0, 0	; C
	spritePiece	$58, -$28, 2, 2, $E, 0, 0, 0, 0		; E

	spritePiece	-$78, 8, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	-$64, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$54, 8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	-$44, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$34, 8, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	-$24, 8, 2, 2, $26, 0, 0, 0, 0		; O

	spritePiece	-8, 8, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	8, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$18, 8, 2, 2, $58, 0, 0, 0, 0		; K
	spritePiece	$28, 8, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$38, 8, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	$4C, 8, 2, 2, $32, 0, 0, 0, 0		; U
	spritePiece	$5C, 8, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	$6C, 8, 2, 2, 4, 0, 0, 0, 0		; A
.soundproduce_End

.soundprogram:	spriteHeader	; SOUND PROGRAM JIMITA MACKY
	spritePiece	-$68, -$30, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	-$58, -$30, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	-$48, -$30, 2, 2, $32, 0, 0, 0, 0	; U
	spritePiece	-$38, -$30, 2, 2, $1A, 0, 0, 0, 0	; N
	spritePiece	-$28, -$30, 2, 2, $54, 0, 0, 0, 0	; D

	spritePiece	-8, -$30, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	8, -$30, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	$18, -$30, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	$28, -$30, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	$38, -$30, 2, 2, $22, 0, 0, 0, 0	; R
	spritePiece	$48, -$30, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$58, -$30, 3, 2, 8, 0, 0, 0, 0		; M

	spritePiece	-$30, 0, 2, 2, $4C, 0, 0, 0, 0		; J
	spritePiece	-$20, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	-$18, 0, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	-4, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	4, 0, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	$14, 0, 2, 2, 4, 0, 0, 0, 0		; A

	spritePiece	-$30, $20, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	-$1C, $20, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$C, $20, 2, 2, $1E, 0, 0, 0, 0		; C
	spritePiece	4, $20, 2, 2, $58, 0, 0, 0, 0		; K
	spritePiece	$14, $20, 2, 2, $2A, 0, 0, 0, 0		; Y
.soundprogram_End

.thanks:	spriteHeader	; SPECIAL THANKS FUJIO MINEGISHI PAPA
	spritePiece	-$80, -$28, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	-$70, -$28, 2, 2, $12, 0, 0, 0, 0	; P
	spritePiece	-$60, -$28, 2, 2, $E, 0, 0, 0, 0	; E
	spritePiece	-$50, -$28, 2, 2, $1E, 0, 0, 0, 0	; C
	spritePiece	-$40, -$28, 1, 2, $46, 0, 0, 0, 0	; I
	spritePiece	-$38, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	-$28, -$28, 2, 2, $16, 0, 0, 0, 0	; L

	spritePiece	-8, -$28, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	8, -$28, 2, 2, $3A, 0, 0, 0, 0		; H
	spritePiece	$18, -$28, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$28, -$28, 2, 2, $1A, 0, 0, 0, 0	; N
	spritePiece	$38, -$28, 2, 2, $58, 0, 0, 0, 0	; K
	spritePiece	$48, -$28, 2, 2, $2E, 0, 0, 0, 0	; S

	spritePiece	-$50, 0, 2, 2, $5C, 0, 0, 0, 0		; F
	spritePiece	-$40, 0, 2, 2, $32, 0, 0, 0, 0		; U
	spritePiece	-$30, 0, 2, 2, $4C, 0, 0, 0, 0		; J
	spritePiece	-$20, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	-$18, 0, 2, 2, $26, 0, 0, 0, 0		; O

	spritePiece	0, 0, 3, 2, 8, 0, 0, 0, 0		; M
	spritePiece	$14, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	$1C, 0, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	$2C, 0, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	$3C, 0, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	$4C, 0, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	$54, 0, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	$64, 0, 2, 2, $3A, 0, 0, 0, 0		; H
	spritePiece	$74, 0, 1, 2, $46, 0, 0, 0, 0		; I

	spritePiece	-8, $20, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	8, $20, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$18, $20, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	$28, $20, 2, 2, 4, 0, 0, 0, 0		; A
.thanks_End

.presentedby:	spriteHeader	; PRESENTED BY SEGA
	spritePiece	-$80, -8, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	-$70, -8, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	-$60, -8, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	-$50, -8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	-$40, -8, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	-$30, -8, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	-$20, -8, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	-$10, -8, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	0, -8, 2, 2, $42, 0, 0, 0, 0		; D

	spritePiece	$18, -8, 2, 2, $48, 0, 0, 0, 0		; B
	spritePiece	$28, -8, 2, 2, $2A, 0, 0, 0, 0		; Y

	spritePiece	$40, -8, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	$50, -8, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	$60, -8, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	$70, -8, 2, 2, 4, 0, 0, 0, 0		; A
.presentedby_End

.tryagain:	spriteHeader	; TRY AGAIN
	spritePiece	-$40, $30, 2, 2, $3E, 0, 0, 0, 0	; T
	spritePiece	-$30, $30, 2, 2, $22, 0, 0, 0, 0	; R
	spritePiece	-$20, $30, 2, 2, $2A, 0, 0, 0, 0	; Y

	spritePiece	-8, $30, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	8, $30, 2, 2, 0, 0, 0, 0, 0		; G
	spritePiece	$18, $30, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$28, $30, 1, 2, $46, 0, 0, 0, 0		; I
	spritePiece	$30, $30, 2, 2, $1A, 0, 0, 0, 0		; N
.tryagain_End


.sonicteampresents:	spriteHeader	; SONIC TEAM PRESENTS
	spritePiece	-$4C, -$18, 2, 2, $2E, 0, 0, 0, 0	; S
	spritePiece	-$3C, -$18, 2, 2, $26, 0, 0, 0, 0	; O
	spritePiece	-$2C, -$18, 2, 2, $1A, 0, 0, 0, 0	; N
	spritePiece	-$1C, -$18, 1, 2, $46, 0, 0, 0, 0	; I
	spritePiece	-$14, -$18, 2, 2, $1E, 0, 0, 0, 0	; C

	spritePiece	4, -$18, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	$14, -$18, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	$24, -$18, 2, 2, 4, 0, 0, 0, 0		; A
	spritePiece	$34, -$18, 3, 2, 8, 0, 0, 0, 0		; M

	spritePiece	-$40, 0, 2, 2, $12, 0, 0, 0, 0		; P
	spritePiece	-$30, 0, 2, 2, $22, 0, 0, 0, 0		; R
	spritePiece	-$20, 0, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	-$10, 0, 2, 2, $2E, 0, 0, 0, 0		; S
	spritePiece	0, 0, 2, 2, $E, 0, 0, 0, 0		; E
	spritePiece	$10, 0, 2, 2, $1A, 0, 0, 0, 0		; N
	spritePiece	$20, 0, 2, 2, $3E, 0, 0, 0, 0		; T
	spritePiece	$30, 0, 2, 2, $2E, 0, 0, 0, 0		; S
.sonicteampresents_End


.sramdeleted: spriteHeader	; SRAM DATA DELETED
		; 15 pieces: SRAM DATA / DELETED
		dc.b $F0, $05, $00, $2E, $B7	; S
		dc.b $F0, $05, $00, $22, $C5	; R
		dc.b $F0, $05, $00, $04, $D5	; A
		dc.b $F0, $09, $00, $08, $E5	; M
						; space
		dc.b $F0, $05, $00, $42, $09	; D
		dc.b $F0, $05, $00, $04, $19	; A
		dc.b $F0, $05, $00, $3E, $29	; T
		dc.b $F0, $05, $00, $04, $39	; A
		dc.b $00, $05, $00, $42, $CA	; D
		dc.b $00, $05, $00, $0E, $DA	; E
		dc.b $00, $05, $00, $16, $E9	; L
		dc.b $00, $05, $00, $0E, $F8	; E
		dc.b $00, $05, $00, $3E, $07	; T
		dc.b $00, $05, $00, $0E, $17	; E
		dc.b $00, $05, $00, $42, $26	; D
.sramdeleted_End

.sraminvalid: dc.b 28	;  / SRAM NOT / DETECTED / NOT MAKING SRAM

		dc.b $F0, $05, $00, $2E, $BF	; S
		dc.b $F0, $05, $00, $22, $CD	; R
		dc.b $F0, $05, $00, $04, $DD	; A
		dc.b $F0, $09, $00, $08, $ED	; M
						; space
		dc.b $F0, $05, $00, $1A, $11	; N
		dc.b $F0, $05, $00, $26, $20	; O
		dc.b $F0, $05, $00, $3E, $30	; T

		dc.b $00, $05, $00, $42, $C1	; D
		dc.b $00, $05, $00, $0E, $D1	; E
		dc.b $00, $05, $00, $3E, $E0	; T
		dc.b $00, $05, $00, $0E, $F0	; E
		dc.b $00, $05, $00, $1E, $FF	; C
		dc.b $00, $05, $00, $3E, $0F	; T
		dc.b $00, $05, $00, $0E, $1F	; E
		dc.b $00, $05, $00, $42, $2E	; D

		dc.b $20, $05, $00, $1A, $8A	; N
		dc.b $20, $05, $00, $26, $99	; O
		dc.b $20, $05, $00, $3E, $A9	; T
						; space
		dc.b $20, $09, $00, $08, $C9	; M
		dc.b $20, $05, $00, $04, $DD	; A
		dc.b $20, $05, $00, $58, $ED	; K
		dc.b $20, $01, $00, $46, $FD	; I
		dc.b $20, $05, $00, $1A, $05	; N
		dc.b $20, $05, $00, $00, $14	; G
						; space
		dc.b $20, $05, $00, $2E, $34	; S
		dc.b $20, $05, $00, $22, $42	; R
		dc.b $20, $05, $00, $04, $52	; A
		dc.b $20, $09, $00, $08, $62	; M
		even
.sraminvalid_End

	even
