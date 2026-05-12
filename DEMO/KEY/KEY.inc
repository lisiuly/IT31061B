
;===================================================
;			RAM Define
;====================================================
.EXTERN		R_Set
D_SetConver		equ	02h
D_SetTimeHour	equ	04h
D_SetTimeMin	equ	08h
D_SetTimeMax	equ	10h

;D_SetAConver	equ	02h
D_SetAlarmHour	equ	02h
D_SetAlarmMin	equ	04h
D_SetAlarmMax	equ	08h

D_SetDateYear	equ	02h
D_SetDateMonth	equ	04h
D_SetDateDay	equ	08h
D_SetDateMax	equ	10h

D_SetHour	equ	02h
D_SetMin	equ	04h
D_SetMax	equ	08h


.EXTERN		R_KeyFlag
D_KeyTone		equ	01h
D_EnableFastAdd	equ	02h		
D_EnableAlarm	equ	04h
D_EnableSnooze	equ	08h
D_KeyRelDis		equ	10h
D_ToneOn		equ	20h
D_Alarming		equ	40h
D_24Mode		equ	80h		;must for bit7/24mode
	
.EXTERN		INT_PlayPWM	
.EXTERN		R_LEDFlag	
D_LED_ON		equ		0x08

.EXTERN		R_BLTime
D_5SecBL			equ	10
D_2SecBL			equ	4

.EXTERN		R_KeyValue		
.EXTERN		R_KeyTemp		
;.EXTERN		R_SpecFlag		
	
.EXTERN		R_SetBack					
.EXTERN		R_OldKeyValue
D_KeyFcClear		equ		0x01
D_KeyAllTime		equ		0x02
D_KeyLight			equ		0x04
D_KeyUnused		equ		0x08
.EXTERN		R_DebounceCnt	
C_KeyDebounce		equ		2		;30ms 
	
.EXTERN		R_LEDTemp	
.EXTERN		F_Check_LED

	
;.EXTERN		R_SleepTime
C_Sleep20Sec			equ 	40	;120/2=60sec
	
.EXTERN		R_LongKeyTime
C_LongKey2Sec			equ		255
C_FastAdd				equ		24		;1√Îº”8¥Œ
	
.EXTERN			R_KeyFlag1	
D_TimeFlag			equ		01h
D_Timering_Short	equ		02H
D_NoKeyTone			equ		04H
D_DC				equ		08H
D_EnableSnooze1		equ		10h
;===================================================
;			Module Define
;====================================================
.EXTERN	        F_KeyScan	
.EXTERN			InitLED
.EXTERN			F_PlayKeyTone
.EXTERN			F_2Hz_Cnt
.EXTERN			F_initSet

.EXTERN			F_DC_Judge	
.EXTERN		F_backlightOpen
