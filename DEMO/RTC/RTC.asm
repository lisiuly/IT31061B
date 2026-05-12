.INCLUDE	SYS\Macro.inc
.INCLUDE	KEY\KEY.inc
.INCLUDE	Alarm\Alarm.inc
;.INCLUDE	RFC\RFC.inc
;==============================================================================
; Public declare area
;==============================================================================
.PUBLIC			F_ResetRealTimeClock
.PUBLIC			F_RealTimeClock
.PUBLIC			F_ClearIncStatus
.PUBLIC			INC_SEC	
.PUBLIC			INC_MIN  
.PUBLIC			INC_MIN1
.PUBLIC			INC_MIN2
.PUBLIC			INC_HR 
.PUBLIC			INC_HR1
.PUBLIC			INC_HR2		;x for RAM, a for Max 
.PUBLIC			R_TimeStatus
.PUBLIC			RTC
;==========================================
; Constant define area
;==========================================
;YearMonthDate	        EQU	    1			 ;define year month date enable 		
	
;------------------------------------------------------------------------------
.PAGE0
;
RTC		             .DS	 3
	; RTC+0 --> Hour (BCD)
	; RTC+1 --> Minute (BCD)
	; RTC+2 --> Second (BCD)
	;  -------------------------------------------
	; |             | RTC+0   | RTC+1   | RTC+2   |
	; |-------------|---------|---------|---------|
	; | Description | Hour    | Minute  | Second  |
	; |	            | 00 - 23 | 00 - 59 | 00 - 59 |        
	; |		        | (BCD)   | (BCD)   | (BCD)   |         |
	;  -------------------------------------------
;
R_TimeStatus	    .DS	    1       ;(.7 reserved!!!)
HalfSecToggle			EQU		01000000B
AddSecondOnly			EQU		00100000B
AddOthers				EQU		00010000B
TR00				.DS	    1
TR01				.DS		1
;------------------------------------------------------------------------------
.CODE
;==============================================================================
F_RealTimeClock:	;Level 1
	LDA	#HalfSecToggle
	EOR	R_TimeStatus
	STA	R_TimeStatus
	AND	#HalfSecToggle
	BNE	L_Time99	; 0.5 second only!!!
;	1 second!!!
	JSR	INC_SEC	;Level 2  
	BCC	L_OnlySEcAdd

	JSR	INC_MIN	;Level 2
	BCC	L_OnlyMinAdd
	
	
	JSR	INC_HR	;Level 2
	; 28规格当前产品只消费时分秒与 AddOthers 标志，不再读 DATE/星期。
	; 旧时钟产品的日期进位链先屏蔽保留，避免继续维护未使用状态。
	BCC	L_OnlyHourAdd
	; JSR	INC_DAT	;Level 3
	; BCC	L_Time01
	; JSR	INC_MON	;Level 2
	; BCC	L_Time01
	; JSR	INC_YER	;Level 2
L_Time01:
	; JSR	WEEKCAL	;Level 3
	; JSR	MAXDCMP	;Level 3
L_OnlyHourAdd:
L_OnlyMinAdd:	
	LDA	#AddOthers
	BNE	L_AddAll	;@JMP
L_OnlySEcAdd:
	LDA	#AddSecondOnly
L_AddAll:
	ORA	R_TimeStatus
	STA	R_TimeStatus
L_Time99:
	RTS
;
;------------------------------------------------------------------------------
;
F_ClearIncStatus:
	LDA	#(.NOT.(AddSecondOnly+AddOthers))
	AND	R_TimeStatus
	STA	R_TimeStatus
	RTS
;
;------------------------------------------------------------------------------
;
F_ResetRealTimeClock:          ;开机显示初值(默认值)
	LDA	#00H
	STA	RTC+0
	LDA	#00H
	STA	RTC+1
	LDA	#00H		;test use
	STA	RTC+2	
	LDA	#AddOthers
	STA	R_TimeStatus
	RTS

INC_SEC:
	LDX	#RTC+2   ;second
	JMP	INC_MIN1
INC_MIN:
	LDX	#RTC+1   ;Minute
INC_MIN1:
	LDA	#59H
	STA	TR01
INC_MIN2:
	LDA	#00
	STA	TR00
	JMP	INC_DET
;
INC_HR:
	LDX	#RTC+0
INC_HR1:
	LDA	#23H
INC_HR2:
	STA	TR01
	JMP	INC_MIN2
INC_DET:
	LDA	R_TimeStatus
	BMI	DEC_DET
	LDA	0,X
	CMP	TR01
	BCS	INC_D01
	LDA	#01
	STA	TR00
	JMP	ADC_RT
INC_D01:
	LDA	TR00
INC_D02:
	STA	0,X
	SEC
	RTS
;
DEC_DET:
	LDA	0,X
	CMP	TR00
	BEQ	DEC_D01
	LDA	#99H
	STA	TR00
	JMP	ADC_RT
DEC_D01:
	LDA	TR01
	JMP	INC_D02
;
; Use:	TR00 - variable
;	TR01 - (X)
;	(X) = TR01+TR00
ADC_RT:
	CLC
	LDA	0,X
	STA	TR01
	AND	#00001111B
	ADC	TR00
	ADC	#6
	EOR	TR00
	AND	#11110000B
	BEQ	L_TimeAdd01
	LDA	#6
L_TimeAdd01:
	ADC	TR00
	ADC	TR01
	BCS	L_TimeAdd02
	CMP	#9AH
	BCC	L_TimeAdd03
L_TimeAdd02:
	ADC	#05FH
L_TimeAdd03:
	STA	0,X
	CLC
	RTS
.END	




