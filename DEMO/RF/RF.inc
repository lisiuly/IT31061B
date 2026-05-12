;===================================================
;            RAM Define
;====================================================
.EXTERN		R_RFStatus
D_RFLongRecv		equ	01h
D_RFCycleMode		equ	02h
D_RFNeedSync		equ	04h
D_RFRecvBusy		equ	08h

.EXTERN		R_RFChannel
D_RFCh1			equ	01h
D_RFCh2			equ	02h
D_RFCh3			equ	03h
D_RFAutoMode		equ	04h

.EXTERN		R_RFViewChannel
.EXTERN		R_RFRequestChannel

.EXTERN		R_RFLongRecvTm
C_RFLongRecv3Min		equ	180

.EXTERN		R_RFAutoSwitchTm
C_RFAutoSwitch4Sec		equ	4

.EXTERN		R_RFRecvWindowTm
C_RFRecvWindow2SecTick	equ	4		; 最新协议已改回提前 2 秒开接收，窗口总长 2 秒。
; C_RFRecvWindow3Sec		equ	6		; 旧一版规格写过 3 秒总窗口，现已不用，保留注释。

.EXTERN		R_RF1SyncTm
.EXTERN		R_RF2SyncTm
.EXTERN		R_RF3SyncTm
C_RFSyncIdle			equ	0FFH
C_RFCh1Sync57Sec		equ	57
C_RFCh2Sync67Sec		equ	67
; C_RFCh3Sync69Sec		equ	69		; 旧值，与协议/规格冲突。
C_RFCh3Sync79Sec		equ	79

; RF发码协议位宽:
; Bit0 = 高500us + 低2000us
; Bit1 = 高500us + 低1000us
C_RFBitHigh500us		equ	500
C_RFBit0Low2000us		equ	2000
C_RFBit1Low1000us		equ	1000
C_RFPacketBits36		equ	36

; RF收码低脉宽按 50us tick 喂入:
; 1ms = 20 tick, 2ms = 40 tick, 停止位 4~5ms = 80~100 tick
C_RFBit1LowMinTick		equ	16
C_RFBit1LowMaxTick		equ	24
C_RFBit0LowMinTick		equ	36
C_RFBit0LowMaxTick		equ	44
C_RFStopLowMinTick		equ	80
C_RFStopLowMaxTick		equ	100

.EXTERN		R_RFBitCnt
.EXTERN		R_RFPacket0
.EXTERN		R_RFPacket1
.EXTERN		R_RFPacket2
.EXTERN		R_RFPacket3
.EXTERN		R_RFPacket4
.EXTERN		R_RFPacket5

.EXTERN		R_RF1Flags
.EXTERN		R_RF1IdH
.EXTERN		R_RF1IdL
.EXTERN		R_RF1TempH
.EXTERN		R_RF1TempL
.EXTERN		R_RF1Hum
.EXTERN		R_RF1LostCnt
.EXTERN		R_RF1RetryStage

.EXTERN		R_RF2Flags
.EXTERN		R_RF2IdH
.EXTERN		R_RF2IdL
.EXTERN		R_RF2TempH
.EXTERN		R_RF2TempL
.EXTERN		R_RF2Hum
.EXTERN		R_RF2LostCnt
.EXTERN		R_RF2RetryStage

.EXTERN		R_RF3Flags
.EXTERN		R_RF3IdH
.EXTERN		R_RF3IdL
.EXTERN		R_RF3TempH
.EXTERN		R_RF3TempL
.EXTERN		R_RF3Hum
.EXTERN		R_RF3LostCnt
.EXTERN		R_RF3RetryStage

D_RFValid		equ	01h
D_RFLowBat		equ	02h
D_RFLost			equ	04h
D_RFNeedPair		equ	08h
C_RFFail3Times		equ	3

; 室外趋势状态位与 Alarm 的 D_Trend* 布局保持一致，
; 这样 LCD 层可以按同样的 Up/Down/Eq 判定去显示室外趋势图标。
.EXTERN		R_RFTrendFlags
D_RFTrendInit		equ	01h
D_RFTrendTempUp		equ	02h
D_RFTrendTempDown	equ	04h
D_RFTrendTempRefresh	equ	08h
D_RFTrendHumUp		equ	10h
D_RFTrendHumDown	equ	20h
D_RFTrendHumRefresh	equ	40h

;===================================================
;            Module Define
;====================================================
.EXTERN		F_RF_Init
.EXTERN		F_RF_SelectNextChannel
.EXTERN		F_RF_ClearCurrentChannel
.EXTERN		F_RF_StartLongReceive
.EXTERN		F_RF_StopLongReceive
.EXTERN		F_RF_ServiceHalfSec
.EXTERN		F_RF_Service1Sec
.EXTERN		F_RF_OnReceiveOK
.EXTERN		F_RF_OnReceiveFail
.EXTERN		F_RF_ResetPacketBuffer
.EXTERN		F_RF_AppendBit0
.EXTERN		F_RF_AppendBit1
.EXTERN		F_RF_FeedLowPulseTicks
.EXTERN		F_RF_Service2KHzSample
.EXTERN		F_RF_ParsePacket
