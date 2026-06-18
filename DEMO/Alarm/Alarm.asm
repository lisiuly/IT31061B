.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE	GPL813x.inc
.INCLUDE	SYS\Project.inc
.INCLUDE	SYS\Macro.inc
.INCLUDE	KEY\KEY.inc
.INCLUDE	RTC\RTC.inc
.INCLUDE	LCD\LCD_Display.inc
.INCLUDE	RF\RF.inc
.INCLUDE	GXHTV4\GXHTV4.inc
.INCLUDE		I2C\D_I2C.inc
.EXTERN		F_ReadGXHTV4Data
.EXTERN		TEMP_INTEGAH
.EXTERN		TEMP_INTEGAL
.EXTERN		HUM

;==========================================
; Public declare area
;==========================================
;.PUBLIC			R_PortD_Data_Buf
.PUBLIC			R_KeyToneTm
.PUBLIC			R_SoundOn
.PUBLIC			R_BatteryFlags
.PUBLIC			F_CheckLowBattery
.PUBLIC			R_TrendFlags

;==========================================
; Variable RAM declare area
;==========================================
RFCRAM	.section

R_SoundOn		ds	1
R_KeyToneTm		ds	1
R_BatteryFlags	ds	1
R_BatteryDetCnt	ds	1
;R_PortD_Data_Buf	ds	1
R_TempCH		ds	1
R_TempCL		ds	1
R_HUM			ds	1

D_BatteryLow		equ	0x01
C_BatteryDetDebounce	equ	5

; 趋势状态位与窗口缓存。
R_TrendFlags		ds	1
D_TrendInit		equ	0x01
D_TrendTempUp		equ	0x02
D_TrendTempDown	equ	0x04
D_TrendTempRefresh	equ	0x08
D_TrendHumUp		equ	0x10
D_TrendHumDown	equ	0x20
D_TrendHumRefresh	equ	0x40
C_TrendEq60Samples	equ	3CH
C_TrendTempOver1C	equ	0BH
C_TrendHumOver5		equ	06H

R_TrendTempEqCnt	ds	1
R_TrendHumEqCnt	ds	1
R_TrendTempMaxH		ds	1
R_TrendTempMaxL		ds	1
R_TrendTempMinH		ds	1
R_TrendTempMinL		ds	1
R_TrendHumMax		ds	1
R_TrendHumMin		ds	1

;---------------------------------------
.PUBLIC		R_TempCH
.PUBLIC		R_TempCL
.PUBLIC		R_HUM
.PUBLIC		R_SpecFlag
.PUBLIC		R_TempMin_Sign
.PUBLIC		R_TempMax_Sign
.PUBLIC		R_DispTemper_F
.PUBLIC		R_MAXDispTemper_F
.PUBLIC		R_MINDispTemper_F
.PUBLIC		R_DispTemper
.PUBLIC		R_TempMax
.PUBLIC		R_TempMin
.PUBLIC		R_DispHum
.PUBLIC		R_HumMax
.PUBLIC		R_HumMin
.PUBLIC		R_TempFlag1

R_SpecFlag		ds	1
R_TempMin_Sign	ds	1
R_TempMax_Sign	ds	1
R_HumMin_Sign	ds	1
R_HumMax_Sign	ds	1
D_HumHH			equ	0x04
D_TempHH		equ	0x40
D_TempLL		equ	0x20
D_Neg			equ	0x10
D_TF			equ	0x08
D_HumLL			equ	0x02
C_HumRaw100		equ	64H
C_HumDisp99		equ	99H

R_DispTemper_F		ds	2
R_MAXDispTemper_F	ds	2
R_MINDispTemper_F	ds	2
R_DispTemper		ds	2
R_TempMax		ds	2
R_TempMin		ds	2
R_DispHum		ds	1
R_HumMax		ds	1
R_HumMin		ds	1
R_TempFlag1		ds	1
D_MaxTemp		equ	0x01
D_MinTemp		equ	0x02

.CODE
;-------------------------------------------------------
; 函数: F_JudgeRFC
; 作用: 温湿度采样统一入口，只在整分 00 秒的半秒边沿触发一次。
.PUBLIC		F_JudgeRFC
F_JudgeRFC:
	%btst	R_KeyFlag,D_KeyRelDis,ExitJudge
	%btst	R_RFStatus,D_RFLongRecv,ExitJudge
	LDA		RTC+2
	CMP		#00H
	BNE		ExitJudge
	%btst	R_TimeStatus,HalfSecToggle,ExitJudge
	JMP		F_UpdateTHFromGXHTV4

;-------------------------------------------------------
; 函数: F_UpdateTHFromGXHTV4
; 作用: 从 GXHTV4 读取原始温湿度值，并转入本模块换算链。
.PUBLIC		F_UpdateTHFromGXHTV4
F_UpdateTHFromGXHTV4:
	JSR		F_ReadGXHTV4Data
	LDA		TEMP_INTEGAH
	STA		R_TempCH
	LDA		TEMP_INTEGAL
	STA		R_TempCL
	LDA		HUM
	STA		R_HUM
	JMP		CalculateRFC

;-------------------------------------------------------
; 函数: CalculateRFC
; 作用: 按原始温度符号位更新负温标志，并进入温湿度处理主链。
.PUBLIC		CalculateRFC
CalculateRFC:
	LDA		R_TempCH
	AND		#80H
	BEQ		TemperatureIsPositive
	%bits	R_SpecFlag,D_Neg
	JMP		LoadTemperatureValue

TemperatureIsPositive:
	%bitr	R_SpecFlag,D_Neg

LoadTemperatureValue:
	%bits	R_TimeStatus,AddOthers
	JMP		F_GetTHVlaue

ExitJudge:
	RTS

;-------------------------------------------------------
; 函数: F_CheckLowBattery
; 作用: 读取 LVD 状态并做去抖，稳定后更新低电池标志。
F_CheckLowBattery:
	LDA		P_LVD_Ctrl
	AND		#D_LVD_State
	BNE		BatterySampleLow

BatterySampleHigh:
	LDA		R_BatteryFlags
	AND		#D_BatteryLow
	BEQ		BatteryClearCounter
	INC		R_BatteryDetCnt
	LDA		R_BatteryDetCnt
	CMP		#C_BatteryDetDebounce
	BCC		BatteryExit
	LDA		R_BatteryFlags
	AND		#.not.D_BatteryLow
	STA		R_BatteryFlags
	%bits	R_TimeStatus,AddOthers
	LDA		#00H
	STA		R_BatteryDetCnt
	RTS

BatterySampleLow:
	LDA		R_BatteryFlags
	AND		#D_BatteryLow
	BNE		BatteryLowKeep
	INC		R_BatteryDetCnt
	LDA		R_BatteryDetCnt
	CMP		#C_BatteryDetDebounce
	BCC		BatteryExit
	LDA		R_BatteryFlags
	ORA		#D_BatteryLow
	STA		R_BatteryFlags
	%bits	R_TimeStatus,AddOthers

BatteryLowKeep:
	LDA		#00H
	STA		R_BatteryDetCnt
	RTS

BatteryClearCounter:
	LDA		#00H
	STA		R_BatteryDetCnt

BatteryExit:
	RTS
;==========================================
; 函数: F_RetryFirstTHRead
; 作用: 若 D_FirstReadRetry 标志置位则重读一次温湿度，
;        成功则清标志，失败则保持标志等待下次重试。
;==========================================
.public		F_RetryFirstTHRead
F_RetryFirstTHRead:
		LDA		R_TempFlag
		AND		#D_FirstReadRetry
		BEQ		?RetryExit
		JSR		F_UpdateTHFromGXHTV4
		LDA		R_SaveData+0
		ORA		R_SaveData+1
		ORA		R_SaveData+3
		ORA		R_SaveData+4
		BEQ		?RetryExit
		LDA		R_TempFlag
		AND		#.not.D_FirstReadRetry
		STA		R_TempFlag
?RetryExit:
		RTS
;-------------------------------------------------------
; 输入：R_TempCH, R_TempCL - 温度值
;       R_HUM - 湿度值
; 输出：当前温湿度显示值、极值缓存和趋势状态。
; 调试：先看 R_DispTemper/R_DispHum，再看极值和趋势状态是否同步更新。
.PUBLIC		F_GetTHVlaue
F_GetTHVlaue:
	JSR		ProcessTemperature
	JSR		ProcessHumidity
	JSR		F_Judge_HHLL
	JSR		UpdateExtremeValues
	JMP		F_UpdateTrendState

;-------------------------------------------------------
; 输入：R_TempCH, R_TempCL 当前温度原始值。
; 输出：生成室内摄氏显示缓冲，并继续生成华氏显示缓冲。
; 调试：看 R_DispTemper+0/+1 与原始温度的 BCD 对应关系。
ProcessTemperature:
	LDA		R_TempCH
	AND		#7FH
	TAX
	LDA		R_TempCL
	JSR		F_CAL_HEX_BCD2
	LDA		OUT_M
	STA		R_DispTemper+0
	LDA		OUT_L
	STA		R_DispTemper+1
	JMP		ConvertToFahrenheit

;-------------------------------------------------------
; 输入：R_TempCH, R_TempCL 当前温度原始值。
; 输出：生成室内华氏显示缓冲 R_DispTemper_F。
; 调试：看 X_M/X_L 和 R_DispTemper_F 是否与换算结果一致。
ConvertToFahrenheit:
	LDA		R_TempCH
	TAX
	LDA		R_TempCL
	JSR		F_CHANGE_CF
	LDX		X_M
	LDA		X_L
	JSR		F_CAL_HEX_BCD2
	LDA		OUT_M
	STA		R_DispTemper_F+0
	LDA		OUT_L
	STA		R_DispTemper_F+1
	RTS

;-------------------------------------------------------
; 输入：R_HUM 当前原始湿度值。
; 输出：把湿度夹到 1~99 后转换成 BCD 显示格式。
; 调试：重点看 0、1、99、100 这几个边界值的 R_DispHum。
ProcessHumidity:
	LDA		R_HUM
	BEQ		ProcessHumidity_Clamp1
	CMP		#C_HumRaw100
	BCC		ProcessHumidity_ConvertBCD
	LDA		#C_HumDisp99
	STA		R_DispHum
	RTS

ProcessHumidity_Clamp1:
	LDA		#01H
	STA		R_DispHum
	RTS

ProcessHumidity_ConvertBCD:
	LDX		#00H
	LDA		R_HUM
	JSR		F_CAL_HEX_BCD2
	LDA		OUT_L
	STA		R_DispHum
	RTS

;-------------------------------------------------------
; 函数: F_Judge_HHLL
; 作用: 重算当前温湿度 HH/LL 状态位。
F_Judge_HHLL:
	%bitr	R_SpecFlag,(D_TempLL+D_TempHH+D_HumLL+D_HumHH)
	JSR		F_Judge_TempHHLL
;	JMP		F_Judge_HumHHLL

; 输入：当前室内温度显示缓冲与负号标志。
; 输出：按规格重算温度 HH/LL 状态位。
; 调试：看 D_TempHH/D_TempLL 在高低边界附近是否按预期翻转。
F_Judge_TempHHLL:
	%btst	R_SpecFlag,D_Neg,JudgeTempLL
	LDA		R_DispTemper+0
	CMP		#05H
	BCC		JudgeTempExit
	BNE		SetTempHH
	LDA		R_DispTemper+1
	BEQ		JudgeTempExit
SetTempHH:
	%bits	R_SpecFlag,D_TempHH
JudgeTempExit:
	RTS

JudgeTempLL:
	LDA		R_DispTemper+0
	CMP		#01H
	BCC		JudgeTempExit
	%bits	R_SpecFlag,D_TempLL
	RTS

; 输入：当前室内湿度显示状态。
; 输出：当前产品固定不产生湿度 HH/LL，直接返回。
; 调试：确认室内湿度始终只走 1~99 显示，不再出现 HH/LL 状态位。
;F_Judge_HumHHLL:
	; 86428 规格要求室内湿度始终夹在 1~99%RH 显示，不再出现 HH/LL。
;	RTS

;-------------------------------------------------------
; 函数: F_IsCurrentTempInRange
; 作用: 根据 HH/LL 状态判断当前温度是否仍参与极值记录。
F_IsCurrentTempInRange:
	LDA		R_SpecFlag
	AND		#(D_TempHH+D_TempLL)
	BEQ		CurrentTempInRange
	CLC
	RTS

CurrentTempInRange:
	SEC
	RTS

;-------------------------------------------------------
; 输入：当前温湿度显示值和 HH/LL 状态。
; 输出：更新温湿度极值缓存；超规格温度不参与极值更新。
; 调试：看极值缓存在 HH/LL 状态下是否停止更新。
UpdateExtremeValues:
	JSR		F_IsCurrentTempInRange
	BCC		UpdateExtremeValues_SkipTemp
	JSR		UpdateTemperatureExtremes

UpdateExtremeValues_SkipTemp:
	JMP		UpdateHumidityExtremes

;-------------------------------------------------------
; 函数: UpdateTemperatureExtremes
; 作用: 更新最高/最低温度记录以及对应的华氏缓存。
UpdateTemperatureExtremes:
	LDA		R_SpecFlag
	AND		#D_Neg
	BNE		CurrentTempIsNeg_1

	LDA		R_TempMax_Sign
	AND		#D_Neg
	BNE		UpdateTempMax
	LDA		R_DispTemper+0
	CMP		R_TempMax+0
	BEQ		CompareTempMaxLow
	BCS		UpdateTempMax
	JMP		CheckTempMin

CompareTempMaxLow:
	LDA		R_DispTemper+1
	CMP		R_TempMax+1
	BCC		CheckTempMin
	BEQ		CheckTempMin
	JMP		UpdateTempMax

UpdateTempMax:
	LDA		R_DispTemper+0
	STA		R_TempMax+0
	LDA		R_DispTemper+1
	STA		R_TempMax+1
	LDA		R_SpecFlag
	STA		R_TempMax_Sign
	LDA		R_DispTemper_F+0
	STA		R_MAXDispTemper_F+0
	LDA		R_DispTemper_F+1
	STA		R_MAXDispTemper_F+1
	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMax_Sign
	STA		R_TempMax_Sign
	JMP		CheckTempMin

CurrentTempIsNeg_1:
	JMP		CurrentTempIsNeg

CheckTempMin:
	LDA		R_SpecFlag
	AND		#D_Neg
	BNE		CurrentTempNegMin
	LDA		R_TempMin_Sign
	AND		#D_Neg
	BNE		ExitTempUpdate
	LDA		R_DispTemper+0
	CMP		R_TempMin+0
	BEQ		CompareTempMinLow
	BCC		UpdateTempMin
	JMP		ExitTempUpdate

CompareTempMinLow:
	LDA		R_DispTemper+1
	CMP		R_TempMin+1
	BCS		ExitTempUpdate
	JMP		UpdateTempMin

UpdateTempMin:
	LDA		R_DispTemper+0
	STA		R_TempMin+0
	LDA		R_DispTemper+1
	STA		R_TempMin+1
	LDA		R_SpecFlag
	STA		R_TempMin_Sign
	LDA		R_DispTemper_F+0
	STA		R_MINDispTemper_F+0
	LDA		R_DispTemper_F+1
	STA		R_MINDispTemper_F+1
	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMin_Sign
	STA		R_TempMin_Sign
	JMP		ExitTempUpdate

ExitTempUpdate:
	RTS

CurrentTempIsNeg:
	LDA		R_TempMax_Sign
	AND		#D_Neg
	BNE		CompareNegativeMax
	JMP		CheckTempMin

CompareNegativeMax:
	LDA		R_DispTemper+0
	CMP		R_TempMax+0
	BEQ		CompareNegativeMaxLow
	BCS		CheckTempMin
	JMP		UpdateTempMax

CompareNegativeMaxLow:
	LDA		R_DispTemper+1
	CMP		R_TempMax+1
	BCS		CheckTempMin
	JMP		UpdateTempMax

CurrentTempNegMin:
	LDA		R_TempMin_Sign
	AND		#D_Neg
	BNE		CompareNegativeMin
	JMP		UpdateTempMin

CompareNegativeMin:
	LDA		R_DispTemper+0
	CMP		R_TempMin+0
	BEQ		CompareNegativeMinLow
	BCS		UpdateTempMin
	JMP		ExitTempUpdate

CompareNegativeMinLow:
	LDA		R_DispTemper+1
	CMP		R_TempMin+1
	BCS		ExitTempUpdate
	JMP		UpdateTempMin

;-------------------------------------------------------
; 函数: UpdateHumidityExtremes
; 作用: 更新最高/最低湿度记录。
UpdateHumidityExtremes:
	LDA		R_DispHum
	CMP		R_HumMax
	BCC		CheckHumMin
	LDA		R_DispHum
	STA		R_HumMax
	LDA		R_SpecFlag
	STA		R_HumMax_Sign
	RTS

CheckHumMin:
	LDA		R_DispHum
	CMP		R_HumMin
	BCS		ExitHumUpdate
	LDA		R_DispHum
	STA		R_HumMin
	LDA		R_SpecFlag
	STA		R_HumMin_Sign

ExitHumUpdate:
	RTS

;-------------------------------------------------------
; 输入：当前温湿度样本和趋势窗口缓存。
; 输出：更新温湿度趋势窗口与刷新位。
; 调试：看 R_TrendFlags、各 Max/Min/EqCnt 是否随着样本推进。
F_UpdateTrendState:
	LDA		R_TrendFlags
	AND		#D_TrendInit
	BEQ		F_TrendSeedCurrent
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempRefresh
	AND		#.not.D_TrendHumRefresh
	STA		R_TrendFlags
	JSR		F_UpdateTempTrendState
	JMP		F_UpdateHumTrendState

;-------------------------------------------------------
; 输入：当前温湿度样本。
; 输出：用当前样本初始化趋势窗口，并触发一次等于图标刷新。
; 调试：看 Init、TempRefresh、HumRefresh 三个位是否一次性置起。
F_TrendSeedCurrent:
	JSR		F_TrendSeedTempCurrent
	JSR		F_TrendSeedHumCurrent
	LDA		#C_TrendEq60Samples
	STA		R_TrendTempEqCnt
	STA		R_TrendHumEqCnt
	LDA		#(D_TrendInit+D_TrendTempRefresh+D_TrendHumRefresh)
	STA		R_TrendFlags
	RTS

; 输入：当前室内温度原始样本。
; 输出：重置温度趋势窗口最大/最小值与等值计数。
; 调试：看 R_TrendTempMax*/Min*/EqCnt 是否都被当前值覆盖。
F_TrendSeedTempCurrent:
	LDA		R_TempCH
	STA		R_TrendTempMaxH
	STA		R_TrendTempMinH
	LDA		R_TempCL
	STA		R_TrendTempMaxL
	STA		R_TrendTempMinL
	LDA		#00H
	STA		R_TrendTempEqCnt
	RTS

; 输入：当前室内湿度样本。
; 输出：重置湿度趋势窗口最大/最小值与等值计数。
; 调试：看 R_TrendHumMax/Min/EqCnt 是否都被当前值覆盖。
F_TrendSeedHumCurrent:
	LDA		R_HUM
	STA		R_TrendHumMax
	STA		R_TrendHumMin
	LDA		#00H
	STA		R_TrendHumEqCnt
	RTS

;-------------------------------------------------------
; 函数: F_UpdateTempTrendState
; 作用: 更新温度趋势窗口，并在跨阈值时切换 Up/Down/Equal 图标。
F_UpdateTempTrendState:
	JSR		F_IsCurrentTempGreaterThanTrendMax
	BCC		TrendTemp_CheckMin
	LDA		R_TempCH
	STA		R_TrendTempMaxH
	LDA		R_TempCL
	STA		R_TrendTempMaxL
	JSR		F_IsTrendTempWindowOverThreshold
	BCC		TrendTemp_AdvanceEq
	JSR		F_TrendSeedTempCurrent
	LDA		R_TrendFlags
	AND		#(D_TrendTempUp+D_TrendTempDown)
	CMP		#D_TrendTempUp
	BEQ		TrendTemp_SetUpNoRefresh
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempDown
	ORA		#(D_TrendTempUp+D_TrendTempRefresh)
	STA		R_TrendFlags
	RTS

TrendTemp_SetUpNoRefresh:
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempDown
	ORA		#D_TrendTempUp
	STA		R_TrendFlags
	RTS

TrendTemp_CheckMin:
	JSR		F_IsCurrentTempLessThanTrendMin
	BCC		TrendTemp_AdvanceEq
	LDA		R_TempCH
	STA		R_TrendTempMinH
	LDA		R_TempCL
	STA		R_TrendTempMinL
	JSR		F_IsTrendTempWindowOverThreshold
	BCC		TrendTemp_AdvanceEq
	JSR		F_TrendSeedTempCurrent
	LDA		R_TrendFlags
	AND		#(D_TrendTempUp+D_TrendTempDown)
	CMP		#D_TrendTempDown
	BEQ		TrendTemp_SetDownNoRefresh
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempUp
	ORA		#(D_TrendTempDown+D_TrendTempRefresh)
	STA		R_TrendFlags
	RTS

TrendTemp_SetDownNoRefresh:
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempUp
	ORA		#D_TrendTempDown
	STA		R_TrendFlags
	RTS

TrendTemp_AdvanceEq:
	LDA		R_TrendTempEqCnt
	CMP		#C_TrendEq60Samples
	BCS		TrendTemp_Exit
	INC		R_TrendTempEqCnt
	LDA		R_TrendTempEqCnt
	CMP		#C_TrendEq60Samples
	BNE		TrendTemp_Exit
	LDA		R_TrendFlags
	AND		#.not.D_TrendTempUp
	AND		#.not.D_TrendTempDown
	ORA		#D_TrendTempRefresh
	STA		R_TrendFlags
TrendTemp_Exit:
	RTS

;-------------------------------------------------------
; 函数: F_UpdateHumTrendState
; 作用: 更新湿度趋势窗口，并在跨阈值时切换 Up/Down/Equal 图标。
F_UpdateHumTrendState:
	LDA		R_HUM
	CMP		R_TrendHumMax
	BCC		TrendHum_CheckMin
	BEQ		TrendHum_CheckMin
	STA		R_TrendHumMax
	JSR		F_IsTrendHumWindowOverThreshold
	BCC		TrendHum_AdvanceEq
	JSR		F_TrendSeedHumCurrent
	LDA		R_TrendFlags
	AND		#(D_TrendHumUp+D_TrendHumDown)
	CMP		#D_TrendHumUp
	BEQ		TrendHum_SetUpNoRefresh
	LDA		R_TrendFlags
	AND		#.not.D_TrendHumDown
	ORA		#(D_TrendHumUp+D_TrendHumRefresh)
	STA		R_TrendFlags
	RTS

TrendHum_SetUpNoRefresh:
	LDA		R_TrendFlags
	AND		#.not.D_TrendHumDown
	ORA		#D_TrendHumUp
	STA		R_TrendFlags
	RTS

TrendHum_CheckMin:
	LDA		R_HUM
	CMP		R_TrendHumMin
	BCS		TrendHum_AdvanceEq
	STA		R_TrendHumMin
	JSR		F_IsTrendHumWindowOverThreshold
	BCC		TrendHum_AdvanceEq
	JSR		F_TrendSeedHumCurrent
	LDA		R_TrendFlags
	AND		#(D_TrendHumUp+D_TrendHumDown)
	CMP		#D_TrendHumDown
	BEQ		TrendHum_SetDownNoRefresh
	LDA		R_TrendFlags
	AND		#.not.D_TrendHumUp
	ORA		#(D_TrendHumDown+D_TrendHumRefresh)
	STA		R_TrendFlags
	RTS

TrendHum_SetDownNoRefresh:
	LDA		R_TrendFlags
	AND		#.not.D_TrendHumUp
	ORA		#D_TrendHumDown
	STA		R_TrendFlags
	RTS

TrendHum_AdvanceEq:
	LDA		R_TrendHumEqCnt
	CMP		#C_TrendEq60Samples
	BCS		TrendHum_Exit
	INC		R_TrendHumEqCnt
	LDA		R_TrendHumEqCnt
	CMP		#C_TrendEq60Samples
	BNE		TrendHum_Exit
	LDA		R_TrendFlags
	AND		#.not.D_TrendHumUp
	AND		#.not.D_TrendHumDown
	ORA		#D_TrendHumRefresh
	STA		R_TrendFlags
TrendHum_Exit:
	RTS

;-------------------------------------------------------
; 输入：当前温度样本和趋势温度最大值窗口。
; 输出：C=1 表示当前温度大于趋势窗口最大值。
; 调试：重点看正温、负温、跨符号三条比较路径。
F_IsCurrentTempGreaterThanTrendMax:
	LDA		R_TempCH
	AND		#80H
	BEQ		TrendTempGtMax_CurrentPos
	LDA		R_TrendTempMaxH
	AND		#80H
	BEQ		TrendTempGtMax_False
	LDA		R_TempCH
	CMP		R_TrendTempMaxH
	BCC		TrendTempGtMax_True
	BNE		TrendTempGtMax_False
	LDA		R_TempCL
	CMP		R_TrendTempMaxL
	BCC		TrendTempGtMax_True
	JMP		TrendTempGtMax_False

TrendTempGtMax_CurrentPos:
	LDA		R_TrendTempMaxH
	AND		#80H
	BNE		TrendTempGtMax_True
	LDA		R_TempCH
	AND		#7FH
	CMP		R_TrendTempMaxH
	BCC		TrendTempGtMax_False
	BNE		TrendTempGtMax_True
	LDA		R_TempCL
	CMP		R_TrendTempMaxL
	BCC		TrendTempGtMax_False
	BEQ		TrendTempGtMax_False

TrendTempGtMax_True:
	SEC
	RTS

TrendTempGtMax_False:
	CLC
	RTS

;-------------------------------------------------------
; 输入：当前温度样本和趋势温度最小值窗口。
; 输出：C=1 表示当前温度小于趋势窗口最小值。
; 调试：重点看正温、负温、跨符号三条比较路径。
F_IsCurrentTempLessThanTrendMin:
	LDA		R_TempCH
	AND		#80H
	BEQ		TrendTempLtMin_CurrentPos
	LDA		R_TrendTempMinH
	AND		#80H
	BEQ		TrendTempLtMin_True
	LDA		R_TempCH
	CMP		R_TrendTempMinH
	BCC		TrendTempLtMin_False
	BNE		TrendTempLtMin_True
	LDA		R_TempCL
	CMP		R_TrendTempMinL
	BCC		TrendTempLtMin_False
	BEQ		TrendTempLtMin_False
	JMP		TrendTempLtMin_True

TrendTempLtMin_CurrentPos:
	LDA		R_TrendTempMinH
	AND		#80H
	BNE		TrendTempLtMin_False
	LDA		R_TempCH
	AND		#7FH
	CMP		R_TrendTempMinH
	BCC		TrendTempLtMin_True
	BNE		TrendTempLtMin_False
	LDA		R_TempCL
	CMP		R_TrendTempMinL
	BCC		TrendTempLtMin_True

TrendTempLtMin_False:
	CLC
	RTS

TrendTempLtMin_True:
	SEC
	RTS

;-------------------------------------------------------
; 输入：趋势温度窗口最大值/最小值。
; 输出：C=1 表示温度趋势窗口跨度已经大于 1.0C。
; 调试：看同号和跨零两种窗口跨度计算是否都正确。
F_IsTrendTempWindowOverThreshold:
	LDA		R_TrendTempMaxH
	AND		#80H
	BEQ		TrendTempSpan_MaxPositive
	SEC
	LDA		R_TrendTempMinL
	SBC		R_TrendTempMaxL
	TAX
	LDA		R_TrendTempMinH
	SBC		R_TrendTempMaxH
	BCC		TrendTempSpan_False
	BNE		TrendTempSpan_True
	TXA
	CMP		#C_TrendTempOver1C
	BCC		TrendTempSpan_False
	JMP		TrendTempSpan_True

TrendTempSpan_MaxPositive:
	LDA		R_TrendTempMinH
	AND		#80H
	BNE		TrendTempSpan_CrossZero
	SEC
	LDA		R_TrendTempMaxL
	SBC		R_TrendTempMinL
	TAX
	LDA		R_TrendTempMaxH
	SBC		R_TrendTempMinH
	BCC		TrendTempSpan_False
	BNE		TrendTempSpan_True
	TXA
	CMP		#C_TrendTempOver1C
	BCC		TrendTempSpan_False
	JMP		TrendTempSpan_True

TrendTempSpan_CrossZero:
	CLC
	LDA		R_TrendTempMaxL
	ADC		R_TrendTempMinL
	TAX
	LDA		R_TrendTempMinH
	AND		#7FH
	ADC		R_TrendTempMaxH
	BNE		TrendTempSpan_True
	TXA
	CMP		#C_TrendTempOver1C
	BCC		TrendTempSpan_False

TrendTempSpan_True:
	SEC
	RTS

TrendTempSpan_False:
	CLC
	RTS

;-------------------------------------------------------
; 输入：趋势湿度窗口最大值/最小值。
; 输出：C=1 表示湿度趋势窗口跨度已经大于 5%RH。
; 调试：看湿度最大最小差值是否跨过 5%RH 阈值。
F_IsTrendHumWindowOverThreshold:
	LDA		R_TrendHumMax
	SEC
	SBC		R_TrendHumMin
	CMP		#C_TrendHumOver5
	BCC		TrendHumSpan_False
	SEC
	RTS

TrendHumSpan_False:
	CLC
	RTS

.END
