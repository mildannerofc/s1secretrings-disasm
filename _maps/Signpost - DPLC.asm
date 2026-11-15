DPLC_Sign: mappingsTable
	mappingsTableEntry.w	DPLC_Sign_0
	mappingsTableEntry.w	DPLC_Sign_1
	mappingsTableEntry.w	DPLC_Sign_2
	mappingsTableEntry.w	DPLC_Sign_3
	mappingsTableEntry.w	DPLC_Sign_4

DPLC_Sign_0:	dplcHeader
 dplcEntry $C, 0
 dplcEntry 2, $38
DPLC_Sign_0_End

DPLC_Sign_1:	dplcHeader
 dplcEntry $10, $C
 dplcEntry 2, $38
DPLC_Sign_1_End

DPLC_Sign_2:	dplcHeader
 dplcEntry 4, $1C
 dplcEntry 2, $38
DPLC_Sign_2_End

DPLC_Sign_3:	dplcHeader
 dplcEntry $10, $C
 dplcEntry 2, $38
DPLC_Sign_3_End

DPLC_Sign_4:	dplcHeader
 dplcEntry $10, $20
 dplcEntry $A, $30
DPLC_Sign_4_End

	even