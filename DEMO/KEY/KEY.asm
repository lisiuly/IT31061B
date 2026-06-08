.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE	GPL813X.inc
.INCLUDE	SYS\Macro.inc
.include	RTC\RTC.inc
.INCLUDE	SYS\Project.inc
.INCLUDE	Alarm\Alarm.inc
.INCLUDE	LCD\LCD_Display.inc
.INCLUDE	RF\RF.inc
;.INCLUDE	RFC\RFC.inc
;==========================================
; External declare area
;==========================================   

;==========================================
; Public declare area
;==========================================
.PUBLIC	        F_KeyScan	

;==========================================
; Public declare area
;==========================================
;.PUBLIC		R_Option
.PUBLIC		R_Set
.PUBLIC		R_LEDFlag	
;.PUBLIC		R_LampTime		;play LED time
.PUBLIC		R_BLTime		
.PUBLIC		R_KeyValue		
.PUBLIC		R_KeyTemp		
;.PUBLIC		R_SpecFlag		
.PUBLIC		R_LongKeyTime	
.PUBLIC		R_SetBack					
.PUBLIC		R_OldKeyValue
.PUBLIC		R_DebounceCnt
.PUBLIC		R_LEDTemp
.PUBLIC		R_KeyFlag
.PUBLIC		F_Check_LED
;.PUBLIC		InitLED
;.PUBLIC		Enable_KeyTone
;.PUBLIC		Down_Month
;.PUBLIC		Sub_AlmMinute
;.PUBLIC		Down_Year
;.PUBLIC		Sub_AlmHour
;.PUBLIC		Sub_AlmHour
;.PUBLIC		Down_Day
.PUBLIC			R_KeyFlag1	
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0
;R_Option		ds	1
R_Set			ds	1
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

R_KeyFlag		ds	1
D_KeyTone		equ	01h
D_EnableFastAdd	equ	02h		
D_EnableAlarm	equ	04h
D_EnableSnooze	equ	08h
D_KeyRelDis		equ	10h
D_ToneOn		equ	20h
D_Alarming		equ	40h
D_24Mode		equ	80h		;must for bit7/24mode
	
R_KeyFlag1		ds	1
D_TimeFlag			equ		01h
D_Timering_Short	equ		02H
D_NoKeyTone			equ		04H
D_DC				equ		08H	
D_EnableSnooze1		equ		10h

R_LEDFlag		ds	1
D_LED_ON	equ		0x08		;无DC有小亮

;R_LampTime		ds	1		;play LED time
;D_LampTime		equ	20h

R_BLTime			ds	1
D_8SecBL			equ	16
D_2SecBL			equ	4
D_20Sec				equ	40

Key_Status			ds		1
R_LongKeyTime		ds		1		
	
R_TempTime			ds		1
R_SetBack			ds		1
C_Sleep20Sec	equ	40	


;---------------------------------------------------
C_LongKey2Sec		equ		4
C_FastAdd			equ		24		;1秒加8次

R_KeyTemp			ds		1	
R_KeyValue			ds		1		
R_OldKeyValue		ds		1
D_KeyFcClear		equ		0x01
D_KeyAllTime		equ		0x02
D_KeyLight			equ		0x04
D_KeyUnused		equ		0x08


R_DebounceCnt		ds		1
C_KeyDebounce		equ		2	
;---------------------------------------------------
R_LEDTemp		ds	1

R_ToneDuty		ds	1
R_ToneVol		ds	1
;=====================================================
.CODE

; 输入: PE0/PE1/PE2 当前按键电平、历史键值和去抖状态。
; 输出: 更新 R_KeyValue/R_OldKeyValue，并在按键释放时分发到对应短按功能。
; 调试: 看 R_KeyTemp、R_KeyValue、R_OldKeyValue、R_DebounceCnt 的变化。
F_KeyScan:	
		; PE0 = LIGHT, PE1 = C/F, PE2 = CH
		LDA		P_IO_PortE_Data
		AND		#(D_Bit2+D_Bit1+D_Bit0)
		BEQ		?ReleaseAllKey

		LDA		#00H
		STA		R_KeyTemp

		LDA		P_IO_PortE_Data
		AND		#D_Bit0
		BEQ		?L_CheckFcClearKey
		LDA		R_KeyTemp
		ORA		#D_KeyLight
		STA		R_KeyTemp

	?L_CheckFcClearKey:
		LDA		P_IO_PortE_Data
		AND		#D_Bit1
		BEQ		?L_CheckAllTimeKey
		LDA		R_KeyTemp
		ORA		#D_KeyFcClear
		STA		R_KeyTemp

	?L_CheckAllTimeKey:
		LDA		P_IO_PortE_Data
		AND		#D_Bit2
		BEQ		?L_HaveKey
		LDA		R_KeyTemp
		ORA		#D_KeyAllTime
		STA		R_KeyTemp

	?L_HaveKey:
		LDA		R_KeyTemp
		CMP		R_KeyValue
		BEQ		?CheckKeyDebounce
		LDA		R_KeyTemp
		STA		R_KeyValue
		LDA		#C_KeyDebounce
		STA		R_DebounceCnt
		CLI
		RTS
				
?ReleaseAllKey:					;按键释放
		%btst	R_KeyFlag,D_KeyRelDis,?L_Exit	
		LDA	R_OldKeyValue
		BEQ	?L_Exit
		
	?L_Dis_KeyTone:		
		LDA		R_OldKeyValue
		CMP		#D_KeyLight
		BNE		$+5		
		JMP		Enable_LightKey			

		CMP		#D_KeyAllTime
		BNE		$+5		
		JMP		Enable_AllTimeKey

		CMP		#D_KeyFcClear
		BNE		$+5		
		JMP		Enable_FcClearKey
		
	?L_Exit:		        ; 将按键值变量清零，退出
		LDA		#00
		STA		R_OldKeyValue
		STA		R_KeyValue
		STA		R_KeyTemp
		LDA	#C_KeyDebounce
		STA	R_DebounceCnt
		LDA	#C_LongKey2Sec
		STA	R_LongKeyTime
		%bitr	R_KeyFlag,(D_EnableFastAdd+D_KeyRelDis)
		RTS
		
?CheckKeyDebounce:
		LDA	R_DebounceCnt
		BEQ	?Key_Process		
		RTS	

	?Key_Process:
		LDA	R_KeyValue
		CMP	R_OldKeyValue
		BEQ	$+5
		JMP	Enable_NewKey	
		

; 输入: 当前保持中的键值与长按倒计时。
; 输出: 长按超时后分发到对应长按功能入口。
; 调试: 看 R_LongKeyTime 归零时是否跳到目标长按处理函数。
Hold_Key:							;长按按键功能
		LDA		R_LongKeyTime
		BNE		?L_LongExit
		LDA		#C_LongKey2Sec
		STA		R_LongKeyTime
		LDA		R_OldKeyValue
		AND		#D_KeyAllTime
		BNE		?L_LongAllTimeKey
		LDA		R_OldKeyValue
		AND		#D_KeyFcClear
		BEQ		?L_LongExit
		JMP		Enable_longFcClearKey
	?L_LongAllTimeKey:
		JMP		Enable_longAllTimeKey
	?L_LongExit:
		RTS
				
; 输入: 已通过去抖的新键值。
; 输出: 把当前键值记为旧键，并装入长按计时初值。
; 调试: 看 R_OldKeyValue 和 R_LongKeyTime 是否在新按键进入时被正确更新。
Enable_NewKey:
		LDA		R_KeyValue
		STA		R_OldKeyValue		
		LDA		#C_LongKey2Sec
		STA		R_LongKeyTime	;长按2秒开始计时
		RTS
	
; 输入: CH 短按释放事件。
; 输出: 标记按键刷新，并切到下一个室外通道/循环模式。
; 调试: 看 R_RFChannel、R_RFViewChannel 和 AddOthers 是否同步变化。
Enable_AllTimeKey:			; 28 规格：CH 短按按 CH1 -> CH2 -> CH3 -> Auto 循环切换
		JSR		F_UpdateKey
		JMP		F_RF_SelectNextChannel
;===================FcClearKey======================	 		
; 输入: C/F 短按释放事件。
; 输出: 标记按键刷新，并翻转当前温度单位标志。
; 调试: 看 R_SpecFlag.D_TF 与界面单位图标是否同步变化。
Enable_FcClearKey:			; 短按切换 C/F，Mold 页循环阈值
		JSR		F_UpdateKey	
		LDA		R_SpecFlag
		EOR		#D_TF
		STA		R_SpecFlag
		RTS

; 输入: C/F 长按事件。
; 输出: 当前产品无长按功能，仅保留统一按键刷新入口。
; 调试: 看长按 C/F 时不会触发额外状态改变。
Enable_longFcClearKey:
		JSR		F_UpdateKey
		RTS

LongFcClearKey_Exit:
		RTS

; 输入: CH 长按释放事件。
; 输出: 标记按键刷新，清当前显示通道并进入 3 分钟长接收。
; 调试: 看当前通道缓存、R_RFStatus 和 LongRecv 状态是否被重置。
Enable_longAllTimeKey:
		JSR		F_UpdateKey
		JMP		F_RF_ClearCurrentChannel

LongAllTimeKey_Exit:
		RTS
		
				
;==========================================
; 输入: LIGHT 短按释放事件。
; 输出: 标记按键刷新并打开背光 8 秒。
; 调试: 看 R_BLTime、R_LEDFlag 和 PB0 输出是否立即生效。
Enable_LightKey:	
		JSR		F_UpdateKey
		JMP		F_backlightOpen


.PUBLIC		F_backlightOpen		
; 输入: 无。
; 输出: 直接点亮背光，并把背光倒计时装成 8 秒。
; 调试: 看 R_LEDFlag、R_BLTime、P_IO_PortB_Data bit0。
F_backlightOpen:
		CLI
		LDA		#D_LED_ON
		STA		R_LEDFlag
		LDA		P_IO_PortB_Data
		ORA		#D_Bit0
		STA		P_IO_PortB_Data
		LDA		#00H
		STA		R_LEDTemp
		LDA		#D_8SecBL
		STA		R_BLTime
		RTS

		
; .PUBLIC		INT_PlayPWM
; ; 输入: 当前背光开关标志 R_LEDFlag。
; ; 输出: 在中断里把 PB0 直接拉高/拉低，维持背光实际电平。
; ; 调试: 看 D_LED_ON 与 PB0 电平是否一致。
; INT_PlayPWM:				;在中断里调用
; 	    LDA     R_LEDFlag
; 	    AND     #D_LED_ON
; 	    BEQ     ?DisLED		; 背光改成直接高低电平，不再做软件 PWM
; 		LDA		P_IO_PortB_Data
; 		ORA		#D_Bit0
; 		STA		P_IO_PortB_Data
; 		RTS

; 	?DisLED:
; 		LDA		P_IO_PortB_Data
; 		AND		#.not.D_Bit0
; 		STA		P_IO_PortB_Data
; 		RTS			
		
		
;		28规格当前产品没有 12/24H 切换入口，这个旧时钟 helper 先屏蔽保留。
;		Check_1224Mode:		
;			LDA	R_KeyFlag
;			EOR	#D_24Mode
;			STA	R_KeyFlag
;			RTS		
.PUBLIC		F_PlayKeyTone		
; 输入: 按键音使能位、当前 ToneOn 状态。
; 输出: 以非阻塞方式触发一次按键音计时。
; 调试: 看 D_KeyTone、D_ToneOn 与 R_KeyToneTm 的联动。
F_PlayKeyTone:		;键音
;		%btst	R_KeyFlag1,D_NoKeyTone,?Dis_KeyTone		
		%btst	R_KeyFlag,D_KeyTone,F_EnKeyTone		
	?Dis_KeyTone:	
		RTS	
 F_EnKeyTone:
		; 键音改成非阻塞触发，避免在主循环里忙等卡住喂狗。
		LDA		R_KeyFlag
		AND		#D_ToneOn
		BNE		?L_KeyToneExit
		%bits	R_KeyFlag,D_ToneOn	
		LDA		#08
		STA		R_KeyToneTm	
		?L_Loop:
		LDA		R_KeyToneTm
		BNE		?L_Loop
		%bitr	R_KeyFlag,D_ToneOn
		?L_KeyToneExit:
		RTS	

;===============================================================
	; 输入: 当前背光倒计时 R_BLTime。
	; 输出: 每 0.5 秒递减一次背光计时，到 0 后关闭背光输出。
	; 调试: 看 R_BLTime 归零时 R_LEDFlag 和 PB0 是否同步清零。
	F_Check_LED:
		LDA		R_BLTime
		BEQ		?Exit_LED
		DEC		R_BLTime
		BNE		?Exit_LED
		LDA		#00
		STA		R_LEDFlag
		STA		R_LEDTemp
		LDA		P_IO_PortB_Data
		AND		#.not.D_Bit0
		STA		P_IO_PortB_Data
		?Exit_LED:		
		RTS
;==============================================================
; 输入: 一次有效按键事件。
; 输出: 触发按键音、禁止重复释放，并在背光已亮时续时到 8 秒。
; 调试: 看 D_KeyTone、D_KeyRelDis、R_BLTime、AddOthers 是否同步更新。
F_UpdateKey:						
;		%bits	R_KeyFlag,D_KeyTone
		%bits	R_KeyFlag,D_KeyRelDis	
		LDA		R_BLTime
		BEQ		F_UpdateKey2
		LDA		#D_8SecBL
		STA		R_BLTime
F_UpdateKey2:							
		LDA		#C_Sleep20Sec
		STA		R_SetBack
		%bits	R_TimeStatus,AddOthers			
		RTS	
		
C_Disp3sShowCount	equ	6		;6 tick × 0.5s = 3 秒，室外掉码虚线闪烁显示时长

.PUBLIC		F_2Hz_Cnt		
; 输入: 2Hz 半秒节拍。
; 输出: 推进长按计时、背光计时、界面自动返回计时和温度保持计时。
; 调试: 看 R_LongKeyTime、R_BLTime、R_SetBack、R_TempTime 是否按半秒变化。
F_2Hz_Cnt:
		LDA		R_LongKeyTime
		BEQ		CheckKeyHoldTimeout
		DEC		R_LongKeyTime

CheckKeyHoldTimeout:
		jsr		Check_SetBackTime
		JSR		F_Check_LED

		; 室外掉码 --.- 3秒闪烁计时（2Hz 节拍）
		LDA		R_OutdoorFlashRun
		BEQ		?F2Hz_NoFlash
		LDA		R_Disp3s
		BEQ		?F2Hz_NoFlash
		DEC		R_Disp3s
		BNE		?F2Hz_NoFlash
		; 刚减到 0：置 BlankPending
		LDA		#01H
		STA		R_OutdoorBlankPending
?F2Hz_NoFlash:
		LDA		R_OutdoorBlanking
		BEQ		?F2Hz_NoBlanking
		DEC		R_OutdoorBlanking
		BNE		?F2Hz_NoBlanking
		LDA		#C_Disp3sShowCount
		STA		R_Disp3s
?F2Hz_NoBlanking:
		
; ; 输入: 最大/最小温度保持标志和保持计时。
; ; 输出: 到时后清掉极值保持状态。
; ; 调试: 看 R_TempTime 归零时 D_MaxTemp/D_MinTemp 是否清除。
; F_Check_Temp:
; 		%btsf	R_TempFlag1,(D_MaxTemp+D_MinTemp),?Exit_Check
; 		LDA		R_TempTime
; 		BEQ		?Exit_Check
; 		DEC		R_TempTime
; 		BNE		?Exit_Check
;  		%bitr	R_TempFlag1,(D_MaxTemp+D_MinTemp) 
; 		?Exit_Check:		
; 		RTS		
	
; 输入: 自动返回计时 R_SetBack。
; 输出: 计时归零后退出设置态并请求界面刷新。
; 调试: 看 R_SetBack 归零时 R_Set 和 AddOthers 是否同步更新。
Check_SetBackTime:
		LDA		R_SetBack
		BEQ		?L_Exit		
		dec		R_SetBack
		bne		?L_Exit	
		LDA		#00H
		STA		R_Set
		%bits	R_TimeStatus,AddOthers	
	?L_Exit:	
		RTS
		
;.PUBLIC		F_DC_Judge	
;F_DC_Judge:
;		LDA		P_IO_PortE_Data
;		AND		#D_Bit2
;		BNE		?L_HaveDC
;		%btsf	R_KeyFlag1,D_DC,?L_Exit		
;		%bitr	R_KeyFlag1,D_DC		
;		LDA		#00
;		STA		R_LEDFlag
; 		LDA     #$25        ;中亮占空比
;  		STA     R_ToneVol
;  	?L_Exit:	
;  		RTS
;	?L_HaveDC:
;		%btst	R_KeyFlag1,D_DC,?L_Exit	
;		%bits	R_KeyFlag1,D_DC			
;		JMP		HasDC_LED_1		
;;		RTS	
;	
.PUBLIC		F_initSet		
; 输入: 无。
; 输出: 初始化设置态计时，并同步初始化温湿度记录缓存。
; 调试: 看 R_Set、R_SetBack 以及 F_Start_RFCMM_Value 的结果。
F_initSet:
		; LDA		#D_TimeMode
		; STA		R_Mode
		LDA		#00H
		STA		R_Set
		LDA		#C_Sleep20Sec
		STA		R_SetBack
		LDA		#C_Disp3sShowCount
		STA		R_Disp3s
;		JMP		F_Start_RFCMM_Value
		RTS
	
.end





