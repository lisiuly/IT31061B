;			RAM Define
;==========================================================

;===================================================
;			RAM Define
;====================================================
.EXTERN			R_TempBuf
R_LcdTableIndex			equ	R_TempBuf+1		;ds	1
R_Display_Number		equ	R_TempBuf+2		;ds	1
R_LcdSegmentPosition	equ	R_TempBuf+3		;ds	1
R_Display7Times			equ	R_TempBuf+4		;ds	1
.EXTERN			T_Icon
.EXTERN			LcdMapTab
.EXTERN			T_NumberTable
.EXTERN			T_12Temp_Table
;===================================================
;			Module Define
;====================================================
.EXTERN         F_ClrLcdDpram
.EXTERN			F_AllDisplayLcd
.EXTERN         F_ClrPage0SRAM
;.EXTERN         F_ClrSRAM
.EXTERN         F_Display
.EXTERN			F_DisplayHLValue
.EXTERN			F_ClearAllDisplay
.EXTERN			F_DisplayProductUI
.EXTERN		R_Disp3s
.EXTERN		R_OutdoorFlashRun
.EXTERN		R_OutdoorBlankPending
.EXTERN		R_OutdoorBlanking
;====================================================
.EXTERN			F_Start_RFCMM_Value	

