;==========================================
; Compiler parameter define
;==========================================
;==========================================
.SYNTAX 6502 ; SYNTAX指定汇编器的语法格式
.LINKLIST
.SYMBOLS

;==========================================
; Constant define area
;==========================================

;==========================================
; Include file area
;==========================================

.INCLUDE		GPL813x.inc
.INCLUDE		SYS\Macro.inc
.INCLUDE		Alarm\Alarm.inc
.INCLUDE		RTC\RTC.inc
.INCLUDE		GXHTV4\GXHTV4.inc
.INCLUDE		LCD\LCD_Display.inc
.INCLUDE		KEY\KEY.inc
.INCLUDE		I2C\D_I2C.inc
.INCLUDE		RF\RF.inc

;==========================================
; Include file area
;==========================================




;==========================================
; External declare area
;==========================================
.PUBLIC	R_2Hz 
.PUBLIC	R_128Hz
.PUBLIC	R_INTFlag
.PUBLIC F_2HzWakeUp
.PUBLIC Wait1_2Sec

;==========================================
; Public declare area
;==========================================
.PUBLIC	L_PowerOn
.PUBLIC V_RESET
;.PUBLIC		IOD_Attmap	
;.PUBLIC		IOD_Dirmap	
;.PUBLIC		IOD_Datmap
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0 ; PAGE指定列在一页上的最大列数和一行上最大的字符数
R_2Hz		ds	1
R_128Hz		ds	1
R_INTFlag	ds	1

;IOD_Attmap	ds	1
;IOD_Dirmap	ds	1
;IOD_Datmap	ds	1
;==========================================
; code starting 
;==========================================
.CODE
V_RESET:
; User_Code_Start:
; Code_Start:
		SEI					; 置中断禁止位
		LDX		#FFH		;
		TXS					;x-->栈指针

		LDA		P_WAKEUP_Ctrl	;唤醒源代码控制寄存器
		TAX
		AND		#(D_WakeupKey+D_WakeupTMBA);+D_Wakeup128Hz) ;WakeupKey+TimeBaseA wake up(1/2hz)---------开启128Hz唤醒
		BEQ		L_PowerOn        ;No Wakeup     
		
        LDA		#00
		STA		P_WAKEUP_Ctrl    ;clear wakeup flag
			
		LDA		#0x20
		STA		P_CLK_CPU_Ctrl		; //after sleep mode wake up, sys=4M CPU=4M/1;			

		TXA
		AND		#D_WakeupTMBA  
;   	BNE		F_2HzWakeUp
		BEQ		F_keyWakeup    ;Judge Wakeup
		JMP		F_2HzWakeUp
;		TXA		
;		AND		#D_Wakeup128Hz
;		BNE		F_128HzWakeUp
;		

; 输入: 按键唤醒事件。
; 输出: 退出低功耗并返回主服务循环。
; 调试: 看按键唤醒后是否直接回到 L_ServiceLoop。
F_keyWakeup:
;       LDA		#D_TBL_Clr
;		STA		P_INT_Clear1   
		CLI
		nop
		JMP		L_ServiceLoop
		
; 输入: 2Hz 半秒唤醒事件。
; 输出: 推进键值/RTC/RF/低电/室内采样等半秒业务后返回主循环。
; 调试: 看 R_2Hz 清零后，各半秒服务函数是否按预期被依次调用。
F_2HzWakeUp:                           ;半秒 0.5s	  
  		LDA		#00
  		STA		R_2Hz
  		LDA		#D_TMBAInt
		STA		P_INT_TimeBaseA_Clear
  		JSR		F_2Hz_Cnt
	    JSR		F_RealTimeClock   ;rtc		
	    JSR		F_RF_ServiceHalfSec	; RF 同步窗口与双帧确认按 0.5 秒调度
	    JSR		F_CheckLowBattery	; 规格要求显示本机低电图标，检测逻辑接回半秒节拍
	    JSR	    F_JudgeRFC		;温湿度检测	    	
	    JMP		L_ServiceLoop	
	    
; 输入: 128Hz 唤醒事件。
; 输出: 清掉 128Hz 标志后返回主循环。
; 调试: 看 R_128Hz 是否被及时清零，避免重复进入该路径。
F_128HzWakeUp:
		LDA		#00
		STA		R_128Hz
;		JSR		F_128Hz_Cnt
		JMP		L_ServiceLoop
		
; 输入: 上电复位后的芯片初始状态。
; 输出: 完成系统/IO/LCD/RTC 初始化，跑满全显与背光时序后进入主服务循环。
; 调试: 看全显 3 秒、最后 1 秒背光、BI、RF 长接收启动是否按顺序发生。
L_PowerOn:  ;---------------------;POWER UP	开机		
		%InitSystem
		
		;CPU时钟选择
		LDA		#0x44					;0100 0100
		STA		P_CLK_CPU_Ctrl ;		; Set Fcpu = (500KHz) / 16
		nop
		LDA		#0x24					;0010 0100
		STA		P_CLK_CPU_Ctrl;			; Set Fcpu = (4MHz) / 16
		nop
		LDA		#0x20					;0010 0000
		STA		P_CLK_CPU_Ctrl		; //sys=4M cpu=4M/1;

		%ClrSRAM
		%InitLCD
		%F_InitINT	
		%F_Initinal_IO	
		JSR		F_ResetRealTimeClock	
		%bits	R_TimeStatus,AddOthers
		LDA		#D_LVD_27		; 上电/唤醒后统一把低电检测门槛拉到 2.4V
		STA		P_LVD_Ctrl
		
		%FillLcdDpram #FFH
		CLI		
		; 上电后先尝试读取一次温湿度（此时传感器可能未就绪）
		; 若数据全为0则置 D_FirstReadRetry 标志，后续在全显计时和主循环中重试
		JSR		F_UpdateTHFromGXHTV4
		LDA		R_SaveData+0
		ORA		R_SaveData+1
		ORA		R_SaveData+3
		ORA		R_SaveData+4		
		BNE		L_PowerOn_ReadOk
		LDA		R_TempFlag
		ORA		#D_FirstReadRetry
		STA		R_TempFlag
L_PowerOn_ReadOk:

	Wait1_2Sec:
		%WatchDogClear
		JSR		F_RetryFirstTHRead
		LDA		R_2Hz
		CMP		#04H
		BCC		Wait1_2Sec
;		LDA		R_BLTime
;		BNE		Wait1_2Sec_CheckEnd
		; 先全显 2 秒，最后 1 秒再点亮背光，对齐新的上电时序要求。
		JSR		F_backlightOpen
		LDA		#01H
		STA		R_BLTime
	Wait1_2Sec_CheckEnd:
		%WatchDogClear
		JSR		F_RetryFirstTHRead
		LDA		R_2Hz
		CMP		#06H		
		BCC		Wait1_2Sec_CheckEnd
;		LDA		R_BLTime
;		BEQ		Jump_DispAll
		; 上电等待环不会跑正常背光倒计时，所以 1 秒到点后手动关灯。
		LDA		#00H
		STA		R_BLTime
		STA		R_LEDFlag
		STA		R_LEDTemp
		LDA		P_IO_PortB_Data
		AND		#.not.D_Bit0
		STA		P_IO_PortB_Data
		JSR		F_CheckTempMode
	Jump_DispAll:
		%FillLcdDpram #00H 
		JSR		F_initSet
		JSR		F_RF_Init
		JSR		F_RF_StartLongReceive
		%bits	R_KeyFlag,D_KeyTone	
		JSR		F_PlayKeyTone



;================================================
L_ServiceLoop:
		%WatchDogClear
		JSR		F_KeyScan		;按键扫描
		JSR		F_PlayKeyTone	;按键音
		JSR		F_RetryFirstTHRead
		JSR		F_RF_ServicePendingParse
		JSR		F_Display
		
	?L_NoDispNormal:
		LDA		R_2Hz		;2Hz唤醒
		BEQ		$+5
		JMP		F_2HzWakeUp
		LDA		R_KeyValue		;按键
		BNE		L_ServiceLoop
		LDA		R_KeyTemp
		BNE		L_ServiceLoop
							
		LDA		R_128Hz
		BEQ		$+5
		JMP		F_128HzWakeUp
		

	?Next_CheckSleepGate:
		%btst	R_LEDFlag,D_LED_ON,L_ServiceLoop	
		%btst	R_KeyFlag,D_ToneOn,L_ServiceLoop		

		LDA		R_SoundOn
		BNE		L_ServiceLoop
		; RF 正在长接收或开着当前收包窗口时不能睡眠，
		; 否则 PD1 上的边沿还没收完，主循环就已经跳进低功耗入口。
		LDA		R_RFStatus
		AND		#(D_RFLongRecv+D_RFRecvBusy)
		BNE		L_ServiceLoop
	
	L_Enter_Sleep2Hz:
		LDA		#0x21
		STA		P_CLK_CPU_Ctrl		; //before enter sleep mode, sys=4M CPU=4M/2;	

		LDA		P_IO_PortE_DataLatch		
		LDA		#00h
		STA		P_WAKEUP_Ctrl	;clear wakeup flag
			
		LDA		#D_WakeupTMBA+D_WakeupKey	;+D_Wakeup128Hz
		STA		P_WAKEUP_Ctrl
		STA		P_SYSTEM_Ctrl
		NOP
		NOP
		JMP		V_RESET	
		
;-------------------------------------------------------
; 函数: F_CheckTempMode
; 作用: 检测PD6电平，高→摄氏度模式，低→华氏度模式。
;       若PD6为高，将其改为输出高电平以锁定模式。
;-------------------------------------------------------
.PUBLIC		F_CheckTempMode
F_CheckTempMode:
		LDA		P_IO_PortD_Data		; 读取PD口数据
		AND		#D_Bit6				; 测试PD6
		BEQ		?SetFahrenheit		; PD6=0 → 华氏度
		; PD6=1 → 摄氏度
		LDA		R_SpecFlag
		AND		#.NOT.D_TF		; 清D_TempF位
		STA		R_SpecFlag
		; PD6改为输出高（方向寄存器只写，通过影子寄存器读-改-写）
		LDA		P_IOD_DIR_Map
		ORA		#D_Bit6
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#D_Bit6
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
		RTS
?SetFahrenheit:
		; PD6=0 → 华氏度
		LDA		R_SpecFlag
		ORA		#D_TF			; 置D_TempF位
		STA		R_SpecFlag
		RTS

.END

		