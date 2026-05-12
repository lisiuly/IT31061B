;==========================================
.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE 	GPL813x.inc
.INCLUDE	sys\Macro.inc
.INCLUDE	key\Key.inc
.INCLUDE	rtc\RTC.inc
.INCLUDE	Alarm\Alarm.inc

;.INCLUDE	Project.inc
.INCLUDE	GXHTV4\GXHTV4.inc
.INCLUDE	RF\RF.inc
;==========================================
; Public declare area
;==========================================
.PUBLIC			R_TempBuf
;==========================================
; Public declare area
;==========================================
.PUBLIC			T_Icon
.PUBLIC			LcdMapTab
.PUBLIC			T_NumberTable
.PUBLIC			F_Display
.PUBLIC			F_DisplayProductUI
.PUBLIC			F_DisplayHLValue
;==========================================
; Variable RAM declare area
;==========================================

; R_Mode	ds	1
; D_TimeMode	equ	01h
; D_AlarmMode	equ	02h
; D_DateMode	equ	04h

R_TempBuf		ds	7
R_OutdoorNoDataDash	ds	1

;=======================================================================
.CODE
.INCLUDE	LCD\LCD_Display.tab

;===================================================================
; Shared record initialization helper, still used by KEY.asm.
;===================================================================
.PUBLIC			F_Start_RFCMM_Value
; 输入: 当前已经准备好的室内温湿度显示缓存与符号标志。
; 输出: 初始化温湿度最大/最小记录缓存，供上电后极值与记录页复用。
; 调试: 看 R_TempMin/Max、R_MIN/MAXDispTemper_F、R_HumMin/Max 是否被当前值覆盖。
F_Start_RFCMM_Value:
	%bitr	R_TempFlag1,(D_MaxTemp+D_MinTemp)
	LDA		#00H
	LDA		R_DispTemper+0
	STA		R_TempMin+0
	STA		R_TempMax+0
	LDA		R_DispTemper+1
	STA		R_TempMin+1
	STA		R_TempMax+1
	LDA		R_DispTemper_F
	STA		R_MINDispTemper_F
	STA		R_MAXDispTemper_F

	LDA		R_DispTemper_F+1
	STA		R_MINDispTemper_F+1
	STA		R_MAXDispTemper_F+1

	LDA		R_DispHum
	STA		R_HumMax
	STA		R_HumMin

	LDA		R_SpecFlag
	STA		R_TempMax_Sign
	STA		R_TempMin_Sign

	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMax_Sign
	STA		R_TempMax_Sign

	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMin_Sign
	STA		R_TempMin_Sign
	RTS

;==============================================================================
; 产品显示框架
; 86428 规格只保留标准显示页，这里直接走标准刷新链。
;==============================================================================
; 输入: R_TimeStatus 的 AddOthers/AddSecondOnly 以及当前 RF 无数据闪烁状态。
; 输出: 在需要刷新时重绘标准页主体；否则直接返回。
; 调试: 看 R_TimeStatus、Disp_ProductIsOutdoorLostFlashMode 的返回以及 LCD DpRam 是否更新。
F_Display:
F_DisplayProductUI:
			LDA		R_TimeStatus
			AND		#AddOthers
			BNE		Disp_ProductUpdateAll
			LDA		R_TimeStatus
			AND		#AddSecondOnly
			BEQ		Disp_ProductDisplayExit
			JSR		Disp_ProductIsOutdoorLostFlashMode
			BCC		Disp_ProductDisplayExit

Disp_ProductUpdateAll:
			; 86428 新玻璃只保留当前页，不再驱动旧页签位。
			JSR		Disp_ProductRefreshPagedBody
	Disp_ProductDisplayExit:
			RTS

; 输入: 已经判定本次需要刷新整页。
; 输出: 清增量标志并刷新标准显示页的公共主体。
; 调试: 看 F_ClearIncStatus 后 R_TimeStatus，以及后续各显示 helper 是否被调用。
Disp_ProductRefreshPagedBody:
			; 标准页整页刷新：清增量标志，并刷新当前值/趋势/低电主体。
			JSR		F_ClearIncStatus
			JSR		Disp_ProductRefreshCommonBody
			RTS


; 输入: 当前室内/室外缓存与图标状态。
; 输出: 先缓存室外无数据态，再刷新数值区和状态图标区。
; 调试: 看 R_OutdoorNoDataDash、室内外数值位和状态图标位是否一起更新。
Disp_ProductRefreshCommonBody:
			; 当前玻璃主体分成两块：室内 GXHTV4 和室外 RF 通道显示。
			JSR		Disp_ProductCacheOutdoorDashDecision
			JSR		Disp_ProductRefreshValueArea
			JMP		Disp_ProductRefreshStatusIcons


; 输入: Alarm 室内当前值与当前视图 RF 通道数据。
; 输出: 刷新室内温湿度和室外温湿度数值区。
; 调试: 看当前值数码位是否与 R_DispTemper/RF 缓存一致。
Disp_ProductRefreshValueArea:
			; 室内用本地 GXHTV4 当前值，室外用当前视图 RF 通道值。
			JSR		Disp_ProductCurrentTemp
			JSR		Disp_ProductCurrentHum
			JSR		Disp_ProductOutdoorTemp
			JMP		Disp_ProductOutdoorHum


; 输入: 静态图标、低电状态、RF 图标与通道状态。
; 输出: 刷新标准页状态图标区。
; 调试: 看 Bat/OutBat/RF/CH/Loop 等 icon 位是否符合当前状态。
Disp_ProductRefreshStatusIcons:
			; 新玻璃保留：室内/室外标签、趋势、低电、RF、CH/Loop。
			JSR		Disp_ProductShowStaticIcons
			JSR		Disp_ProductRefreshTrendIcons
			JSR		Disp_ProductShowBatteryIcon
			JSR		Disp_ProductShowOutdoorBatteryIcon
			JSR		Disp_ProductShowRFChannelIcons
			JMP		Disp_ProductShowRFStateIcon


; 输入: Alarm 室内趋势位与 RF 每通道趋势位。
; 输出: 刷新室内外温湿度趋势图标。
; 调试: 看 T_Up/TEq/TDn 与 OutT*/OutH* 图标是否符合对应趋势位。
Disp_ProductRefreshTrendIcons:
			; 室内趋势继续直接读 Alarm，室外趋势改成读 RF 每通道缓存的趋势位。
			JSR		Disp_ProductShowTempTrend
			JSR		Disp_ProductShowHumTrend
			JSR		Disp_ProductShowOutdoorTempTrend
			JMP		Disp_ProductShowOutdoorHumTrend


; 输入: R_TrendFlags 的室内温度趋势位。
; 输出: 互斥显示室内温度 Up/Down/Eq 图标。
; 调试: 看 T_TUp/T_TEq/T_TDn 三个位是否只亮一个。
Disp_ProductShowTempTrend:
			LDA		R_TrendFlags
			AND		#(D_TrendTempUp+D_TrendTempDown)
			BEQ		Disp_ProductShowTempTrendEq
			CMP		#D_TrendTempUp
			BEQ		Disp_ProductShowTempTrendUp
			LDX		#T_TUp
			JSR		NoDisplay_OneBit
			LDX		#T_TEq
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JMP		Display_OneBit

Disp_ProductShowTempTrendUp:
			LDX		#T_TEq
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JSR		NoDisplay_OneBit
			LDX		#T_TUp
			JMP		Display_OneBit

Disp_ProductShowTempTrendEq:
			LDX		#T_TUp
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JSR		NoDisplay_OneBit
			LDX		#T_TEq
			JMP		Display_OneBit


; 输入: R_TrendFlags 的室内湿度趋势位。
; 输出: 互斥显示室内湿度 Up/Down/Eq 图标。
; 调试: 看 T_HUp/T_HEq/T_HDn 三个位是否只亮一个。
Disp_ProductShowHumTrend:
			LDA		R_TrendFlags
			AND		#(D_TrendHumUp+D_TrendHumDown)
			BEQ		Disp_ProductShowHumTrendEq
			CMP		#D_TrendHumUp
			BEQ		Disp_ProductShowHumTrendUp
			LDX		#T_HUp
			JSR		NoDisplay_OneBit
			LDX		#T_HEq
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JMP		Display_OneBit

Disp_ProductShowHumTrendUp:
			LDX		#T_HEq
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JSR		NoDisplay_OneBit
			LDX		#T_HUp
			JMP		Display_OneBit

Disp_ProductShowHumTrendEq:
			LDX		#T_HUp
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JSR		NoDisplay_OneBit
			LDX		#T_HEq
			JMP		Display_OneBit

; 输入: 本机低电标志 R_BatteryFlags。
; 输出: 根据低电状态显示或熄灭本机电池图标。
; 调试: 看 T_Bat 是否仅在 D_BatteryLow 置位时显示。
Disp_ProductShowBatteryIcon:
			; 电池图标同样按目标状态直接更新，避免低电时先灭后亮。
			LDA		R_BatteryFlags
			AND		#D_BatteryLow
			BEQ		Disp_ProductShowBatteryIconHide
			LDX		#T_Bat
			JMP		Display_OneBit
Disp_ProductShowBatteryIconHide:
			LDX		#T_Bat
			JMP		NoDisplay_OneBit


; 输入: 无，固定标准页静态图标集合。
; 输出: 亮起室内/室外标签、单位与小数点等常驻图标。
; 调试: 看 In/Out 标签、HuUnit、TempDot 是否始终保持显示。
Disp_ProductShowStaticIcons:
			LDX		#T_InTempHum
			JSR		Display_OneBit
			LDX		#T_OutTemp
			JSR		Display_OneBit
			LDX		#T_OutHum
			JSR		Display_OneBit
			LDX		#T_InHuUnit
			JSR		Display_OneBit
			LDX		#T_OutHuUnit
			JSR		Display_OneBit
			LDX		#T_InTempDot
			JSR		Display_OneBit
			LDX		#T_OutTempDot
			JMP		Display_OneBit

; 室外趋势不在 LCD 刷新层里计算，只根据 RF 每通道的趋势状态位去显示。
; 这样 Auto 模式切换通道时，每个通道都能保持自己独立的 Up/Down/Eq 状态。
; 输入: 当前视图通道和对应的室外温度趋势位。
; 输出: 显示当前通道的室外温度趋势图标；无数据时清空。
; 调试: 看 Y 指向的 R_RFTrendFlags 与 OutTUp/OutTEq/OutTDn 图标是否一致。
Disp_ProductShowOutdoorTempTrend:
			JSR		Disp_ProductHasOutdoorData
			BCC		Disp_ProductClearOutdoorTempTrend
			LDA		R_RFTrendFlags,Y
			AND		#(D_RFTrendTempUp+D_RFTrendTempDown)
			BEQ		Disp_ProductShowOutdoorTempTrendEq
			CMP		#D_RFTrendTempUp
			BEQ		Disp_ProductShowOutdoorTempTrendUp
			LDX		#T_OutTUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutTEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutTDn
			JMP		Display_OneBit

Disp_ProductShowOutdoorTempTrendUp:
			LDX		#T_OutTEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutTDn
			JSR		NoDisplay_OneBit
			LDX		#T_OutTUp
			JMP		Display_OneBit

Disp_ProductShowOutdoorTempTrendEq:
			LDX		#T_OutTUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutTDn
			JSR		NoDisplay_OneBit
			LDX		#T_OutTEq
			JMP		Display_OneBit

Disp_ProductClearOutdoorTempTrend:
			LDX		#T_OutTUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutTEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutTDn
			JMP		NoDisplay_OneBit


; 输入: 当前视图通道和对应的室外湿度趋势位。
; 输出: 显示当前通道的室外湿度趋势图标；无数据时清空。
; 调试: 看 Y 指向的 R_RFTrendFlags 与 OutHUp/OutHEq/OutHDn 图标是否一致。
Disp_ProductShowOutdoorHumTrend:
			JSR		Disp_ProductHasOutdoorData
			BCC		Disp_ProductClearOutdoorHumTrend
			LDA		R_RFTrendFlags,Y
			AND		#(D_RFTrendHumUp+D_RFTrendHumDown)
			BEQ		Disp_ProductShowOutdoorHumTrendEq
			CMP		#D_RFTrendHumUp
			BEQ		Disp_ProductShowOutdoorHumTrendUp
			LDX		#T_OutHUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutHEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutHDn
			JMP		Display_OneBit

Disp_ProductShowOutdoorHumTrendUp:
			LDX		#T_OutHEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutHDn
			JSR		NoDisplay_OneBit
			LDX		#T_OutHUp
			JMP		Display_OneBit

Disp_ProductShowOutdoorHumTrendEq:
			LDX		#T_OutHUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutHDn
			JSR		NoDisplay_OneBit
			LDX		#T_OutHEq
			JMP		Display_OneBit

Disp_ProductClearOutdoorHumTrend:
			LDX		#T_OutHUp
			JSR		NoDisplay_OneBit
			LDX		#T_OutHEq
			JSR		NoDisplay_OneBit
			LDX		#T_OutHDn
			JMP		NoDisplay_OneBit


; 输入: 无。
; 输出: 清空当前页的全部室外趋势图标。
; 调试: 看 OutT*/OutH* 图标是否全部熄灭。
Disp_ProductClearOutdoorTrendIcons:
			JSR		Disp_ProductClearOutdoorTempTrend
			JMP		Disp_ProductClearOutdoorHumTrend


; 输入: 当前视图通道的 Valid/LowBat 标志。
; 输出: 仅在该通道有效且低电时显示室外低电图标。
; 调试: 看 R_RF1Flags,X 与 T_OutBat 的联动是否正确。
Disp_ProductShowOutdoorBatteryIcon:
			JSR		Disp_ProductLoadRFViewOffset
			LDA		R_RF1Flags,X
			AND		#(D_RFValid+D_RFLowBat)
			CMP		#(D_RFValid+D_RFLowBat)
			BNE		Disp_ProductShowOutdoorBatteryHide
			LDX		#T_OutBat
			JMP		Display_OneBit
Disp_ProductShowOutdoorBatteryHide:
			LDX		#T_OutBat
			JMP		NoDisplay_OneBit


; 输入: R_RFViewChannel 当前显示通道号。
; 输出: X 返回通道记录偏移，Y 返回趋势/同步数组索引。
; 调试: 切 CH1/CH2/CH3/Auto 时看 X/Y 是否落在 0/0、0Ah/1、14h/2。
Disp_ProductLoadRFViewOffset:
			; X 返回通道数据偏移(0/10/20)，Y 返回趋势数组索引(0/1/2)。
			LDX		#00H
			LDY		#00H
			LDA		R_RFViewChannel
			CMP		#D_RFCh2
			BNE		Disp_ProductLoadRFViewOffset_CheckCh3
			LDX		#0AH
			LDY		#01H
			RTS
Disp_ProductLoadRFViewOffset_CheckCh3:
			CMP		#D_RFCh3
			BNE		Disp_ProductLoadRFViewOffset_End
			LDX		#14H
			LDY		#02H
Disp_ProductLoadRFViewOffset_End:
			RTS


; 输入: 当前视图通道的配对、lost、同步和长接收状态。
; 输出: SEC=当前通道应显示最后一次室外数据，CLC=应显示无数据态。
; 调试: 看 Flags、SyncTm 和 LongRecv 三者组合下返回的进位位是否符合规格。
Disp_ProductHasOutdoorData:
			JSR		Disp_ProductLoadRFViewOffset
			LDA		R_RF1Flags,X
			AND		#D_RFNeedPair
			BNE		Disp_ProductHasOutdoorData_No
			LDA		R_RF1Flags,X
			AND		#D_RFLost
			BEQ		Disp_ProductHasOutdoorData_Yes
			; 连续 3 次失败只灭 RF 图标，但常规同步还在，所以继续显示最后值；
			; 只有同步被关掉且当前不在长接收里，才切到 60 分钟后的虚线闪烁态。
			LDA		R_RF1SyncTm,Y
			CMP		#C_RFSyncIdle
			BNE		Disp_ProductHasOutdoorData_Yes
			LDA		R_RFStatus
			AND		#D_RFLongRecv
			BEQ		Disp_ProductHasOutdoorData_No
	Disp_ProductHasOutdoorData_Yes:
			SEC
			RTS
Disp_ProductHasOutdoorData_No:
			CLC
			RTS


; 输入: 当前视图通道的配对、lost、同步和长接收状态。
; 输出: SEC=当前通道处于 60 分钟后的 lost flash 模式，CLC=否则。
; 调试: 看 NeedPair/Lost/SyncIdle/LongRecv 的组合是否只在目标模式下返回 SEC。
Disp_ProductIsOutdoorLostFlashMode:
			JSR		Disp_ProductLoadRFViewOffset
			LDA		R_RFStatus
			AND		#D_RFLongRecv
			BNE		Disp_ProductIsOutdoorLostFlashMode_No
			LDA		R_RF1Flags,X
			AND		#D_RFNeedPair
			BNE		Disp_ProductIsOutdoorLostFlashMode_No
			LDA		R_RF1Flags,X
			AND		#D_RFLost
			BEQ		Disp_ProductIsOutdoorLostFlashMode_No
			LDA		R_RF1SyncTm,Y
			CMP		#C_RFSyncIdle
			BNE		Disp_ProductIsOutdoorLostFlashMode_No
			SEC
			RTS
Disp_ProductIsOutdoorLostFlashMode_No:
			CLC
			RTS


; 输入: RTC 秒值；调用方已先确认处于 lost flash 模式。
; 输出: SEC=本帧应显示 dash，CLC=本帧应显示 blank。
; 调试: 看 RTC+2 每跨 3 秒时返回相位是否按规格翻转。
Disp_ProductIsOutdoorLostFlashOn:
			; 调用方已先确认处于 60 分钟后的 lost flash 模式，这里只负责算 3 秒相位。
			LDA		RTC+2
			PHA
			AND		#0FH
			STA		R_TempBuf
			PLA
			AND		#0F0H
			LSR		A
			LSR		A
			LSR		A
			LSR		A
			CLC
			ADC		R_TempBuf
	Disp_ProductIsOutdoorLostFlashOn_Mod3:
			CMP		#03H
			BCC		Disp_ProductIsOutdoorLostFlashOn_Check
			SEC
			SBC		#03H
			JMP		Disp_ProductIsOutdoorLostFlashOn_Mod3
	Disp_ProductIsOutdoorLostFlashOn_Check:
			BEQ		Disp_ProductIsOutdoorLostFlashOn_Yes
			CLC
			RTS
	Disp_ProductIsOutdoorLostFlashOn_Yes:
			SEC
			RTS


; 输入: 当前视图通道的 lost flash 模式与 RTC 秒相位。
; 输出: 把本帧室外无数据态缓存成 dash 或 blank，供温度/湿度共用。
; 调试: 看 R_OutdoorNoDataDash 是否在同一帧内被温度和湿度共用。
	Disp_ProductCacheOutdoorDashDecision:
			LDA		#01H
			STA		R_OutdoorNoDataDash
			JSR		Disp_ProductIsOutdoorLostFlashMode
			BCC		Disp_ProductCacheOutdoorDashDecision_End
			JSR		Disp_ProductIsOutdoorLostFlashOn
			BCS		Disp_ProductCacheOutdoorDashDecision_End
			LDA		#00H
			STA		R_OutdoorNoDataDash
	Disp_ProductCacheOutdoorDashDecision_End:
			RTS


; 输入: 已缓存的 R_OutdoorNoDataDash。
; 输出: SEC=当前室外无数据位应显示 dash，CLC=应显示 blank。
; 调试: 看温度和湿度 no-data 路径是否读到同一份决策结果。
	Disp_ProductShouldShowOutdoorDash:
			LDA		R_OutdoorNoDataDash
			BNE		Disp_ProductShouldShowOutdoorDash_Yes
				CLC
				RTS
	Disp_ProductShouldShowOutdoorDash_Yes:
				SEC
				RTS


; 输入: 当前 RF 通道选择与循环模式状态。
; 输出: 刷新 CH1/CH2/CH3/Loop 图标。
; 调试: 看 R_RFChannel、R_RFViewChannel 与 T_1/T_2/T_3/T_Loop 的联动。
Disp_ProductShowRFChannelIcons:
			LDX		#T_CH
			JSR		Display_OneBit
			LDX		#T_1
			JSR		NoDisplay_OneBit
			LDX		#T_2
			JSR		NoDisplay_OneBit
			LDX		#T_3
			JSR		NoDisplay_OneBit
			LDX		#T_Loop
			JSR		NoDisplay_OneBit
			LDA		R_RFChannel
			CMP		#D_RFAutoMode
			BNE		Disp_ProductShowRFChannelNumber
			LDX		#T_Loop
			JSR		Display_OneBit

Disp_ProductShowRFChannelNumber:
			LDA		R_RFViewChannel
			CMP		#D_RFCh2
			BEQ		Disp_ProductShowRFChannel2
			CMP		#D_RFCh3
			BEQ		Disp_ProductShowRFChannel3
			LDX		#T_1
			JMP		Display_OneBit
Disp_ProductShowRFChannel2:
			LDX		#T_2
			JMP		Display_OneBit
Disp_ProductShowRFChannel3:
			LDX		#T_3
			JMP		Display_OneBit


; 输入: RF 长接收、收包窗口和当前通道 Valid 状态。
; 输出: 长接收时按 1Hz 闪烁 RF 图标；平时按 Valid/RecvBusy 状态显示。
; 调试: 看 D_RFLongRecv、D_RFRecvBusy、D_RFValid 与 T_RF 的显示关系。
Disp_ProductShowRFStateIcon:
			LDA		R_RFStatus
			AND		#D_RFLongRecv
			BNE		Disp_ProductShowRFStateBlink
			LDA		R_RFStatus
			AND		#D_RFRecvBusy
			BNE		Disp_ProductShowRFStateOn
			JSR		Disp_ProductLoadRFViewOffset
			LDA		R_RF1Flags,X
			AND		#D_RFValid
			BEQ		Disp_ProductShowRFStateOff
	Disp_ProductShowRFStateBlink:
			LDA		R_TimeStatus
			AND		#HalfSecToggle
			BEQ		Disp_ProductShowRFStateOff
Disp_ProductShowRFStateOn:
			LDX		#T_RF
			JMP		Display_OneBit
Disp_ProductShowRFStateOff:
			LDX		#T_RF
			JMP		NoDisplay_OneBit

; 当前值直接使用兼容 RFC/GXHTV4 的实时缓冲。
; 先判断 HH/LL 和 C/F，再进入对应的具体显示分支。
; 输入: 室内当前温度缓冲和规格标志位。
; 输出: 按 HH/LL/C/F 规则刷新室内当前温度数码位和单位图标。
; 调试: 看 R_SpecFlag、R_DispTemper、R_DispTemper_F 对应的显示分支是否正确。
Disp_ProductCurrentTemp:
			%btst	R_SpecFlag,D_TempHH,Disp_ProductCurrentTempHH
			%btst	R_SpecFlag,D_TempLL,Disp_ProductCurrentTempLL
			%btst	R_SpecFlag,D_TF,Disp_ProductCurrentTempF
			JMP		Disp_ProductCurrentTempC

Disp_ProductCurrentTempHH:
			LDA		#0CH
			JMP		Disp_ProductDisplayCurrentTempCode

Disp_ProductCurrentTempLL:
			LDA		#0FH
			JMP		Disp_ProductDisplayCurrentTempCode

; HH/LL 这种异常码直接写三位数码位，不再走正常温度拆位流程。
; 输入: A=需要显示的异常码(0Ch=HH, 0Fh=LL)。
; 输出: 直接把异常码写到室内温度三位数码位。
; 调试: 看 CurTeH/M/L 是否都写入同一个异常码。
Disp_ProductDisplayCurrentTempCode:
			PHA
			LDX		#T_CurTeH
			JSR		F_LcdDisplayDigital
			PLA
			PHA
			LDX		#T_CurTeM
			JSR		F_LcdDisplayDigital
			PLA
			LDX		#T_CurTeL
			JSR		F_LcdDisplayDigital
			JSR		Disp_ProductShowCurrentUnit
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

; 当前温度单位图标互斥显示，只保留 C 或 F 其中一个。
; 输入: R_SpecFlag.D_TF 当前单位状态。
; 输出: 互斥显示室内 C/F 单位图标。
; 调试: 看 T_InCUnit/T_InFUnit 是否始终只有一个亮。
Disp_ProductShowCurrentUnit:
			%btst	R_SpecFlag,D_TF,Disp_ProductShowCurrentUnitF

Disp_ProductShowCurrentUnitC:
			LDX		#T_InCUnit
			JSR		Display_OneBit
			LDX		#T_InFUnit
			JMP		NoDisplay_OneBit

Disp_ProductShowCurrentUnitF:
			LDX		#T_InCUnit
			JSR		NoDisplay_OneBit
			LDX		#T_InFUnit
			JMP		Display_OneBit

; 华氏度当前值不再重算，直接使用 Alarm 里已经准备好的 BCD 结果。
; 输入: Alarm 已准备好的室内华氏 BCD 缓冲。
; 输出: 刷新室内华氏当前温度，并处理 100 图标显示。
; 调试: 看 R_DispTemper_F 和 T_CurTe100 是否在 100.0F 边界处正确。
Disp_ProductCurrentTempF:
			LDA		R_DispTemper_F+0
			STA		R_TempBuf+5
			LDA		R_DispTemper_F+1
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderCurrentTempFromBuf
			JSR		Disp_ProductShowCurrentUnitF
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			; 华氏当前值按 0.1 度存成 BCD，100 图标要看高字节高 nibble
			; 是否非 0，也就是 100.0F 以上的千位。
			LDA		R_TempBuf+5
			AND		#0F0H
			BEQ		Disp_ProductCurrentTempF_No100
			LDX		#T_CurTe100
			JMP		Display_OneBit

Disp_ProductCurrentTempF_No100:
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit
			
; 摄氏度当前值走实时原始温度，重新转一次 BCD 后再显示。
; 这样能统一处理负号、百位留空和当前值三位数码位布局。
; 输入: 室内摄氏 BCD 缓冲和负号状态。
; 输出: 刷新室内摄氏当前温度，并按需要显示负号。
; 调试: 看 R_DispTemper、D_Neg 与 T_TeNeg 的联动是否正确。
Disp_ProductCurrentTempC:
			LDA		R_DispTemper+0
			STA		R_TempBuf+5
			LDA		R_DispTemper+1
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderCurrentTempFromBuf
			JSR		Disp_ProductShowCurrentUnitC
			%btst	R_SpecFlag,D_Neg,Disp_ProductCurrentTempC_Neg
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

Disp_ProductCurrentTempC_Neg:
			LDX		#T_TeNeg
			JSR		Display_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

; R_TempBuf+5 是高两位 BCD，R_TempBuf+6 是低两位 BCD。
; F_DisplayHLValue 会把低 4 bit 放到 R_TempBuf，并把高 4 bit 留在 A。
; 输入: R_TempBuf+5/+6 中的一组温度 BCD。
; 输出: 把这组温度 BCD 拆到室内当前温度三位数码位。
; 调试: 看 CurTeH/M/L 的位值是否和 TempBuf 中的 BCD 对应。
Disp_ProductRenderCurrentTempFromBuf:
			LDA		R_TempBuf+5
			JSR		F_DisplayHLValue
			LDA		R_TempBuf
			BNE		Disp_ProductCurTempH_Out
Disp_ProductCurTempH_Blank:
			LDA		#0AH
Disp_ProductCurTempH_Out:
			LDX		#T_CurTeH
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf+6
			JSR		F_DisplayHLValue
			LDX		#T_CurTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_CurTeL
			JMP		F_LcdDisplayDigital

; 当前湿度显示和温度不同，直接使用 Alarm 已整理好的 BCD 缓冲。
; 输入: 室内当前湿度 BCD 缓冲 R_DispHum。
; 输出: 刷新室内当前湿度两位数码位。
; 调试: 看 CurHuH/L 是否和 R_DispHum 保持一致。
Disp_ProductCurrentHum:
			; 湿度规格固定夹在 1~99%RH，显示层不再消费旧的 HH/LL 状态位。
			LDA		R_DispHum
			JSR		F_DisplayHLValue
			PHA
			LDA		R_TempBuf
			LDX		#T_CurHuL
			JSR		F_LcdDisplayDigital
			PLA
			BNE		Disp_ProductCurHumH_Out
			LDA		#0AH

Disp_ProductCurHumH_Out:
			LDX		#T_CurHuH
			JMP		F_LcdDisplayDigital


; 输入: A=需要显示的室外湿度码值。
; 输出: 把同一个码值写到室外湿度两位数码位。
; 调试: 看 OutCurHuH/L 是否都写入 A 指定的值。
Disp_ProductDisplayOutdoorHumCode:
			PHA
			LDX		#T_OutCurHuH
			JSR		F_LcdDisplayDigital
			PLA
			LDX		#T_OutCurHuL
			JMP		F_LcdDisplayDigital


; 输入: A=需要显示的室外温度码值。
; 输出: 把同一个码值写到室外温度三位数码位，并清负号/100 图标。
; 调试: 看 OutCurTeH/M/L 与 OutTeNeg/OutCurTe100 是否符合预期。
Disp_ProductDisplayOutdoorTempCode:
			PHA
			LDX		#T_OutCurTeH
			JSR		F_LcdDisplayDigital
			PLA
			PHA
			LDX		#T_OutCurTeM
			JSR		F_LcdDisplayDigital
			PLA
			LDX		#T_OutCurTeL
			JSR		F_LcdDisplayDigital
			JSR		Disp_ProductShowOutdoorUnit
			LDX		#T_OutTeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_OutCurTe100
			JMP		NoDisplay_OneBit


; 输入: 当前单位状态。
; 输出: 把室外温度三位数码位显示为空白码，并保留当前单位图标。
; 调试: 看无数据 blank 态时三位是否为 0Ah，单位图标是否保持。
Disp_ProductOutdoorTempBlank:
			LDA		#0AH
			JMP		Disp_ProductDisplayOutdoorTempCode


; 输入: 当前视图通道缓存中的原始室外温度。
; 输出: 若该通道有数据，则把原始温度整理到 R_TempBuf 并用进位位返回有效。
; 调试: 看 R_TempBuf+5/+6、进位位以及负温补码转换是否正确。
Disp_ProductPrepareOutdoorTemp:
			JSR		Disp_ProductHasOutdoorData
			BCC		Disp_ProductPrepareOutdoorTemp_Invalid
			LDA		R_RF1TempH,X
			STA		R_TempBuf+5
			LDA		R_RF1TempL,X
			STA		R_TempBuf+6
			LDA		R_TempBuf+5
			AND		#80H
			BEQ		Disp_ProductPrepareOutdoorTemp_Positive
			LDA		R_TempBuf+6
			EOR		#0FFH
			CLC
			ADC		#01H
			STA		R_TempBuf+6
			LDA		R_TempBuf+5
			EOR		#0FFH
			ADC		#00H
			AND		#7FH
			ORA		#80H
			STA		R_TempBuf+5
			SEC
			RTS
Disp_ProductPrepareOutdoorTemp_Positive:
			LDA		R_TempBuf+5
			AND		#7FH
			STA		R_TempBuf+5
			SEC
			RTS
Disp_ProductPrepareOutdoorTemp_Invalid:
			CLC
			RTS


; 输入: R_SpecFlag.D_TF 当前单位状态。
; 输出: 互斥显示室外 C/F 单位图标。
; 调试: 看 T_OutCUnit/T_OutFUnit 是否始终只有一个亮。
Disp_ProductShowOutdoorUnit:
			%btst	R_SpecFlag,D_TF,Disp_ProductShowOutdoorUnitF

Disp_ProductShowOutdoorUnitC:
			LDX		#T_OutCUnit
			JSR		Display_OneBit
			LDX		#T_OutFUnit
			JMP		NoDisplay_OneBit

Disp_ProductShowOutdoorUnitF:
			LDX		#T_OutCUnit
			JSR		NoDisplay_OneBit
			LDX		#T_OutFUnit
			JMP		Display_OneBit


; 输入: R_TempBuf+5/+6 中的一组室外温度 BCD。
; 输出: 把这组温度 BCD 拆到室外温度三位数码位。
; 调试: 看 OutCurTeH/M/L 的位值是否和 TempBuf 中的 BCD 对应。
Disp_ProductRenderOutdoorTempFromBuf:
			LDA		R_TempBuf+5
			JSR		F_DisplayHLValue
			LDA		R_TempBuf
			BNE		Disp_ProductOutdoorTempH_Out
			LDA		#0AH
Disp_ProductOutdoorTempH_Out:
			LDX		#T_OutCurTeH
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf+6
			JSR		F_DisplayHLValue
			LDX		#T_OutCurTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_OutCurTeL
			JMP		F_LcdDisplayDigital


; 输入: 当前视图通道的室外温度缓存、无数据态和单位状态。
; 输出: 在正常值、dash/blank、HH/LL、C/F 之间选择并刷新室外温度区。
; 调试: 看室外温度在有效、掉码、超规格、切单位几条路径下的分支选择。
Disp_ProductOutdoorTemp:
			JSR		Disp_ProductPrepareOutdoorTemp
			BCC		Disp_ProductOutdoorTempNoData
			LDA		R_SpecFlag
			AND		#D_TF
			BNE		Disp_ProductOutdoorTempF_Entry
			JMP		Disp_ProductOutdoorTempC

Disp_ProductOutdoorTempF_Entry:
			JMP		Disp_ProductOutdoorTempF

Disp_ProductOutdoorTempNoData:
			JSR		Disp_ProductShouldShowOutdoorDash
			BCS		Disp_ProductOutdoorTempDash
			JMP		Disp_ProductOutdoorTempBlank

Disp_ProductOutdoorTempDash:
			LDA		#0BH
			JMP		Disp_ProductDisplayOutdoorTempCode


; 输入: 已准备好的室外原始摄氏温度。
; 输出: 刷新室外摄氏温度，并在超规格时显示 HH/LL。
; 调试: 看 70.0C / -40.0C 边界附近是否按规格切到 HH/LL。
Disp_ProductOutdoorTempC:
			LDA		R_TempBuf+5
			STA		R_TempBuf+4
			AND		#80H
			BNE		Disp_ProductOutdoorTempC_CheckLL
			LDA		R_TempBuf+5
			AND		#7FH
			CMP		#02H
			BCC		Disp_ProductOutdoorTempC_DoConvert
			BNE		Disp_ProductOutdoorTempHH
			LDA		R_TempBuf+6
			CMP		#0BCH
			BCC		Disp_ProductOutdoorTempC_DoConvert
			BEQ		Disp_ProductOutdoorTempC_DoConvert
	Disp_ProductOutdoorTempHH:
			LDA		#0CH
			JMP		Disp_ProductDisplayOutdoorTempCode

	Disp_ProductOutdoorTempC_CheckLL:
			LDA		R_TempBuf+5
			AND		#7FH
			CMP		#01H
			BCC		Disp_ProductOutdoorTempC_DoConvert
			BNE		Disp_ProductOutdoorTempLL
			LDA		R_TempBuf+6
			CMP		#90H
			BCC		Disp_ProductOutdoorTempC_DoConvert
			BEQ		Disp_ProductOutdoorTempC_DoConvert
	Disp_ProductOutdoorTempLL:
			LDA		#0FH
			JMP		Disp_ProductDisplayOutdoorTempCode

	Disp_ProductOutdoorTempC_DoConvert:
			JMP		Disp_ProductOutdoorTempC_Convert

	Disp_ProductOutdoorTempC_Convert:
			LDA		R_TempBuf+5
			AND		#7FH
			TAX
			LDA		R_TempBuf+6
			JSR		F_CAL_HEX_BCD2
			LDA		OUT_M
			STA		R_TempBuf+5
			LDA		OUT_L
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderOutdoorTempFromBuf
			JSR		Disp_ProductShowOutdoorUnitC
			LDA		R_TempBuf+4
			AND		#80H
			BEQ		Disp_ProductOutdoorTempC_Positive
			LDX		#T_OutTeNeg
			JSR		Display_OneBit
			LDX		#T_OutCurTe100
			JMP		NoDisplay_OneBit
Disp_ProductOutdoorTempC_Positive:
			LDX		#T_OutTeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_OutCurTe100
			JMP		NoDisplay_OneBit


; 输入: 已准备好的室外原始华氏温度。
; 输出: 刷新室外华氏温度，并在超规格时显示 HH/LL/负号/100 图标。
; 调试: 看 158.0F / -40.0F 边界附近以及负号、100 图标是否正确。
Disp_ProductOutdoorTempF:
			LDX		R_TempBuf+5
			LDA		R_TempBuf+6
			JSR		F_CHANGE_CF
			LDA		R_TempFlag
			AND		#D_TempFReg
			BNE		Disp_ProductOutdoorTempF_CheckLL
			LDA		X_M
			CMP		#06H
			BCC		Disp_ProductOutdoorTempF_DoConvert
			BNE		Disp_ProductOutdoorTempHH
			LDA		X_L
			CMP		#2CH
			BCC		Disp_ProductOutdoorTempF_DoConvert
			BEQ		Disp_ProductOutdoorTempF_DoConvert
			JMP		Disp_ProductOutdoorTempHH

	Disp_ProductOutdoorTempF_CheckLL:
			LDA		X_M
			CMP		#01H
			BCC		Disp_ProductOutdoorTempF_DoConvert
			BNE		Disp_ProductOutdoorTempLL
			LDA		X_L
			CMP		#90H
			BCC		Disp_ProductOutdoorTempF_DoConvert
			BEQ		Disp_ProductOutdoorTempF_DoConvert
			JMP		Disp_ProductOutdoorTempLL

	Disp_ProductOutdoorTempF_DoConvert:
			JMP		Disp_ProductOutdoorTempF_Convert

	Disp_ProductOutdoorTempF_Convert:
			LDX		X_M
			LDA		X_L
			JSR		F_CAL_HEX_BCD2
			LDA		OUT_M
			STA		R_TempBuf+5
			LDA		OUT_L
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderOutdoorTempFromBuf
			JSR		Disp_ProductShowOutdoorUnitF
			; F_CHANGE_CF 把华氏负号写回 R_TempFlag.D_TempFReg，不在 X_M 里。
			LDA		R_TempFlag
			AND		#D_TempFReg
			BNE		Disp_ProductOutdoorTempF_Neg
			LDX		#T_OutTeNeg
			JSR		NoDisplay_OneBit
			; 室外华氏温度同样按 0.1 度存 BCD，100 图标应看高字节高 nibble。
			LDA		R_TempBuf+5
			AND		#0F0H
			BEQ		Disp_ProductOutdoorTempF_No100
			LDX		#T_OutCurTe100
			JMP		Display_OneBit
Disp_ProductOutdoorTempF_No100:
			LDX		#T_OutCurTe100
			JMP		NoDisplay_OneBit
Disp_ProductOutdoorTempF_Neg:
			LDX		#T_OutTeNeg
			JSR		Display_OneBit
			LDX		#T_OutCurTe100
			JMP		NoDisplay_OneBit


; 输入: 当前视图通道的室外湿度缓存和无数据态。
; 输出: 在正常值、夹到 1/99 和 dash/blank 之间选择并刷新室外湿度区。
; 调试: 看湿度 0、1、99、100 以及无数据态时的显示是否符合规格。
Disp_ProductOutdoorHum:
			JSR		Disp_ProductHasOutdoorData
			BCC		Disp_ProductOutdoorHumNoData
			LDA		R_RF1Hum,X
			BEQ		Disp_ProductOutdoorHumClamp1
			CMP		#64H
			BCC		Disp_ProductOutdoorHumConvert
			LDA		#99H
			JMP		Disp_ProductOutdoorHumDisplay
	Disp_ProductOutdoorHumClamp1:
			LDA		#01H
			JMP		Disp_ProductOutdoorHumDisplay
Disp_ProductOutdoorHumConvert:
			LDX		#00H
			JSR		F_CAL_HEX_BCD2
			LDA		OUT_L
Disp_ProductOutdoorHumDisplay:
			JSR		F_DisplayHLValue
			PHA
			LDA		R_TempBuf
			LDX		#T_OutCurHuL
			JSR		F_LcdDisplayDigital
			PLA
			BNE		Disp_ProductOutdoorHumH_Out
			LDA		#0AH
Disp_ProductOutdoorHumH_Out:
			LDX		#T_OutCurHuH
			JMP		F_LcdDisplayDigital

Disp_ProductOutdoorHumNoData:
			JSR		Disp_ProductShouldShowOutdoorDash
			BCS		Disp_ProductOutdoorHumDash
			JMP		Disp_ProductOutdoorHumBlank

Disp_ProductOutdoorHumDash:
			LDA		#0BH
			JMP		Disp_ProductDisplayOutdoorHumCode

Disp_ProductOutdoorHumBlank:
			LDA		#0AH
			JMP		Disp_ProductDisplayOutdoorHumCode

Disp_ProductTempRecords:
Disp_ProductTempRecordsDash:
Disp_ProductTempRecordsDashC:
Disp_ProductTempRecordsDashF:
Disp_ProductRenderMaxTempDashC:
Disp_ProductRenderMinTempDashC:
Disp_ProductRenderMaxTempDashF:
Disp_ProductRenderMinTempDashF:
Disp_ProductHumRecords:
Disp_ProductHumRecordsDash:
Disp_ProductRenderMaxHumDash:
Disp_ProductRenderMinHumDash:
			RTS

