; ---------------------------------------------------------------------------
; Sprite mappings - dynamically loaded walls of the Special Stage
; ---------------------------------------------------------------------------
; The straight wall uses a 3x3 sprite (9 tiles). Every rotated wall uses a
; 4x4 sprite (16 tiles). SS_LoadWalls streams the corresponding art frame to
; ArtTile_SS_Wall, so only these two mapping entries are required.

Map_SSWalls_internal:	mappingsTable
	mappingsTableEntry.w	.straight
	mappingsTableEntry.w	.angled

.straight:	spriteHeader
	spritePiece	-$C, -$C, 3, 3, 0, 0, 0, 0, 0
.straight_End

.angled:	spriteHeader
	spritePiece	-$10, -$10, 4, 4, 0, 0, 0, 0, 0
.angled_End

	even
