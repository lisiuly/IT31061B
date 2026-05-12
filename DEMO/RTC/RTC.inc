;===================================================
;            RAM Define
;====================================================
.EXTERN			R_TimeStatus
HalfSecToggle			EQU		01000000B

AddSecondOnly			EQU		00100000B
AddOthers				EQU		00010000B
.EXTERN			RTC

;===================================================
;            Module Define
;====================================================
.EXTERN			F_ResetRealTimeClock
.EXTERN			F_RealTimeClock
.EXTERN			F_ClearIncStatus
.EXTERN			INC_SEC
.EXTERN			INC_MIN
.EXTERN			INC_MIN1
.EXTERN			INC_MIN2
.EXTERN			INC_HR
.EXTERN			INC_HR1
.EXTERN			INC_HR2		;x for RAM, a for Max

;====================================================
