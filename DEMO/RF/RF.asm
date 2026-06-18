;==========================================================================
; Name                  : RF.asm
; Applied Body          : GPL813X
; Programmer            : 
; Description           : RF三通道状态管理骨架
; History version       : 
;==================================================================================
;==========================================
; Compiler parameter define
;==========================================
.SYNTAX 6502
.LINKLIST
.SYMBOLS

;==========================================
; Include file area
;==========================================
.INCLUDE 	GPL813x.inc
.INCLUDE 	SYS\Macro.inc
.INCLUDE 	RTC\RTC.inc

;==========================================
; Constant define area
;==========================================
D_RFLongRecv		equ	01h
D_RFCycleMode		equ	02h
D_RFNeedSync		equ	04h
D_RFRecvBusy		equ	08h

D_RFCh1			equ	01h
D_RFCh2			equ	02h
D_RFCh3			equ	03h
D_RFAutoMode		equ	04h

D_RFValid		equ	01h
D_RFLowBat		equ	02h
D_RFLost			equ	04h
D_RFNeedPair		equ	08h
D_RFManualRetry		equ	10h
D_RFBlocked		equ	80h	; 上电长接收未配对 → 阻塞后续自动接收，需手动按 CH 键清除

C_RFLongRecv3Min		equ	180
C_RFAutoSwitch4Sec		equ	4
C_RFRecvWindow4SecTick	equ	6		; 3s 接收窗口（原 4s→3s，1s 提前量已含在周期内）
; C_RFRecvWindow2Sec		equ	4		; 旧配置是 2 秒总窗口，现已不用，保留注释。
C_RFSyncAdvance2SecTick	equ	4		; 0.5 秒粒度，提前 2 秒开窗（保留，新设计不再减此值）
; C_RFSyncAdvance1p5Sec	equ	3		; 旧一版规格写过 1.5 秒提前，现已不用，保留注释。
C_RFSyncIdle			equ	0FFH
C_RFCh1Sync57Sec		equ	56		; 提前 1s，原 57s→56s
C_RFCh2Sync67Sec		equ	66		; 提前 1s，原 67s→66s
C_RFCh3Sync79Sec		equ	78		; 提前 1s，原 79s→78s
C_RFCh1Sync57Tick		equ	112		; 56s，0.5s 粒度（原 114→112）
C_RFCh2Sync67Tick		equ	132		; 66s，0.5s 粒度（原 134→132）
C_RFCh3Sync79Tick		equ	156		; 78s，0.5s 粒度（原 158→156）
; 同步失败校准值：窗关→下次开窗 = 发端周期 ? 窗长3s
C_RFCh1SyncCloseTick	equ	110		; 有效 55s（reload?3）
C_RFCh2SyncCloseTick	equ	130		; 有效 65s（reload?3）
C_RFCh3SyncCloseTick	equ	154		; 有效 77s（reload?3）
C_RFFail3Times		equ	3
C_RFFail60Min			equ	60
C_RFFail120Min			equ	120
C_RFFailRetry63Min		equ	63		; 每次 3 分钟长接收结束后，还剩完整 60 分钟才开下一轮小时重试。
C_RFHourlyRetryStageFirst	equ	02H
C_RFHourlyRetryStageLast	equ	04H
C_RFFinalRetryStage		equ		05H

C_RFPendMax		equ	04H		; Pending槽数=4

; 室外趋势逻辑与 Alarm 的室内趋势保持同一门限：
; 连续 60 个有效样本都没有跨阈值则回到平；
; 温度跨度超过 1.0C、湿度跨度超过 5% 时判成上/下趋势。
D_RFTrendInit		equ	01h
D_RFTrendTempUp		equ	02h
D_RFTrendTempDown	equ	04h
D_RFTrendTempRefresh	equ	08h
D_RFTrendHumUp		equ	10h
D_RFTrendHumDown	equ	20h
D_RFTrendHumRefresh	equ	40h
C_RFTrendEq60Samples	equ	3CH
C_RFTrendTempOver1C	equ	0BH
C_RFTrendHumOver5		equ	06H

; RF发码协议位宽:
; Bit0 = 高500us + 低2000us
; Bit1 = 高500us + 低1000us
C_RFPacketBits36		equ	36

; RF收码低脉宽按 Timer0 实测约 4.096kHz 的样本数喂入:
; bit1 约 4~5 sample，bit0 约 8~9 sample，停止位约 16~20 sample。
C_RFBitHighMinSample		equ	01H
C_RFBitHighMaxSample		equ	03H
C_RFBit1LowMinSample		equ	03H
C_RFBit1LowMaxSample		equ	06H
C_RFBit0LowMinSample		equ	07H
C_RFBit0LowMaxSample		equ	0AH
C_RFStopLowMinSample		equ	0FH
C_RFStopLowMaxSample		equ	16H

;==========================================
; External declare area
;==========================================
.EXTERN		RTC
.EXTERN		P_IOD_DIR_Map
.EXTERN		R_PortD_Data_Buf
.EXTERN		R_KeyValue
.EXTERN		R_OldKeyValue




;==========================================
; Public declare area
;==========================================
.PUBLIC		R_RFStatus
.PUBLIC		R_RFChannel
.PUBLIC		R_RFViewChannel
.PUBLIC		R_RFRequestChannel
.PUBLIC		R_RFLongRecvTm
.PUBLIC		R_RFAutoSwitchTm
.PUBLIC		R_RFRecvWindowTm

.PUBLIC		R_RF1SyncTm
.PUBLIC		R_RF2SyncTm
.PUBLIC		R_RF3SyncTm

.PUBLIC		R_RFBitCnt
.PUBLIC		R_RFPacket0
.PUBLIC		R_RFPacket1
.PUBLIC		R_RFPacket2
.PUBLIC		R_RFPacket3
.PUBLIC		R_RFPacket4

.PUBLIC		R_RF1Flags
.PUBLIC		R_RF1IdH
.PUBLIC		R_RF1IdL
.PUBLIC		R_RF1TempH
.PUBLIC		R_RF1TempL
.PUBLIC		R_RF1Hum
.PUBLIC		R_RF1LostCnt
.PUBLIC		R_RF1MissMin
.PUBLIC		R_RF1RetryStage

.PUBLIC		R_RF2Flags
.PUBLIC		R_RF2IdH
.PUBLIC		R_RF2IdL
.PUBLIC		R_RF2TempH
.PUBLIC		R_RF2TempL
.PUBLIC		R_RF2Hum
.PUBLIC		R_RF2LostCnt
.PUBLIC		R_RF2RetryStage

.PUBLIC		R_RF3Flags
.PUBLIC		R_RF3IdH
.PUBLIC		R_RF3IdL
.PUBLIC		R_RF3TempH
.PUBLIC		R_RF3TempL
.PUBLIC		R_RF3Hum
.PUBLIC		R_RF3LostCnt
.PUBLIC		R_RF3RetryStage

.PUBLIC		R_RFTrendFlags

.PUBLIC		F_RF_Init
.PUBLIC		F_RF_SelectNextChannel
.PUBLIC		F_RF_ClearCurrentChannel
.PUBLIC		F_RF_StartLongReceive
.PUBLIC		F_RF_StopLongReceive
.PUBLIC		F_RF_ServiceHalfSec
.PUBLIC		F_RF_Service1Sec
.PUBLIC		F_RF_ServicePendingParse
.PUBLIC		F_RF_OnReceiveOK
.PUBLIC		F_RF_OnReceiveFail
.PUBLIC		F_RF_ResetPacketBuffer
.PUBLIC		F_RF_AppendBit0
.PUBLIC		F_RF_AppendBit1
.PUBLIC		F_RF_FeedLowPulseTicks
.PUBLIC		F_RF_Service8KHzSample
.PUBLIC		F_RF_ParsePacket

;==========================================
; RF模块调试总览
;==========================================
; 主运行链:
; 1. F_RF_Init: 上电后清状态、清收码缓存、三路通道置 NeedPair。
; 2. F_RF_ServiceHalfSec: 每 0.5 秒跑接收窗口/同步窗口；每两次再进一次 F_RF_Service1Sec。
; 3. F_RF_Service8KHzSample: 函数名沿用旧名，当前实际是在 Timer0 约 4.096kHz IRQ 里按样本数抓低脉宽。
; 4. F_RF_FeedLowPulseTicks: 先认 4~5ms 停止位作为一帧起点，不认前导码；之后把 1ms/2ms 低脉宽翻成 bit1/bit0。
; 5. F_RF_ParsePacket: 收满 36bit 后先做双帧一致确认，再按包内通道和已绑定 ID 判断是否落库。
; 6. F_RF_LoadPacketToRequestChannel: 把 ID/温度/湿度/低电信息写入目标通道缓存。
;
; 包格式(MSB first，bit0 先进 Packet0 bit7):
; Packet0 = 发射器 ID 8bit。
; Packet1 bit7 = 电池标志(1=低电, 0=正常), bit6 = 当前未用,
;         bit5~4 = 通道码, bit3~0 = 温度高 4bit(12bit 补码的高位，bit3 为符号位)。
; Packet2 = 温度低 8bit。
; Packet3 高 4bit 当前未用, 低 4bit = 湿度高 4bit。
; Packet4 高 4bit = 湿度低 4bit, 低 4bit 当前未用。
; 当前抓码验证到：拼出来的这 8bit 湿度是反码，落库前还要再 EOR FFh。
; 温度最终存入 R_RF1TempH/L ~ R_RF3TempH/L，为 16bit 符号扩展后的值。
;
; 关键观察变量:
; R_RFStatus: bit0 LongRecv, bit1 CycleMode, bit2 NeedSync, bit3 RecvBusy。
; R_RFRequestChannel: 当前接收窗口正在等哪一路包。
; R_RF1SyncTm~R_RF3SyncTm: 三路同步倒计时，单位 0.5 秒，FF 表示 idle。
; R_RFSamplePrev / R_RFLowSampleCnt / R_RFPulseTicks: PD1 采样与低脉宽换算链。
; R_RFCaptureActive / R_RFBitCnt / R_RFPacket0~4: 当前帧是否已锁定、已收 bit 数、解包前原始缓存。
; R_RFPendingValid / R_RFPending0~4: 上一帧缓存，用来做“双帧一致确认”。
; R_RF1Flags~R_RF3Flags: bit0 Valid, bit1 LowBat, bit2 Lost, bit3 NeedPair, bit4 ManualRetry。
; R_RF1IdL~R_RF3IdL: 每个通道绑定过的发射器 ID。
; R_RF1TempH/L、R_RF1Hum ...: 通道最终温湿度结果。
; R_RFTrendFlags: 三个室外通道各自的趋势状态位，布局与 Alarm 的室内趋势位一致。
; R_RF1LostCnt / R_RF1MissMin / R_RF1RetryStage / R_RF1RetryTm ...: 掉码、分钟累计与重试阶段。
;
; 函数速查:
; F_RF_Init: 初始化整个 RF 状态机，并把 CH1/2/3 清成待配对。
; F_RF_SelectNextChannel: 手动 CH1 -> CH2 -> CH3 -> Auto 切换。
; F_RF_ClearCurrentChannel: 清当前显示通道，并进入长接收重配对。
; F_RF_LoadSelectedChannelOffsets: 把通道号换成数据偏移 X 和同步偏移 Y。
; F_RF_StartLongReceive / F_RF_StopLongReceive: 进入或退出 3 分钟长接收。
; F_RF_ServiceHalfSec / F_RF_Service1Sec / F_RF_ServiceMinuteTick: 0.5 秒、1 秒、1 分钟调度入口。
; F_RF_SetSelectedChannelValid / F_RF_SetSelectedChannelLost: 更新某一路的有效/掉码状态，但掉码不清 ID。
; F_RF_OnReceiveOK / F_RF_OnReceiveFail: 一次接收窗口完成后的统一收口。
; F_RF_ClearSelectedChannel: 清某通道缓存并恢复成 NeedPair。
; F_RF_ServiceAutoView: Auto 模式每 4 秒切换显示通道。
; F_RF_ServiceReceiveWindow: 接收窗口倒计时，超时算失败。
; F_RF_ServiceSyncTimers: 推进三路同步倒计时。
; F_RF_ServiceChannel1Sync / F_RF_ServiceChannel2Sync / F_RF_ServiceChannel3Sync: 三路同步窗口触发入口。
; F_RF_RequestSync: 打开指定通道的 2 秒同步接收窗口。
; F_RF_UpdateReceiverEnable: 按 LongRecv/RecvBusy 状态驱动 PD0 低有效使能。
; F_RF_ReloadRequestChannelSync / F_RF_LoadRequestChannelFirstSync: 装载当前请求通道的下次同步点。
; F_RF_ReloadChannel1Sync / F_RF_ReloadChannel2Sync / F_RF_ReloadChannel3Sync: 重装 57/67/79 秒同步周期。
; F_RF_ServiceChannel1Minute / F_RF_ServiceChannel2Minute / F_RF_ServiceChannel3Minute / F_RF_ServiceSelectedChannelMinute:
; 按分钟累计掉码时长，并在 60/120/180 分钟节点触发补救接收。
; F_RF_ClearPendingFrame / F_RF_CheckAgainstPending: 维护10槽Pending多帧确认缓存。
; F_RF_IsRequestChannelPacketAccepted: 按 NeedPair 或已绑定 ID 决定当前包是否允许写入。
; F_RF_ResetPacketBuffer / F_RF_AppendBit0 / F_RF_AppendBit1: 维护 36bit 当前帧缓存。
; F_RF_FeedLowPulseTicks: 识别停止位和 bit0/bit1 低脉宽。
; F_RF_Service8KHzSample: 在 Timer0 中断中测脉宽并送入解码入口。
; F_RF_ParsePacket: 双帧确认后判通道、验 ID、落库、置有效。
; F_RF_BuildPacketBitMask / F_RF_SetBitInPacket0~4: 把某个 bit1 写进对应 Packet 字节。
; F_RF_LoadPacketToRequestChannel: 从 Packet0~4 提取 ID、温度、湿度、电池状态到通道 RAM。

;==========================================
;Variable RAM declare area
;==========================================
RFCRAM	.section
R_RFStatus			ds	1
R_RFChannel			ds	1
R_RFViewChannel		ds	1
R_RFRequestChannel	ds	1
R_RFLongRecvTm		ds	1
R_RFAutoSwitchTm	ds	1
R_RFRecvWindowTm	ds	1

R_RF1SyncTm			ds	1
R_RF2SyncTm			ds	1
R_RF3SyncTm			ds	1
R_RFHalfSecDiv		ds	1
R_RFMinuteStamp		ds	1

R_RF1Flags			ds	1
R_RF1IdH			ds	1
R_RF1IdL			ds	1
R_RF1TempH			ds	1
R_RF1TempL			ds	1
R_RF1Hum			ds	1
R_RF1LostCnt		ds	1
R_RF1MissMin		ds	1
R_RF1RetryStage	ds	1
R_RF1RetryTm		ds	1

R_RF2Flags			ds	1
R_RF2IdH			ds	1
R_RF2IdL			ds	1
R_RF2TempH			ds	1
R_RF2TempL			ds	1
R_RF2Hum			ds	1
R_RF2LostCnt		ds	1
R_RF2MissMin		ds	1
R_RF2RetryStage	ds	1
R_RF2RetryTm		ds	1

R_RF3Flags			ds	1
R_RF3IdH			ds	1
R_RF3IdL			ds	1
R_RF3TempH			ds	1
R_RF3TempL			ds	1
R_RF3Hum			ds	1
R_RF3LostCnt		ds	1
R_RF3MissMin		ds	1
R_RF3RetryStage	ds	1
R_RF3RetryTm		ds	1

.PAGE0
; 收包/双帧确认状态和趋势窗口都放到 PAGE0，给 0x0100 硬件栈让出足够余量。
R_RFBitCnt			ds	1
R_RFPacket0			ds	1
R_RFPacket1			ds	1
R_RFPacket2			ds	1
R_RFPacket3			ds	1
R_RFPacket4			ds	1
R_RFPendingValid	ds	1	; 已存槽数(0-4)
R_RFPendingBuf		ds	20	; 4帧×5字节
R_RFParsePending	ds	1
R_RFCaptureActive	ds	1
R_RFPulseTicks		ds	1
R_RFSamplePrev		ds	1
R_RFHighSampleCnt	ds	1
R_RFLowSampleCnt	ds	1
R_RFTrendFlags		ds	3
R_RFTrendTempEqCnt	ds	3
R_RFTrendHumEqCnt	ds	3
R_RFTrendTempMaxH	ds	3
R_RFTrendTempMaxL	ds	3
R_RFTrendTempMinH	ds	3
R_RFTrendTempMinL	ds	3
R_RFTrendHumMax	ds	3
R_RFTrendHumMin	ds	3
R_RFTrendCmpL		ds	1

;==========================================
; code starting 
;==========================================
.CODE

; 输入: 无。
; 输出: 清所有 RF 运行态，三路通道都回到 NeedPair，默认当前显示 CH1。
; 调试: 上电后先看 R_RFStatus、R_RFChannel、R_RFViewChannel、R_RF1Flags~R_RF3Flags。
F_RF_Init:					; RF模块初始化
		LDA		#00H
		STA		R_RFStatus
		STA		R_RFRequestChannel
		STA		R_RFLongRecvTm
		STA		R_RFAutoSwitchTm
		STA		R_RFRecvWindowTm
		STA		R_RFCaptureActive
		STA		R_RFSamplePrev
		STA		R_RFHighSampleCnt
		STA		R_RFLowSampleCnt
		STA		R_RFHalfSecDiv
		STA		R_RF1MissMin
		STA		R_RF1RetryStage
		STA		R_RF1RetryTm
		STA		R_RF2MissMin
		STA		R_RF2RetryStage
		STA		R_RF2RetryTm
		STA		R_RF3MissMin
		STA		R_RF3RetryStage
		STA		R_RF3RetryTm
		LDA		RTC+1
		STA		R_RFMinuteStamp
		JSR		F_RF_ResetPacketBuffer
		JSR		F_RF_ClearPendingFrame
		JSR		F_RF_UpdateReceiverEnable
		LDA		#D_RFCh1
		JSR		F_RF_ClearSelectedChannel
		LDA		#D_RFCh2
		JSR		F_RF_ClearSelectedChannel
		LDA		#D_RFCh3
		JSR		F_RF_ClearSelectedChannel
		LDA		#D_RFCh1
		STA		R_RFChannel
		STA		R_RFViewChannel
		RTS

; 输入: R_RFChannel 当前手动选择状态。
; 输出: CH1 -> CH2 -> CH3 -> Auto 循环；进入 Auto 时会置 D_RFCycleMode 并装入 4 秒轮显定时。
; 调试: 看 R_RFChannel、R_RFViewChannel、R_RFAutoSwitchTm、R_RFStatus 的 D_RFCycleMode 位。
F_RF_SelectNextChannel:			; CH1 -> CH2 -> CH3 -> Auto
		LDA		R_RFChannel
		CMP		#D_RFCh1
		BEQ		RF_NextCh2
		CMP		#D_RFCh2
		BEQ		RF_NextCh3
		CMP		#D_RFCh3
		BEQ		RF_NextAuto
RF_NextCh1:
		; 回到手动 CH1 时，必须退出 Auto 轮显模式并清轮显定时。
		LDA		#D_RFCh1
		STA		R_RFChannel
		STA		R_RFViewChannel
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFCycleMode))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFAutoSwitchTm
		RTS
RF_NextCh2:
		; CH2/CH3 的处理和 CH1 一样，都是固定显示，不走 Auto 定时。
		LDA		#D_RFCh2
		STA		R_RFChannel
		STA		R_RFViewChannel
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFCycleMode))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFAutoSwitchTm
		RTS
RF_NextCh3:
		LDA		#D_RFCh3
		STA		R_RFChannel
		STA		R_RFViewChannel
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFCycleMode))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFAutoSwitchTm
		RTS
RF_NextAuto:
		; 进入 Auto 后从 CH1 开始轮显，后续由 F_RF_ServiceAutoView 每 4 秒切一次。
		LDA		#D_RFAutoMode
		STA		R_RFChannel
		LDA		#D_RFCh1
		STA		R_RFViewChannel
		LDA		#C_RFAutoSwitch4Sec
		STA		R_RFAutoSwitchTm
		LDA		R_RFStatus
		ORA		#D_RFCycleMode
		STA		R_RFStatus
		RTS

; 输入: R_RFViewChannel 当前显示通道。
; 输出: 清当前显示通道缓存，并直接跳到长接收重配对。
; 调试: 看 R_RFViewChannel、对应通道的 Id/Flags，以及 R_RFStatus 的 D_RFLongRecv 位。
F_RF_ClearCurrentChannel:		; 长按CH后清当前通道缓存并重进长接收
		LDA		R_RFViewChannel
		PHA
		JSR		F_RF_ClearSelectedChannel
		PLA
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		R_RF1Flags,X
		ORA		#D_RFManualRetry
		STA		R_RF1Flags,X
		JMP		F_RF_StartLongReceive

; 输入: A=通道号。
; 输出: X 返回通道数据区偏移(0/10/20)，Y 返回同步计时偏移(0/1/2)。
; 调试: 如果后续写错通道，先断在这里看 A、X、Y 是否对应 CH1/CH2/CH3。
F_RF_LoadSelectedChannelOffsets:	; A=通道号, X=记录偏移(0/10/20), Y=同步偏移(0/1/2)
		LDX		#00H
		LDY		#00H
		CMP		#D_RFCh2
		BNE		RF_LoadSelectedChannelOffsets_CheckCh3
		LDX		#0AH
		LDY		#01H
		RTS
RF_LoadSelectedChannelOffsets_CheckCh3:
		CMP		#D_RFCh3
		BNE		RF_LoadSelectedChannelOffsets_End
		LDX		#14H
		LDY		#02H
RF_LoadSelectedChannelOffsets_End:
		RTS

; 输入: 无。
; 输出: 置 D_RFLongRecv，开 3 分钟长接收，清请求通道和当前接收窗口，并刷新 RF_EN。
; 调试: 看 R_RFStatus、R_RFLongRecvTm、R_RFRequestChannel、R_RFRecvWindowTm。
F_RF_StartLongReceive:			; 进入3分钟长接收状态
		LDA		R_RFStatus
		ORA		#D_RFLongRecv
		STA		R_RFStatus
		LDA		#C_RFLongRecv3Min
		STA		R_RFLongRecvTm
		LDA		#00H
		STA		R_RFRequestChannel
		STA		R_RFRecvWindowTm
		JSR		F_RF_ClearPendingFrame
		; 新一轮长接收从干净状态开始，不能带着上一轮半截 frame 继续收。
		JSR		F_RF_ResetPacketBuffer
		JSR		F_RF_UpdateReceiverEnable
		%bits	R_TimeStatus,AddOthers
		RTS

; 输入: 无。
; 输出: 清掉长接收、NeedSync、RecvBusy，并把 RF_EN 关掉。
; 调试: 长接收超时后看 R_RFStatus 和 PD0 输出是否回到高电平。
F_RF_StopLongReceive:			; 退出长接收状态
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFLongRecv+D_RFNeedSync+D_RFRecvBusy))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFLongRecvTm
		STA		R_RFRequestChannel
		STA		R_RFRecvWindowTm
		JSR		F_RF_ClearPendingFrame
		JSR		F_RF_ResetPacketBuffer
		JSR		F_RF_UpdateReceiverEnable
		%bits	R_TimeStatus,AddOthers
		RTS

; 输入: 由 0.5 秒节拍调用。
; 输出: 先推进接收窗口与同步窗口，再每两次补跑一次 1 秒业务。
; 调试: 看 R_RFHalfSecDiv 是否 0/1 翻转，以及同步计时是否按 0.5 秒递减。
F_RF_ServiceHalfSec:			; 0.5秒调度：同步窗口与同步计时按半秒粒度运行
		; 最新协议已改回“提前 2 秒开始接收”，所以同步相关计时全部按 0.5 秒粒度维护。
		JSR		F_RF_ServiceReceiveWindow
		JSR		F_RF_ServiceSyncTimers
;		JSR		F_RF_UpdateReceiverEnable
		LDA		R_RFStatus
		AND		#D_RFLongRecv
		BEQ		RF_ServiceHalfSec_Check1Sec
		; 长接收中的 RF 图标需要按 1Hz 闪烁，所以半秒就要刷新一次 LCD。
		%bits	R_TimeStatus,AddOthers

	RF_ServiceHalfSec_Check1Sec:
		LDA		R_RFHalfSecDiv
		EOR		#01H
		STA		R_RFHalfSecDiv
		BNE		RF_ServiceHalfSec_End
		JSR		F_RF_Service1Sec
RF_ServiceHalfSec_End:
		RTS

; 输入: 由 F_RF_ServiceHalfSec 每 1 秒调用一次。
; 输出: 跑轮显、分钟跳变检测，并维护长接收 3 分钟寿命。
; 调试: 看 R_RFAutoSwitchTm、R_RFMinuteStamp、R_RFLongRecvTm 是否按秒变化。
F_RF_Service1Sec:			; 1秒业务入口：处理轮显、长接收寿命和分钟边界
	RF_Service1Sec_Common:
		JSR		F_RF_ServiceAutoView
		JSR		F_RF_ServiceMinuteTick

RF_CheckLongReceive:
		LDA		R_RFStatus
		AND		#D_RFLongRecv
		BEQ		RF_Service1Sec_RunSync
		; 长接收寿命只在 D_RFLongRecv 期间递减，降到 0 就自动退出。
		LDA		R_RFLongRecvTm
		BEQ		RF_StopLongReceive_Timeout
		SEC
		SBC		#01H
		STA		R_RFLongRecvTm
		BNE		RF_Service1Sec_RunSync
RF_StopLongReceive_Timeout:
		; 手动清通道后若 3 分钟仍未收到，需要从这里转入掉码分钟规则。
		JSR		F_RF_ArmManualRetryChannels
		; 3 分钟到了仍未配对的通道（未手动清但也没收到包），阻塞其后续自动接收，
		; 之后必须手动按 CH 键才能重新打开配对。
		LDX		#00H
		JSR		F_RF_CloseSelectedIfUnpaired
		LDX		#0AH
		JSR		F_RF_CloseSelectedIfUnpaired
		LDX		#14H
		JSR		F_RF_CloseSelectedIfUnpaired
		; 3 分钟长接收到点后，统一走 StopLongReceive 收口并关闭 RF_EN。
		JSR		F_RF_StopLongReceive

	RF_Service1Sec_RunSync:
RF_Service1Sec_End:
		RTS

; 输入: 无。
; 输出: 把“手动长按 CH 清通道后，3 分钟仍未收到”的通道接入掉码分钟链。
; 调试: 看 NeedPair+ManualRetry 通道是否在长接收超时后得到 LostCnt=1。
F_RF_ArmManualRetryChannels:
		LDX		#00H
		JSR		F_RF_ArmSelectedManualRetryChannel
		LDX		#0AH
		JSR		F_RF_ArmSelectedManualRetryChannel
		LDX		#14H
		JMP		F_RF_ArmSelectedManualRetryChannel

; 输入: X=通道记录偏移(0/10/20)。
; 输出: ManualRetry 且仍 NeedPair 的通道，超时后开始按掉码分钟规则累计。
F_RF_ArmSelectedManualRetryChannel:
		LDA		R_RF1Flags,X
		AND		#D_RFManualRetry
		BEQ		RF_ArmSelectedManualRetryChannel_End
		LDA		R_RF1Flags,X
		AND		#D_RFNeedPair
		BEQ		RF_ArmSelectedManualRetryChannel_End
		LDA		R_RF1Flags,X
		ORA		#D_RFLost
		STA		R_RF1Flags,X
		LDA		R_RF1LostCnt,X
		BNE		RF_ArmSelectedManualRetryChannel_End
		LDA		#01H
		STA		R_RF1LostCnt,X
		LDA		#00H
		STA		R_RF1MissMin,X
		STA		R_RF1RetryStage,X
		STA		R_RF1RetryTm,X
RF_ArmSelectedManualRetryChannel_End:
		RTS

; 输入: X=通道记录偏移(0/10/20)。
; 输出: 若该通道为 NeedPair 且非 ManualRetry，则置 D_RFBlocked 阻塞位，同步定时器 idle。
; 调试: 看 Flags 的 Blocked 位是否置位，NeedPair 保持不变。
F_RF_CloseSelectedIfUnpaired:
		LDA		R_RF1Flags,X
		AND		#D_RFNeedPair
		BEQ		RF_CloseSelectedIfUnpaired_End
		LDA		R_RF1Flags,X
		AND		#D_RFManualRetry
		BNE		RF_CloseSelectedIfUnpaired_End
		; 阻塞该通道：置 D_RFBlocked（NeedPair 保留），同步定时器置 idle
		LDA		R_RF1Flags,X
		ORA		#D_RFBlocked
		STA		R_RF1Flags,X
		; X→Y 偏移映射：0→0, 0AH→1, 14H→2
		CPX		#00H
		BEQ		RF_CloseSync_Ch1
		CPX		#0AH
		BEQ		RF_CloseSync_Ch2
		LDY		#02H
		JMP		RF_CloseSync_SetIdle
RF_CloseSync_Ch1:
		LDY		#00H
		JMP		RF_CloseSync_SetIdle
RF_CloseSync_Ch2:
		LDY		#01H
RF_CloseSync_SetIdle:
		LDA		#C_RFSyncIdle
		STA		R_RF1SyncTm,Y
RF_CloseSelectedIfUnpaired_End:
		RTS

; 输入: RTC+1 当前分钟值。
; 输出: 只有分钟发生跳变时，才推进三路掉码分钟累计状态机。
; 调试: 看 R_RFMinuteStamp 是否跟 RTC+1 同步更新。
F_RF_ServiceMinuteTick:		; 仅在 RTC 分钟跳变时推进三路掉码分级状态机
		; 60/120 分钟掉码分级按 RTC 的分钟跳变计数，不再按同步失败次数粗暴代替。
		LDA		RTC+1
		CMP		R_RFMinuteStamp
		BEQ		RF_ServiceMinuteTick_End
		STA		R_RFMinuteStamp
		JSR		F_RF_ServiceChannel1Minute
		JSR		F_RF_ServiceChannel2Minute
		JSR		F_RF_ServiceChannel3Minute
RF_ServiceMinuteTick_End:
		RTS

; 输入: A=通道号。
; 输出: 清 lost/NeedPair，置 valid，并把该通道掉码与重试计数清零。
; 调试: 收到有效包后看对应通道 Flags 是否从 Lost/NeedPair 变成 Valid。
F_RF_SetSelectedChannelValid:		; A=通道号，清掉 lost/retry/blocked 并恢复有效标志
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		R_RF1Flags,X
		AND		#(.NOT.(D_RFLost+D_RFNeedPair+D_RFManualRetry+D_RFBlocked))
		ORA		#D_RFValid
		STA		R_RF1Flags,X
		LDA		#00H
		STA		R_RF1LostCnt,X
		STA		R_RF1MissMin,X
		STA		R_RF1RetryStage,X
		STA		R_RF1RetryTm,X
		RTS

; 输入: A=通道号。
; 输出: 仅置 Lost，不清 ID，也不回到 NeedPair。
; 调试: 重点看对应通道 Flags、LostCnt、IdL，确认“掉码不清 ID”成立。
F_RF_SetSelectedChannelLost:		; A=通道号，仅置 lost 但保留已配对 ID
		JSR		F_RF_LoadSelectedChannelOffsets
		; 旧逻辑会直接置 NeedPair，和“掉码不清 ID”冲突，保留注释不删除。
		; 		LDA		R_RF1Flags,X
		; 		AND		#(.NOT.(D_RFValid))
		; 		ORA		#(D_RFLost+D_RFNeedPair)
		LDA		R_RF1Flags,X
		AND		#(.NOT.(D_RFValid+D_RFNeedPair))
		ORA		#D_RFLost
		STA		R_RF1Flags,X
		RTS

; 输入: A=请求通道号。
; 输出: 对应通道的 LostCnt +1；满 3 次时钳到 3 并置 lost。
; 调试: 看对应通道 LostCnt 是否只增一次，以及第 3 次时 Flags 是否转成 lost。
F_RF_HandleSelectedChannelFail:
		PHA
		JSR		F_RF_LoadSelectedChannelOffsets
		INC		R_RF1LostCnt,X
		LDA		R_RF1LostCnt,X
		CMP		#C_RFFail3Times
		BCC		RF_HandleSelectedChannelFail_End
		LDA		#C_RFFail3Times
		STA		R_RF1LostCnt,X
		PLA
		JMP		F_RF_SetSelectedChannelLost

RF_HandleSelectedChannelFail_End:
		PLA
		RTS

; 输入: 无。
; 输出: 只要三路里仍有 NeedPair/Lost，就返回 SEC 继续长接收；否则返回 CLC 可提前退出。
; 调试: 上电长接收或掉码重收时，看三路 Flags 的 Lost/NeedPair 是否都清零。
F_RF_ShouldContinueLongReceive:
		LDA		R_RF1Flags
		AND		#(D_RFLost+D_RFNeedPair)
		BNE		RF_ShouldContinueLongReceive_Yes
		LDA		R_RF2Flags
		AND		#(D_RFLost+D_RFNeedPair)
		BNE		RF_ShouldContinueLongReceive_Yes
		LDA		R_RF3Flags
		AND		#(D_RFLost+D_RFNeedPair)
		BNE		RF_ShouldContinueLongReceive_Yes
		CLC
		RTS

RF_ShouldContinueLongReceive_Yes:
		SEC
		RTS

; 输入: 当前一帧已经通过双帧确认并完成落库。
; 输出: 收口本次接收窗口，必要时装下次同步点，并把对应通道置 Valid。
; 调试: 成功收包后看 R_RFRecvWindowTm 是否清零、R_RFRequestChannel 是否清掉、通道 Flags 是否置 Valid。
F_RF_OnReceiveOK:			; RF底层收到有效包后调用
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFNeedSync+D_RFRecvBusy))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFRecvWindowTm
		JSR		F_RF_ClearPendingFrame
		JSR		F_RF_UpdateReceiverEnable
		%bits	R_TimeStatus,AddOthers
	RF_OnReceiveOK_CheckRequestChannel:
		LDA		R_RFRequestChannel
		JSR		F_RF_SetSelectedChannelValid
		LDA		R_RFStatus
		AND		#D_RFLongRecv
		BNE		RF_OnReceiveOK_LongRecv
		; 同步成功：从抓码点重装计时器，下次开窗=抓码+56s/66s/78s
		LDA		R_RFRequestChannel
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		T_RFReloadTick,Y
		STA		R_RF1SyncTm,Y
		JMP		RF_ClearRequestChannel
RF_OnReceiveOK_LongRecv:
		; 长接收里收包成功后，要先给该通道补上下次常规同步点，
		; 再判断三路是否都已经收齐，以便提前退出 3 分钟长接收。
		JSR		F_RF_LoadRequestChannelFirstSync
		JSR		F_RF_ShouldContinueLongReceive
		BCS		RF_ClearRequestChannel
		JSR		F_RF_StopLongReceive
		JMP		RF_ClearRequestChannel

; 输入: 一次接收窗口超时或收到坏包。
; 输出: 收口本次窗口，LostCnt 累加；连续 3 次失败就把该通道标 Lost。
; 调试: 看 R_RFRequestChannel、R_RFRecvWindowTm、对应通道 LostCnt/Flags。
F_RF_OnReceiveFail:			; RF底层接收超时或校验失败后调用
		LDA		R_RFStatus
		AND		#(.NOT.(D_RFNeedSync+D_RFRecvBusy))
		STA		R_RFStatus
		LDA		#00H
		STA		R_RFRecvWindowTm
		JSR		F_RF_ClearPendingFrame
		; 超时很可能正停在一帧中间，收口时必须把当前 frame 状态一起丢掉。
		JSR		F_RF_ResetPacketBuffer
		JSR		F_RF_UpdateReceiverEnable
		%bits	R_TimeStatus,AddOthers
		LDA		R_RFRequestChannel
		JSR		F_RF_HandleSelectedChannelFail
		; ===== 同步失败校准：窗已过3s(6tick)，覆盖计时器保证总周期 =====
		LDA		R_RFRequestChannel
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		T_RFCloseTick,Y
		STA		R_RF1SyncTm,Y

RF_ClearRequestChannel:
		; 成功/失败最终都要把请求通道清掉，等待下一次窗口重新指定目标通道。
		LDA		#00H
		STA		R_RFRequestChannel
		RTS

; 输入: A=通道号。
; 输出: 清空该通道的 ID、温湿度、掉码状态，并置回 NeedPair。
; 调试: 长按清通道后，看该通道 Flags 是否只剩 NeedPair，SyncTm 是否被置 idle。
F_RF_ClearSelectedChannel:		; A=通道号，清 ID/温湿度/重试状态并回到待配对
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		#00H
		STA		R_RF1IdH,X
		STA		R_RF1IdL,X
		STA		R_RF1TempH,X
		STA		R_RF1TempL,X
		STA		R_RF1Hum,X
		STA		R_RF1LostCnt,X
		STA		R_RF1MissMin,X
		STA		R_RF1RetryStage,X
		STA		R_RF1RetryTm,X
		STA		R_RFTrendFlags,Y
		STA		R_RFTrendTempEqCnt,Y
		STA		R_RFTrendHumEqCnt,Y
		STA		R_RFTrendTempMaxH,Y
		STA		R_RFTrendTempMaxL,Y
		STA		R_RFTrendTempMinH,Y
		STA		R_RFTrendTempMinL,Y
		STA		R_RFTrendHumMax,Y
		STA		R_RFTrendHumMin,Y
		LDA		#C_RFSyncIdle
		STA		R_RF1SyncTm,Y
		LDA		#D_RFNeedPair
		STA		R_RF1Flags,X
		RTS

; 输入: Auto 模式下每秒调用一次。
; 输出: R_RFAutoSwitchTm 递减到 0 时切到下一显示通道。
; 调试: 看 R_RFStatus 的 D_RFCycleMode、R_RFAutoSwitchTm、R_RFViewChannel。
F_RF_ServiceAutoView:			; Auto 模式下每 4 秒轮显一个户外通道
		LDA		R_KeyValue
		ORA		R_OldKeyValue
		BNE		RF_ServiceAutoView_End
		LDA		R_RFStatus
		AND		#D_RFCycleMode
		BEQ		RF_ServiceAutoView_End
		LDA		R_RFAutoSwitchTm
		BEQ		RF_AutoSwitchReload
		SEC
		SBC		#01H
		STA		R_RFAutoSwitchTm
		BNE		RF_ServiceAutoView_End
RF_AutoSwitchReload:
		; 计时到点后先重装 4 秒，再切下一个显示通道。
		LDA		#C_RFAutoSwitch4Sec
		STA		R_RFAutoSwitchTm
		LDA		R_RFViewChannel
		CMP		#D_RFCh1
		BEQ		RF_AutoToCh2
		CMP		#D_RFCh2
		BEQ		RF_AutoToCh3
		JMP		RF_AutoToCh1
RF_AutoToCh2:
		LDA		#D_RFCh2
		STA		R_RFViewChannel
		%bits	R_TimeStatus,AddOthers
		RTS
RF_AutoToCh3:
		LDA		#D_RFCh3
		STA		R_RFViewChannel
		%bits	R_TimeStatus,AddOthers
		RTS

RF_AutoToCh1:
		LDA		#D_RFCh1
		STA		R_RFViewChannel
		%bits	R_TimeStatus,AddOthers
RF_ServiceAutoView_End:
		RTS

; 输入: 当前是否处于 D_RFRecvBusy。
; 输出: 接收窗口按 0.5 秒单位倒计时，到 0 直接走 F_RF_OnReceiveFail。
; 调试: 开窗后盯 R_RFRecvWindowTm，从 8 递减到 0 的过程最直观。
F_RF_ServiceReceiveWindow:		; 接收窗口倒计时，超时即按一次失败处理
		LDA		R_RFStatus
		AND		#D_RFRecvBusy
		BEQ		RF_ServiceReceiveWindow_End
		LDA		R_RFRecvWindowTm
		BEQ		RF_ServiceReceiveWindow_Fail
		SEC
		SBC		#01H
		STA		R_RFRecvWindowTm
		BNE		RF_ServiceReceiveWindow_End
RF_ServiceReceiveWindow_Fail:
		JSR		F_RF_OnReceiveFail
RF_ServiceReceiveWindow_End:
		RTS

; 输入: 无。
; 输出: 顺序推进 CH1/CH2/CH3 三个同步倒计时。
; 调试: 看 R_RF1SyncTm~R_RF3SyncTm 是否每 0.5 秒递减或保持 FF。
F_RF_ServiceSyncTimers:			; 统一推进 CH1/CH2/CH3 的同步倒计时
		JSR		F_RF_ServiceChannel1Sync
		JSR		F_RF_ServiceChannel2Sync
		JSR		F_RF_ServiceChannel3Sync
RF_ServiceSyncTimers_End:
		RTS

; 输入: A=通道号，Y=对应 SyncTm 偏移(0/1/2)。
; 输出: SyncTm 在非 FF/0 时递减，到点后若当前空闲则请求该通道同步接收。
; 调试: 看 R_RF1SyncTm,Y 递减到 0 时，R_RFRequestChannel 是否切到 A 指定的通道。
F_RF_ServiceSelectedChannelSync:
		PHA
		LDA		R_RF1SyncTm,Y
		CMP		#C_RFSyncIdle
		BEQ		RF_ServiceSelectedChannelSync_End
		CMP		#00H
		BEQ		RF_RequestSelectedChannelSync
		SEC
		SBC		#01H
		STA		R_RF1SyncTm,Y
		BNE		RF_ServiceSelectedChannelSync_End
RF_RequestSelectedChannelSync:
		LDA		R_RFStatus
		AND		#(D_RFRecvBusy+D_RFLongRecv)
		BNE		RF_ServiceSelectedChannelSync_End
		PLA
		JMP		F_RF_RequestSync

RF_ServiceSelectedChannelSync_End:
		PLA
		RTS

; 输入: CH1 的同步倒计时 R_RF1SyncTm。
; 输出: 计时从非 FF 递减到 0 后，如果当前空闲，就请求一次 CH1 同步接收。
; 调试: 看 R_RF1SyncTm 递减到 0 时，R_RFRequestChannel 是否切到 CH1。
F_RF_ServiceChannel1Sync:		; 维护 CH1 的同步定时，到点后发起接收
		LDA		#D_RFCh1
		LDY		#00H
		JMP		F_RF_ServiceSelectedChannelSync

; 输入/输出与 CH1 同步入口相同，只是对象换成 CH2。
; 调试: 看 R_RF2SyncTm、R_RFRequestChannel。
F_RF_ServiceChannel2Sync:		; 维护 CH2 的同步定时，到点后发起接收
		LDA		#D_RFCh2
		LDY		#01H
		JMP		F_RF_ServiceSelectedChannelSync

; 输入/输出与 CH1 同步入口相同，只是对象换成 CH3。
; 调试: 看 R_RF3SyncTm、R_RFRequestChannel。
F_RF_ServiceChannel3Sync:		; 维护 CH3 的同步定时，到点后发起接收
		LDA		#D_RFCh3
		LDY		#02H
		JMP		F_RF_ServiceSelectedChannelSync

; 输入: A=请求通道号。
; 输出: 记录当前请求通道、重装同步周期、清双帧缓存、开启 4 秒接收窗口并拉低 PD0。
; 调试: 开窗点先看 R_RFRequestChannel、R_RFRecvWindowTm、R_RFStatus。
F_RF_RequestSync:			; 发起指定通道的一次同步接收窗口
		STA		R_RFRequestChannel
		; 这里先重装“下一个”同步周期，这样即使本次窗口失败也不会丢节拍。
		JSR		F_RF_ReloadRequestChannelSync
		; 新窗口开始前要清 pending，避免把上次窗口残留帧拿来比较。
		JSR		F_RF_ClearPendingFrame
		; 同时清当前半截包，避免上个窗口没收完的 BIT 串到这次窗口。
		JSR		F_RF_ResetPacketBuffer
		LDA		#C_RFRecvWindow4SecTick
		STA		R_RFRecvWindowTm
		LDA		R_RFStatus
		ORA		#(D_RFNeedSync+D_RFRecvBusy)
		STA		R_RFStatus
		JSR		F_RF_UpdateReceiverEnable
		%bits	R_TimeStatus,AddOthers
		RTS

; 输入: R_RFStatus 的 LongRecv/RecvBusy。
; 输出: 只要任一接收态成立，PD0 就拉低使能 RF；否则拉高关闭。
; 调试: 看 R_PortD_Data_Buf bit0 和外部 PD0 实际电平。
F_RF_UpdateReceiverEnable:		; PD0=RF_EN，低有效；PD1 保持输入浮空收码
		LDA		P_IOD_DIR_Map
		ORA		#D_Bit0
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#D_Bit1
		STA		R_PortD_Data_Buf
		LDA		R_RFStatus
		AND		#(D_RFLongRecv+D_RFRecvBusy)
		BEQ		RF_UpdateReceiverDisable
		LDA		R_PortD_Data_Buf
		AND		#FEH
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
		CLI		
		RTS

RF_UpdateReceiverDisable:
		LDA		R_PortD_Data_Buf
		ORA		#D_Bit0
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data		
		RTS

; 输入: R_RFRequestChannel。
; 输出: 按当前请求通道选择同步周期，查表写回对应 SyncTm。
; 调试: 看请求通道变化后，哪一路 SyncTm 被重新装载。
F_RF_ReloadRequestChannelSync:		; 按当前请求通道重装常规同步周期（查表）
		LDA		R_RFRequestChannel
		JSR		F_RF_LoadSelectedChannelOffsets
		LDA		T_RFReloadTick,Y
		STA		R_RF1SyncTm,Y
		RTS

; 旧的按请求通道分拆 ReloadChannel 入口已由上方查表替代，
; F_RF_ReloadChannel1Sync / F_RF_ReloadChannel2Sync / F_RF_ReloadChannel3Sync 不再需要。

; 输入: R_RFRequestChannel。
; 输出: 首次配对成功后，把该通道同步点装到“完整周期 - 2 秒提前量”。
; 调试: 长接收首次配对成功后，看对应 SyncTm 是否被写成周期减 4 tick。
F_RF_LoadRequestChannelFirstSync	equ	F_RF_ReloadRequestChannelSync

; 同步周期查表，按通道索引 0=CH1/1=CH2/2=CH3
T_RFReloadTick:
		.DB		C_RFCh1Sync57Tick, C_RFCh2Sync67Tick, C_RFCh3Sync79Tick
T_RFCloseTick:
		.DB		C_RFCh1SyncCloseTick, C_RFCh2SyncCloseTick, C_RFCh3SyncCloseTick

; 这三个函数只是给通用分钟状态机装不同的 X/Y 偏移。
F_RF_ServiceChannel1Minute:		; 按分钟累计 CH1 掉码时长并触发 60/120/180 分钟策略
		LDX		#00H
		LDY		#00H
		JMP		F_RF_ServiceSelectedChannelMinute

F_RF_ServiceChannel2Minute:		; 按分钟累计 CH2 掉码时长并触发 60/120/180 分钟策略
		LDX		#0AH
		LDY		#01H
		JMP		F_RF_ServiceSelectedChannelMinute

F_RF_ServiceChannel3Minute:		; 按分钟累计 CH3 掉码时长并触发 60/120/小时重试策略
		LDX		#14H
		LDY		#02H
		; 60 分钟先触发一次 3 分钟长接收；120 分钟后改成每小时 1 次，总共 3 次。
		JMP		F_RF_ServiceSelectedChannelMinute

; 输入: X=通道数据偏移，Y=同步计时偏移。
; 输出: LostCnt 非 0 时按分钟累计 MissMin，并在 60/120 分钟点切换到 3 分钟长接收/小时重试。
; 调试: 重点看 MissMin、RetryStage、RetryTm、对应 SyncTm。
F_RF_ServiceSelectedChannelMinute:	; X=通道记录偏移(0/10/20), Y=同步计时偏移(0/1/2)
		LDA		R_RF1LostCnt,X
		; LostCnt 为 0 说明这一路没有掉码，不需要累计分钟数。
		BEQ		RF_ServiceSelectedChannelMinute_End
		LDA		R_RF1RetryStage,X
		CMP		#C_RFFinalRetryStage
		BCS		RF_ServiceSelectedChannelMinute_End
		; RetryStage=2~4 表示 120 分钟后的小时重试窗口。
		CMP		#C_RFHourlyRetryStageFirst
		BCS		RF_ServiceSelectedChannelRetryHourly
		LDA		R_RF1MissMin,X
		CLC
		ADC		#01H
		STA		R_RF1MissMin,X
		CMP		#C_RFFail60Min
		BEQ		RF_SelectedChannelEnter60MinLongRecv
		CMP		#C_RFFail120Min
		BEQ		RF_SelectedChannelEnter120MinLongRecv
RF_ServiceSelectedChannelMinute_End:
		RTS

RF_SelectedChannelEnter60MinLongRecv:
		; 第一次累计到 60 分钟，先拉起一次 3 分钟长接收尝试找回信号。
		LDA		#01H
		STA		R_RF1RetryStage,X
		LDA		#C_RFSyncIdle
		STA		R_RF1SyncTm,Y
		JMP		F_RF_StartLongReceive

RF_SelectedChannelEnter120MinLongRecv:
		; 到 120 分钟后清除 ID，进入小时重试模式：马上开 1 次长接收，
		; 之后每次长接收结束再等完整 60 分钟，总共尝试 3 次。
		LDA		#00H
		STA		R_RF1IdH,X
		STA		R_RF1IdL,X
		LDA		R_RF1Flags,X
		AND		#(.NOT.(D_RFValid+D_RFLost))
		ORA		#D_RFNeedPair
		STA		R_RF1Flags,X
		LDA		#C_RFHourlyRetryStageFirst
		STA		R_RF1RetryStage,X
		LDA		#C_RFFailRetry63Min
		STA		R_RF1RetryTm,X
		LDA		#C_RFSyncIdle
		STA		R_RF1SyncTm,Y
		JMP		F_RF_StartLongReceive

RF_ServiceSelectedChannelRetryHourly:
		LDA		R_RF1RetryTm,X
		BEQ		RF_SelectedChannelRetryHourly
		SEC
		SBC		#01H
		STA		R_RF1RetryTm,X
		BNE		RF_ServiceSelectedChannelMinute_End

RF_SelectedChannelRetryHourly:
		LDA		R_RF1RetryStage,X
		CMP		#C_RFHourlyRetryStageLast
		BCS		RF_SelectedChannelRetryHourlyFinish
		INC		R_RF1RetryStage,X
		LDA		#C_RFFailRetry63Min
		STA		R_RF1RetryTm,X
		LDA		#C_RFSyncIdle
		STA		R_RF1SyncTm,Y
		JMP		F_RF_StartLongReceive

RF_SelectedChannelRetryHourlyFinish:
		; 小时重试第 3 次仍失败后，后续不再自动打开长接收，保留手动 CH 清配入口。
		LDA		#C_RFFinalRetryStage
		STA		R_RF1RetryStage,X
		LDA		#00H
		STA		R_RF1RetryTm,X
		RTS

; 输入: 无。
; 输出: 仅清掉 pending 有效标志，让下一帧重新成为“第一帧”。
; 调试: 盯 R_RFPendingValid。
F_RF_ClearPendingFrame:			; 清空双帧确认缓存状态
		LDA		#00H
		STA		R_RFPendingValid
		RTS

T_PendOfs:
		.DB		0,5,10,15

F_RF_SaveToPendingSlot:
		LDA		T_PendOfs,X
		TAX
		LDY		#00H
RF_SaveLoop:
		LDA		R_RFPacket0,Y
		STA		R_RFPendingBuf,X
		INX
		INY
		CPY		#05H
		BCC		RF_SaveLoop
		RTS

F_RF_ShiftPendingUp:
		LDX		#00H
		LDY		#05H
RF_ShiftLoop:
		LDA		R_RFPendingBuf,Y
		STA		R_RFPendingBuf,X
		INX
		INY
		CPX		#0FH
		BCC		RF_ShiftLoop
		RTS

F_RF_CmpCurrentWithSlot:
		TAX
		LDA		T_PendOfs,X
		TAX
		LDY		#00H
RF_CmpLoop:
		LDA		R_RFPacket0,Y
		CMP		R_RFPendingBuf,X
		BNE		RF_CmpFail
		INX
		INY
		CPY		#05H
		BCC		RF_CmpLoop
		SEC
		RTS
RF_CmpFail:
		CLC
		RTS

F_RF_IsRequestChannelPacketAccepted:
		; 只有 NeedPair 通道允许接收新 ID；已配对通道必须同 ID 才能恢复或更新。
		LDA		R_RFRequestChannel
		CMP		#D_RFCh2
		BEQ		RF_IsChannel2PacketAccepted
		CMP		#D_RFCh3
		BEQ		RF_IsChannel3PacketAccepted

RF_IsChannel1PacketAccepted:
		LDA		R_RF1Flags
		BMI		RF_RequestChannelPacketReject	; bit7（D_RFBlocked）→ 被阻塞，拒绝
		AND		#D_RFNeedPair
		; NeedPair 说明 CH1 还没绑定过 ID，当前包直接允许写入。
		BNE		RF_RequestChannelPacketAccept
		LDA		R_RFPacket0
		CMP		R_RF1IdL
		; 已配对后只有 ID 一致才允许恢复/更新该通道。
		BEQ		RF_RequestChannelPacketAccept
		CLC
		RTS

RF_IsChannel2PacketAccepted:
		LDA		R_RF2Flags
		BMI		RF_RequestChannelPacketReject	; bit7（D_RFBlocked）→ 被阻塞，拒绝
		AND		#D_RFNeedPair
		BNE		RF_RequestChannelPacketAccept
		LDA		R_RFPacket0
		CMP		R_RF2IdL
		BEQ		RF_RequestChannelPacketAccept
		CLC
		RTS

RF_IsChannel3PacketAccepted:
		LDA		R_RF3Flags
		BMI		RF_RequestChannelPacketReject	; bit7（D_RFBlocked）→ 被阻塞，拒绝
		AND		#D_RFNeedPair
		BNE		RF_RequestChannelPacketAccept
		LDA		R_RFPacket0
		CMP		R_RF3IdL
		BEQ		RF_RequestChannelPacketAccept
		CLC
		RTS

RF_RequestChannelPacketReject:
		CLC
		RTS

RF_RequestChannelPacketAccept:
		SEC
		RTS

; 输入: 无。
; 输出: 清当前帧缓存和 CaptureActive，准备重新从停止位开始抓数。
; 调试: 看 R_RFBitCnt 是否回 0，R_RFCaptureActive 是否清零。
F_RF_ResetPacketBuffer:			; 清当前 36bit 收包缓存，不动双帧 pending 缓存
		LDA		#00H
		STA		R_RFBitCnt
		STA		R_RFCaptureActive
		STA		R_RFHighSampleCnt
		STA		R_RFPacket0
		STA		R_RFPacket1
		STA		R_RFPacket2
		STA		R_RFPacket3
		STA		R_RFPacket4
		RTS

; 输入: 当前收到一个 bit0。
; 输出: 仅递增 R_RFBitCnt，因为 bit0 在缓存里天然就是 0。
; 调试: 看 R_RFBitCnt 是否递增但 Packet0~4 不变。
F_RF_AppendBit0:			; Bit0 只需要推进位计数，因为 Packet 缓冲默认就是 0
		LDA		R_RFBitCnt
		CMP		#C_RFPacketBits36
		BCS		RF_AppendBit_End
		INC		R_RFBitCnt
		RTS

; 输入: 当前收到一个 bit1。
; 输出: 按 bit 序号把 1 写到 Packet0~4 中的目标位，再递增 bit 计数。
; 调试: 看 R_RFBitCnt 和对应 Packet 字节的某一位是否被置 1。
F_RF_AppendBit1:			; Bit1 要按当前 bit 序号写入 Packet0~4 的目标位
		LDA		R_RFBitCnt
		CMP		#C_RFPacketBits36
		BCS		RF_AppendBit_End
		CMP		#08H
		BCC		RF_AppendPacket0
		CMP		#10H
		BCC		RF_AppendPacket1
		CMP		#18H
		BCC		RF_AppendPacket2
		CMP		#20H
		BCC		RF_AppendPacket3
		JMP		RF_AppendPacket4

RF_AppendPacket0:
		LDX		R_RFBitCnt
		JSR		F_RF_SetBitInPacket0
		JMP		RF_AppendBit_Inc

RF_AppendPacket1:
		LDX		R_RFBitCnt
		TXA
		SEC
		SBC		#08H
		TAX
		JSR		F_RF_SetBitInPacket1
		JMP		RF_AppendBit_Inc

RF_AppendPacket2:
		LDX		R_RFBitCnt
		TXA
		SEC
		SBC		#10H
		TAX
		JSR		F_RF_SetBitInPacket2
		JMP		RF_AppendBit_Inc

RF_AppendPacket3:
		LDX		R_RFBitCnt
		TXA
		SEC
		SBC		#18H
		TAX
		JSR		F_RF_SetBitInPacket3
		JMP		RF_AppendBit_Inc

RF_AppendPacket4:
		LDX		R_RFBitCnt
		TXA
		SEC
		SBC		#20H
		TAX
		JSR		F_RF_SetBitInPacket4

RF_AppendBit_Inc:
		INC		R_RFBitCnt

RF_AppendBit_End:
		RTS

; 输入: A=一次连续低电平的宽度，单位为 Timer0 实测约 244us/sample。
; 输出: 识别停止位/bit0/bit1，并在满 36bit 时转入解包流程。
; 调试: 先看 R_RFPulseTicks、R_RFCaptureActive、R_RFBitCnt、R_RFPacket0~4。
F_RF_FeedLowPulseTicks:		; 先认 4~5ms 停止位作为起帧锚点，再把后续低脉宽翻成 36bit 数据
		STA		R_RFPulseTicks
		; 停止位既是上一帧的结尾，也是下一帧开始抓数的锚点；前导码全部忽略。
		CMP		#C_RFStopLowMinSample
		BCC		RF_FeedLowPulse_CheckCapture
		CMP		#C_RFStopLowMaxSample+1
		BCC		RF_FeedLowPulse_StartFrame

RF_FeedLowPulse_CheckCapture:
		; 只有已经见过停止位时，后面的 1ms/2ms 低脉宽才会被当成数据位。
		LDA		R_RFCaptureActive
		BEQ		RF_FeedLowPulse_End
		LDA		R_RFPulseTicks
		CMP		#C_RFBit1LowMinSample
		BCC		RF_FeedLowPulse_Invalid
		CMP		#C_RFBit1LowMaxSample+1
		BCC		RF_FeedLowPulse_Bit1
		CMP		#C_RFBit0LowMinSample
		BCC		RF_FeedLowPulse_Invalid
		CMP		#C_RFBit0LowMaxSample+1
		BCC		RF_FeedLowPulse_Bit0

RF_FeedLowPulse_Invalid:
		; 中途遇到非法低脉宽，整帧作废，等待下一次停止位重开。
		JMP		F_RF_ResetPacketBuffer

RF_FeedLowPulse_StartFrame:
		; 锁定一帧新的数据，后续 bit 从 Packet0 的 bit7 开始依次写入。
		JSR		F_RF_ResetPacketBuffer
		LDA		#01H
		STA		R_RFCaptureActive
		RTS

RF_FeedLowPulse_Bit1:
		; 1ms 低脉宽判成 bit1。
		JSR		F_RF_AppendBit1
		JMP		RF_FeedLowPulse_AfterBit

RF_FeedLowPulse_Bit0:
		; 2ms 低脉宽判成 bit0。
		JSR		F_RF_AppendBit0

RF_FeedLowPulse_AfterBit:
		LDA		R_RFBitCnt
		CMP		#C_RFPacketBits36
		BCC		RF_FeedLowPulse_End
		; 满 36bit 直接存 pending 缓冲
		LDX		R_RFPendingValid
		CPX		#C_RFPendMax
		BCC		RF_AfterBit_Save
		JSR		F_RF_ShiftPendingUp
		LDX		#03H				; C_RFPendMax-1
		JSR		F_RF_SaveToPendingSlot
		JMP		RF_AfterBit_Done
RF_AfterBit_Save:
		JSR		F_RF_SaveToPendingSlot
		INC		R_RFPendingValid
RF_AfterBit_Done:
		LDA		#00H
		STA		R_RFCaptureActive
		STA		R_RFSamplePrev
		STA		R_RFHighSampleCnt
		STA		R_RFLowSampleCnt
		RTS
; 输入: 无。
; 输出: 如果 IRQ 已经收满 36bit，就在主循环里补做解析，避免把重调用链压在中断栈上。
F_RF_ServicePendingParse:		; 主循环入口：pending攒够2帧后比对
		LDA		R_RFPendingValid
		CMP		#02H
		BCC		RF_ServicePendingParse_End
		JSR		F_RF_ParsePacket
RF_ServicePendingParse_End:
		RTS

RF_FeedLowPulse_End:
		RTS

; 输入: Timer0 中断节拍下的 PD1 当前电平。
; 输出: 维护低电平样本计数，并在一次低脉冲结束后把实测约 244us 的样本数喂给解码入口。
; 调试: 先看 R_RFSamplePrev、R_RFLowSampleCnt；一次低电平结束后看 R_RFPulseTicks。
F_RF_Service8KHzSample:		; 函数名沿用旧名，当前按 Timer0 实测约 4.096kHz 采样 PD1
		LDA		R_RFStatus
		AND		#(D_RFLongRecv+D_RFRecvBusy)
		BNE		RF_Service8KHzSample_Active
		; 未处于接收状态时只同步输入电平，不累计高/低脉宽。
		LDA		P_IO_PortD_Data
		AND		#D_Bit1
		STA		R_RFSamplePrev
		LDA		#00H
		STA		R_RFHighSampleCnt
		STA		R_RFLowSampleCnt
		RTS

RF_Service8KHzSample_Active:
		LDA		P_IO_PortD_Data
		AND		#D_Bit1
		; PD1 为高时，如果上一拍也是高，就什么都不做；如果上一拍是低，就表示一段低脉冲结束了。
		BEQ		RF_Service8KHzSample_Low
		LDA		R_RFSamplePrev
		BEQ		RF_Service8KHzSample_LowEnd
		LDA		R_RFHighSampleCnt
		CMP		#0FEH
		BCS		RF_Service8KHzSample_HighKeep
		INC		R_RFHighSampleCnt
RF_Service8KHzSample_HighKeep:
		LDA		#D_Bit1
		STA		R_RFSamplePrev
		RTS

RF_Service8KHzSample_Low:
		LDA		R_RFSamplePrev
		BEQ		RF_Service8KHzSample_LowHold
		; 刚从高跳低，先验上一段高电平是否接近协议固定的 500us，再开始统计低电平。
		LDA		R_RFCaptureActive
		BEQ		RF_Service8KHzSample_StartLow
		LDA		R_RFHighSampleCnt
		CMP		#C_RFBitHighMinSample
		BCC		RF_Service8KHzSample_InvalidHigh
		CMP		#C_RFBitHighMaxSample+1
		BCC		RF_Service8KHzSample_StartLow
RF_Service8KHzSample_InvalidHigh:
		JSR		F_RF_ResetPacketBuffer
RF_Service8KHzSample_StartLow:
		LDA		#00H
		STA		R_RFSamplePrev
		STA		R_RFHighSampleCnt
		LDA		#01H
		STA		R_RFLowSampleCnt
		RTS

RF_Service8KHzSample_LowHold:
		LDA		R_RFLowSampleCnt
		CMP		#0FEH
		; 饱和保护，防止异常长低电平把计数溢出。
		BCS		RF_Service8KHzSample_End
		INC		R_RFLowSampleCnt
RF_Service8KHzSample_End:
		RTS

RF_Service8KHzSample_LowEnd:
		LDA		#D_Bit1
		STA		R_RFSamplePrev
		LDA		R_RFLowSampleCnt
		BEQ		RF_Service8KHzSample_End
		; Timer0 一个样本当前实测约 244us，直接按样本数判 stop/bit0/bit1。
		STA		R_RFPulseTicks
		LDA		#01H
		STA		R_RFHighSampleCnt
		LDA		R_RFPulseTicks
		JSR		F_RF_FeedLowPulseTicks
		LDA		#00H
		STA		R_RFLowSampleCnt
		RTS

; 输入: 当前帧缓存 R_RFPacket0~4 已经收满 36bit。
; 输出: 双帧确认通过后按通道和 ID 规则落库，并在成功时统一走接收成功收口。
; 调试: 先看 R_RFPacket0~4，再看 R_RFPending0~4、R_RFRequestChannel、R_RF1IdL~R_RF3IdL。
F_RF_ParsePacket:			; SEI保护下全扫描pending找匹配对
		LDA		R_RFPendingValid
		CMP		#02H
		BCS		RF_PP_Start
		RTS
RF_PP_Start:
		SEI						; 关中断，全程保护pending不被IRQ踩
		LDA		#00H
		STA		R_RFTrendCmpL	; i=0

RF_PP_iLoop:
		; 复制 pending[i] 到 Packet0-4
		LDX		R_RFTrendCmpL
		LDA		T_PendOfs,X
		TAX
		LDY		#00H
RF_PP_Copy:
		LDA		R_RFPendingBuf,X
		STA		R_RFPacket0,Y
		INX
		INY
		CPY		#05H
		BCC		RF_PP_Copy
		; j = i+1
		LDA		R_RFTrendCmpL
		CLC
		ADC		#01H
		STA		R_RFPulseTicks	; j（SEI下可借用）

RF_PP_jLoop:
		LDA		R_RFPulseTicks
		CMP		R_RFPendingValid
		BCS		RF_PP_iNext
		JSR		F_RF_CmpCurrentWithSlot	; Packet0-4 vs pending[j]
		BCS		RF_PP_Match
		INC		R_RFPulseTicks
		BNE		RF_PP_jLoop		; PulseTicks 1~3 永不=0, BNE=JMP省1字节

RF_PP_iNext:
		INC		R_RFTrendCmpL
		LDA		R_RFTrendCmpL
		CLC
		ADC		#01H
		CMP		R_RFPendingValid
		BCC		RF_PP_iLoop		; i+1 < Valid → 继续

RF_PP_NoMatch:
		CLI						; 无匹配，保留pending
		RTS

RF_PP_Match:
		JSR		F_RF_ClearPendingFrame
		; Packet1 bit5~4 是通道码：30h/00h 走 CH1，20h 走 CH2，其余按 CH3 处理。
		LDA		R_RFPacket1
		AND		#30H
		CLI						; 比对和通道码已读出，恢复中断
		CMP		#30H
		BEQ		RF_ParsePacket_CH1
		CMP		#00H
		BEQ		RF_ParsePacket_CH1
		CMP		#20H
		BEQ		RF_ParsePacket_CH2
		JMP		RF_ParsePacket_CH3

RF_ParsePacket_CH1:
		; 先把这帧归到 CH1，再做“是否允许写 CH1”的 ID/NeedPair 判断。
		LDA		#D_RFCh1
		STA		R_RFRequestChannel
		JSR		F_RF_IsRequestChannelPacketAccepted
		BCC		RF_ParsePacket_Clear
		; 验收通过才落库，并收口这次接收窗口。
		JSR		F_RF_LoadPacketToRequestChannel
		JSR		F_RF_OnReceiveOK
		JMP		RF_ParsePacket_Clear

RF_ParsePacket_CH2:
		LDA		#D_RFCh2
		STA		R_RFRequestChannel
		JSR		F_RF_IsRequestChannelPacketAccepted
		BCC		RF_ParsePacket_Clear
		JSR		F_RF_LoadPacketToRequestChannel
		JSR		F_RF_OnReceiveOK
		JMP		RF_ParsePacket_Clear

RF_ParsePacket_CH3:
		LDA		#D_RFCh3
		STA		R_RFRequestChannel
		JSR		F_RF_IsRequestChannelPacketAccepted
		BCC		RF_ParsePacket_Clear
		JSR		F_RF_LoadPacketToRequestChannel
		JSR		F_RF_OnReceiveOK

RF_ParsePacket_Clear:
		; 无论成功还是失败，都把当前帧缓存清掉，等待下一次停止位重新起帧。
		JSR		F_RF_ResetPacketBuffer

RF_ParsePacket_End:
		RTS

; 输入: X=0~7，对应当前 bit 在字节内的位置。
; 输出: A=80h >> X，供 Packet0~4 的 bit1 写入 helper 复用。
; 调试: 看 X=0 是否返回 80h，X=7 是否返回 01h。
F_RF_BuildPacketBitMask:		; 输入 X=0~7，输出 A=80h >> X，供 Packet0~4 的 bit1 写入复用
		LDA		#80H

RF_SetPacketMask:
		CPX		#00H
		BEQ		RF_SetPacketMaskDone
		LSR		A
		DEX
		JMP		RF_SetPacketMask

RF_SetPacketMaskDone:
		RTS

; 输入: X=0~7，对应当前 bit 在目标字节内的位置。
; 输出: 把 bit1 写到对应 Packet 字节的目标位上。
; 调试: X=0 表示写 bit7，X=7 表示写 bit0，所以整帧在每个字节里都是 MSB first。
F_RF_SetBitInPacket0:			; 将当前 bit 写入 Packet0 的目标位
		JSR		F_RF_BuildPacketBitMask
		ORA		R_RFPacket0
		STA		R_RFPacket0
		RTS

F_RF_SetBitInPacket1:			; 将当前 bit 写入 Packet1 的目标位
		JSR		F_RF_BuildPacketBitMask
		ORA		R_RFPacket1
		STA		R_RFPacket1
		RTS

F_RF_SetBitInPacket2:			; 将当前 bit 写入 Packet2 的目标位
		JSR		F_RF_BuildPacketBitMask
		ORA		R_RFPacket2
		STA		R_RFPacket2
		RTS

F_RF_SetBitInPacket3:			; 将当前 bit 写入 Packet3 的目标位
		JSR		F_RF_BuildPacketBitMask
		ORA		R_RFPacket3
		STA		R_RFPacket3
		RTS

F_RF_SetBitInPacket4:			; 将当前 bit 写入 Packet4 的目标位
		JSR		F_RF_BuildPacketBitMask
		ORA		R_RFPacket4
		STA		R_RFPacket4
		RTS

; 输入: 当前确认通过的 RF 包，以及 R_RFRequestChannel 指向的目标通道。
; 输出: 把 ID、温度、湿度、低电状态落到目标通道缓存，并刷新该通道趋势窗口。
; 调试: 把 R_RFPacket0~4 和 R_RF1IdL/TempH/TempL/Hum 等结果一起看，最容易对位。
F_RF_LoadPacketToRequestChannel:	; 把解析后的 ID、温度、湿度、电池状态落到当前请求通道缓存
		LDA		R_RFRequestChannel
		JSR		F_RF_LoadSelectedChannelOffsets

RF_LoadPacketToChannelCommon:
		LDA		#00H
		STA		R_RF1IdH,X
		; Packet0 = 发射器 ID 8bit。
		LDA		R_RFPacket0
		STA		R_RF1IdL,X
		; 现场实测这 12bit 温度场与真实补码按位相反，先取反再做符号扩展。
		LDA		R_RFPacket1
		AND		#0FH
		EOR		#0FH
		STA		R_RF1TempH,X
		LDA		R_RFPacket2
		EOR		#0FFH
		STA		R_RF1TempL,X
		; 修正后的温度字段仍按 12bit 补码处理，bit12 为符号位。
		LDA		R_RFPacket1
		AND		#0FH
		EOR		#0FH
		AND		#08H
		BEQ		RF_LoadPacketTempReady
		LDA		R_RF1TempH,X
		ORA		#0F0H
		STA		R_RF1TempH,X
RF_LoadPacketTempReady:
		; Packet3 低 4bit + Packet4 高 4bit 组成湿度 8bit。
		; bit24~27 当前协议忽略，bit28~35 才是湿度数据。
		LDA		R_RFPacket3
		AND		#0FH
		ASL		A
		ASL		A
		ASL		A
		ASL		A
		STA		R_RF1Hum,X
		LDA		R_RFPacket4
		LSR		A
		LSR		A
		LSR		A
		LSR		A
		ORA		R_RF1Hum,X
		; 湿度字段是反码，例: C1h 实际应还原成 3Eh(62)。
		EOR		#0FFH
		STA		R_RF1Hum,X
		LDA		R_RFPacket1
		AND		#80H
		BEQ		RF_LoadPacketBatteryNormal
		; Packet1 bit7 = 1 表示低电。
		LDA		R_RF1Flags,X
		ORA		#D_RFLowBat
		STA		R_RF1Flags,X
		JMP		RF_LoadPacketTrendUpdate
RF_LoadPacketBatteryNormal:
		LDA		R_RF1Flags,X
		AND		#(.NOT.(D_RFLowBat))
		STA		R_RF1Flags,X

RF_LoadPacketTrendUpdate:
		; 趋势缓存已移到 PAGE0，恢复每次收包后的趋势推进。
		JMP		F_RF_UpdateSelectedChannelTrend

; 输入: X=通道记录偏移(0/10/20), Y=趋势索引(0/1/2)。
; 输出: 按当前通道新样本更新温度/湿度趋势窗口和 Up/Down/Eq 状态位。
; 调试: 先看 R_RFTrendFlags,Y，再看 Max/Min/EqCnt 是否按当前样本推进。
F_RF_UpdateSelectedChannelTrend:
		LDA		R_RFTrendFlags,Y
		AND		#D_RFTrendInit
		BEQ		RF_TrendSeedCurrent
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempRefresh+D_RFTrendHumRefresh))
		STA		R_RFTrendFlags,Y
		JSR		F_RF_UpdateSelectedChannelTempTrend
		JMP		F_RF_UpdateSelectedChannelHumTrend

RF_TrendSeedCurrent:
		JSR		F_RF_SeedSelectedChannelTempTrend
		JSR		F_RF_SeedSelectedChannelHumTrend
		LDA		#C_RFTrendEq60Samples
		STA		R_RFTrendTempEqCnt,Y
		STA		R_RFTrendHumEqCnt,Y
		LDA		#(D_RFTrendInit+D_RFTrendTempRefresh+D_RFTrendHumRefresh)
		STA		R_RFTrendFlags,Y
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: 用当前通道温度重置趋势温度窗口和等值计数。
; 调试: 看 R_RFTrendTempMax*/Min*/EqCnt 是否被当前样本覆盖。
F_RF_SeedSelectedChannelTempTrend:
		LDA		R_RF1TempH,X
		STA		R_RFTrendTempMaxH,Y
		STA		R_RFTrendTempMinH,Y
		LDA		R_RF1TempL,X
		STA		R_RFTrendTempMaxL,Y
		STA		R_RFTrendTempMinL,Y
		LDA		#00H
		STA		R_RFTrendTempEqCnt,Y
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: 用当前通道湿度重置趋势湿度窗口和等值计数。
; 调试: 看 R_RFTrendHumMax/Min/EqCnt 是否被当前样本覆盖。
F_RF_SeedSelectedChannelHumTrend:
		LDA		R_RF1Hum,X
		STA		R_RFTrendHumMax,Y
		STA		R_RFTrendHumMin,Y
		LDA		#00H
		STA		R_RFTrendHumEqCnt,Y
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: 按当前室外温度样本更新趋势窗口，并在跨阈值时切换 Up/Down/Eq 状态位。
; 调试: 看 R_RFTrendFlags,Y 与 TempMax/TempMin/EqCnt 的联动是否正确。
F_RF_UpdateSelectedChannelTempTrend:
		JSR		F_RF_IsCurrentTrendTempGreaterThanMax
		BCC		RF_TrendTempCheckMin
		LDA		R_RF1TempH,X
		STA		R_RFTrendTempMaxH,Y
		LDA		R_RF1TempL,X
		STA		R_RFTrendTempMaxL,Y
		JSR		F_RF_IsTrendTempSpanOverThreshold
		BCC		RF_TrendTempAdvanceEq
		JSR		F_RF_SeedSelectedChannelTempTrend
		LDA		R_RFTrendFlags,Y
		AND		#(D_RFTrendTempUp+D_RFTrendTempDown)
		CMP		#D_RFTrendTempUp
		BEQ		RF_TrendTempSetUpNoRefresh
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempDown))
		ORA		#(D_RFTrendTempUp+D_RFTrendTempRefresh)
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendTempSetUpNoRefresh:
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempDown))
		ORA		#D_RFTrendTempUp
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendTempCheckMin:
		JSR		F_RF_IsCurrentTrendTempLessThanMin
		BCC		RF_TrendTempAdvanceEq
		LDA		R_RF1TempH,X
		STA		R_RFTrendTempMinH,Y
		LDA		R_RF1TempL,X
		STA		R_RFTrendTempMinL,Y
		JSR		F_RF_IsTrendTempSpanOverThreshold
		BCC		RF_TrendTempAdvanceEq
		JSR		F_RF_SeedSelectedChannelTempTrend
		LDA		R_RFTrendFlags,Y
		AND		#(D_RFTrendTempUp+D_RFTrendTempDown)
		CMP		#D_RFTrendTempDown
		BEQ		RF_TrendTempSetDownNoRefresh
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempUp))
		ORA		#(D_RFTrendTempDown+D_RFTrendTempRefresh)
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendTempSetDownNoRefresh:
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempUp))
		ORA		#D_RFTrendTempDown
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendTempAdvanceEq:
		LDA		R_RFTrendTempEqCnt,Y
		CMP		#C_RFTrendEq60Samples
		BCS		RF_TrendTempExit
		CLC
		ADC		#01H
		STA		R_RFTrendTempEqCnt,Y
		LDA		R_RFTrendTempEqCnt,Y
		CMP		#C_RFTrendEq60Samples
		BNE		RF_TrendTempExit
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendTempUp+D_RFTrendTempDown))
		ORA		#D_RFTrendTempRefresh
		STA		R_RFTrendFlags,Y
RF_TrendTempExit:
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: 按当前室外湿度样本更新趋势窗口，并在跨阈值时切换 Up/Down/Eq 状态位。
; 调试: 看 R_RFTrendFlags,Y 与 HumMax/HumMin/EqCnt 的联动是否正确。
F_RF_UpdateSelectedChannelHumTrend:
		LDA		R_RF1Hum,X
		CMP		R_RFTrendHumMax,Y
		BCC		RF_TrendHumCheckMin
		BEQ		RF_TrendHumCheckMin
		STA		R_RFTrendHumMax,Y
		JSR		F_RF_IsTrendHumSpanOverThreshold
		BCC		RF_TrendHumAdvanceEq
		JSR		F_RF_SeedSelectedChannelHumTrend
		LDA		R_RFTrendFlags,Y
		AND		#(D_RFTrendHumUp+D_RFTrendHumDown)
		CMP		#D_RFTrendHumUp
		BEQ		RF_TrendHumSetUpNoRefresh
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendHumDown))
		ORA		#(D_RFTrendHumUp+D_RFTrendHumRefresh)
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendHumSetUpNoRefresh:
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendHumDown))
		ORA		#D_RFTrendHumUp
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendHumCheckMin:
		LDA		R_RF1Hum,X
		CMP		R_RFTrendHumMin,Y
		BCS		RF_TrendHumAdvanceEq
		STA		R_RFTrendHumMin,Y
		JSR		F_RF_IsTrendHumSpanOverThreshold
		BCC		RF_TrendHumAdvanceEq
		JSR		F_RF_SeedSelectedChannelHumTrend
		LDA		R_RFTrendFlags,Y
		AND		#(D_RFTrendHumUp+D_RFTrendHumDown)
		CMP		#D_RFTrendHumDown
		BEQ		RF_TrendHumSetDownNoRefresh
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendHumUp))
		ORA		#(D_RFTrendHumDown+D_RFTrendHumRefresh)
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendHumSetDownNoRefresh:
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendHumUp))
		ORA		#D_RFTrendHumDown
		STA		R_RFTrendFlags,Y
		RTS

RF_TrendHumAdvanceEq:
		LDA		R_RFTrendHumEqCnt,Y
		CMP		#C_RFTrendEq60Samples
		BCS		RF_TrendHumExit
		CLC
		ADC		#01H
		STA		R_RFTrendHumEqCnt,Y
		LDA		R_RFTrendHumEqCnt,Y
		CMP		#C_RFTrendEq60Samples
		BNE		RF_TrendHumExit
		LDA		R_RFTrendFlags,Y
		AND		#(.NOT.(D_RFTrendHumUp+D_RFTrendHumDown))
		ORA		#D_RFTrendHumRefresh
		STA		R_RFTrendFlags,Y
RF_TrendHumExit:
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: SEC=当前温度大于趋势窗口最大值，CLC=否则。
; 调试: 重点看当前样本和 R_RFTrendTempMaxH/L,Y 的符号与大小比较。
F_RF_IsCurrentTrendTempGreaterThanMax:
		LDA		R_RF1TempH,X
		AND		#80H
		BEQ		RF_TrendTempGtMax_CurrentPos
		LDA		R_RFTrendTempMaxH,Y
		AND		#80H
		BEQ		RF_TrendTempGtMax_False
		LDA		R_RF1TempH,X
		CMP		R_RFTrendTempMaxH,Y
		BCC		RF_TrendTempGtMax_True
		BNE		RF_TrendTempGtMax_False
		LDA		R_RF1TempL,X
		CMP		R_RFTrendTempMaxL,Y
		BCC		RF_TrendTempGtMax_True
		JMP		RF_TrendTempGtMax_False

RF_TrendTempGtMax_CurrentPos:
		LDA		R_RFTrendTempMaxH,Y
		AND		#80H
		BNE		RF_TrendTempGtMax_True
		LDA		R_RF1TempH,X
		AND		#7FH
		CMP		R_RFTrendTempMaxH,Y
		BCC		RF_TrendTempGtMax_False
		BNE		RF_TrendTempGtMax_True
		LDA		R_RF1TempL,X
		CMP		R_RFTrendTempMaxL,Y
		BCC		RF_TrendTempGtMax_False
		BEQ		RF_TrendTempGtMax_False

RF_TrendTempGtMax_True:
		SEC
		RTS

RF_TrendTempGtMax_False:
		CLC
		RTS

; 输入: X=通道记录偏移，Y=趋势索引。
; 输出: SEC=当前温度小于趋势窗口最小值，CLC=否则。
; 调试: 重点看当前样本和 R_RFTrendTempMinH/L,Y 的符号与大小比较。
F_RF_IsCurrentTrendTempLessThanMin:
		LDA		R_RF1TempH,X
		AND		#80H
		BEQ		RF_TrendTempLtMin_CurrentPos
		LDA		R_RFTrendTempMinH,Y
		AND		#80H
		BEQ		RF_TrendTempLtMin_True
		LDA		R_RF1TempH,X
		CMP		R_RFTrendTempMinH,Y
		BCC		RF_TrendTempLtMin_False
		BNE		RF_TrendTempLtMin_True
		LDA		R_RF1TempL,X
		CMP		R_RFTrendTempMinL,Y
		BCC		RF_TrendTempLtMin_False
		BEQ		RF_TrendTempLtMin_False
		JMP		RF_TrendTempLtMin_True

RF_TrendTempLtMin_CurrentPos:
		LDA		R_RFTrendTempMinH,Y
		AND		#80H
		BNE		RF_TrendTempLtMin_False
		LDA		R_RF1TempH,X
		AND		#7FH
		CMP		R_RFTrendTempMinH,Y
		BCC		RF_TrendTempLtMin_True
		BNE		RF_TrendTempLtMin_False
		LDA		R_RF1TempL,X
		CMP		R_RFTrendTempMinL,Y
		BCC		RF_TrendTempLtMin_True

RF_TrendTempLtMin_False:
		CLC
		RTS

RF_TrendTempLtMin_True:
		SEC
		RTS

; 输入: Y=趋势索引，对应温度窗口最大/最小值。
; 输出: SEC=温度趋势窗口跨度已经大于 1.0C，CLC=否则。
; 调试: 看 Max/Min 同号和跨零两条路径下的差值是否都正确。
F_RF_IsTrendTempSpanOverThreshold:
		LDA		R_RFTrendTempMaxH,Y
		AND		#80H
		BEQ		RF_TrendTempSpan_MaxPositive
		SEC
		LDA		R_RFTrendTempMinL,Y
		SBC		R_RFTrendTempMaxL,Y
		STA		R_RFTrendCmpL
		LDA		R_RFTrendTempMinH,Y
		SBC		R_RFTrendTempMaxH,Y
		BCC		RF_TrendTempSpan_False
		BNE		RF_TrendTempSpan_True
		LDA		R_RFTrendCmpL
		CMP		#C_RFTrendTempOver1C
		BCC		RF_TrendTempSpan_False
		JMP		RF_TrendTempSpan_True

RF_TrendTempSpan_MaxPositive:
		LDA		R_RFTrendTempMinH,Y
		AND		#80H
		BNE		RF_TrendTempSpan_CrossZero
		SEC
		LDA		R_RFTrendTempMaxL,Y
		SBC		R_RFTrendTempMinL,Y
		STA		R_RFTrendCmpL
		LDA		R_RFTrendTempMaxH,Y
		SBC		R_RFTrendTempMinH,Y
		BCC		RF_TrendTempSpan_False
		BNE		RF_TrendTempSpan_True
		LDA		R_RFTrendCmpL
		CMP		#C_RFTrendTempOver1C
		BCC		RF_TrendTempSpan_False
		JMP		RF_TrendTempSpan_True

RF_TrendTempSpan_CrossZero:
		CLC
		LDA		R_RFTrendTempMaxL,Y
		ADC		R_RFTrendTempMinL,Y
		STA		R_RFTrendCmpL
		LDA		R_RFTrendTempMinH,Y
		AND		#7FH
		ADC		R_RFTrendTempMaxH,Y
		BNE		RF_TrendTempSpan_True
		LDA		R_RFTrendCmpL
		CMP		#C_RFTrendTempOver1C
		BCC		RF_TrendTempSpan_False

RF_TrendTempSpan_True:
		SEC
		RTS

RF_TrendTempSpan_False:
		CLC
		RTS

; 输入: Y=趋势索引，对应湿度窗口最大/最小值。
; 输出: SEC=湿度趋势窗口跨度已经大于 5%RH，CLC=否则。
; 调试: 看 R_RFTrendHumMax/Min,Y 的差值是否跨过阈值。
F_RF_IsTrendHumSpanOverThreshold:
		SEC
		LDA		R_RFTrendHumMax,Y
		SBC		R_RFTrendHumMin,Y
		CMP		#C_RFTrendHumOver5
		BCC		RF_TrendHumSpan_False
		SEC
		RTS

RF_TrendHumSpan_False:
		CLC
		RTS
