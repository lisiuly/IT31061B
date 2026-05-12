;==================================================================================
; The information contained herein is the exclusive property of
; Generalplus Technology Co. And shall not be distributed, reproduced,
; or disclosed in whole in part without prior written permission.
;       (C) COPYRIGHT 2017   Generalplus TECHNOLOGY CO.                            
;                   ALL RIGHTS RESERVED
; The entire notice above must be reproduced on all authorized copies.
;==================================================================================
;==================================================================================
; Name                  : INT_VEC.asm
; Applied Body          : GPL813X
; Programmer            : 
; Description           : Interrupt vector declare and service routine
; History version       : 
;==================================================================================

;==========================================
; Compiler parameter define
;==========================================
.SYNTAX 6502
.LINKLIST
.SYMBOLS

;==========================================
; Constant define area
;==========================================



;==========================================
; Include file area
;==========================================
.INCLUDE		GPL813x.inc
.INCLUDE		SYS\Project.inc
.INCLUDE		SYS\Macro.inc
.INCLUDE		KEY\KEY.inc
.INCLUDE		LCD\LCD_Display.inc
.INCLUDE		ALARM\ALARM.inc

;==========================================
; External declare area
;==========================================
.EXTERN		F_RF_Service2KHzSample

;==========================================
; Public declare area
;==========================================


.EXTERNAL V_RESET
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0



;==========================================
; code starting 
;==========================================
.CODE


;==========================================
; IRQ INTERRUPT SERVICE ROUTINE
;==========================================
V_IRQ:
    %PushAll				;保存所有寄存器的值到堆栈中
    LDA		P_INT_Ctrl		
	STA		R_INTFlag
	
?L_TMBaseB_INT:
	LDA		R_INTFlag
	AND		#D_TMBBInt
	BEQ		?L_128HZ_INT
	STA		P_INT_TimeBaseB_Clear	;如果不是定时器B中断，则跳转到下一步处理
	JSR		INT_PlayPWM
	 ; 如果声音开启，则执行声音处理
    LDA     R_SoundOn
    BNE     ?On    ; 如果声音开启，则跳转到?On处理
    LDA     R_KeyFlag
    AND     #D_ToneOn
    BEQ     ?DisTone   ; 如果声音关闭，则跳转到?DisTone处理
;---------------------------------	
	?On:							;蜂鸣器PB1
	LDA		P_IO_PortB_Data
	EOR		#D_Bit1
	STA		P_IO_PortB_Data
;	STA		R_PortD_Data_Buf
	JMP		?L_128HZ_INT
;--------------------------------
?DisTone:
	LDA		P_IO_PortB_Data
	AND		#.not.D_Bit1
;	STA		R_PortD_Data_Buf
	STA		P_IO_PortB_Data

?L_2KHz_INT:
		LDA		R_INTFlag
		AND		#D_2KHzInt
		BEQ		?L_128HZ_INT
		STA		P_INT_2KHz_Clear
		JSR		F_RF_Service2KHzSample

?L_128HZ_INT:	; 检查是否为128Hz定时器中断
		LDA		R_INTFlag
		AND		#D_128HzInt
		BEQ		?L_2hz_INT	; 如果不是128Hz定时器中断，则跳转到?L_2hz_INT处理
		STA		P_INT_128Hz_Clear	; 如果是128Hz定时器中断，则清除中断标志，并执行相应处理
		
		INC		R_128Hz		
		
		; 检查按键消抖计数器是否为零，如果不为零则递减
		LDA		R_DebounceCnt
		BEQ		?L_FastAdd
		DEC		R_DebounceCnt
	
	?L_FastAdd: ; 长按倒计时改由 2Hz 路径处理
		; 86428 规格未定义 Mold 报警，128Hz 中断不再驱动这条非规格逻辑。
	
	?Check_ToneTime:; 检查按键音时间是否为零，如果不为零则递减
		LDA	R_KeyToneTm
		beq	?L_2hz_INT
		DEC	R_KeyToneTm
		BNE	?L_2hz_INT

		LDA	R_KeyFlag
		AND	#(.not.(D_KeyTone+D_ToneOn))
		STA	R_KeyFlag
		
;	?Check_Pulse:
;		LDA		R_Pulse
;		BEQ		?L_2hz_INT
;		DEC		R_Pulse
;		BNE		?L_2hz_INT
;		JSR		F_PulseHigh
;		%bitr	R_KeyFlag,D_Alarming

;		
;		LDA	R_DebounceCntHall
;		BEQ	?Check_LongTimeHall
;		DEC	R_DebounceCntHall
;		
;			
;	?Check_LongTimeHall:
;		LDA	R_LongKeyTimeHall
;		BEQ	?Check_SWTimeHall
;		DEC	R_LongKeyTimeHall
;		
;	?Check_SWTimeHall:
		
		
		
?L_2hz_INT:; 检查是否为2Hz定时器中断
	LDA		R_INTFlag
	AND		#D_TMBAInt
	BEQ		?L_Exit_IRQ		; 如果不是2Hz定时器中断，则退出中断处理
	STA		P_INT_TimeBaseA_Clear
	INC		R_2Hz

;  	LDA		R_PlaySeconds
;    BEQ		?L_Exit_IRQ       ; 时间为0则跳转停止
;    DEC		R_PlaySeconds   ; 剩余秒数减0.5
;
;	LDA		R_LongKeyTime_1
;	BEQ		?L_Exit_IRQ
;	DEC		R_LongKeyTime_1
?L_Exit_IRQ:
    %PopAll   ; 恢复所有寄存器的值
    RTI       ; 返回中断处理结束
    
	
    
;==========================================
; Vector declare
;==========================================
VECTOR: .SECTION
    DW  V_RESET             ; Reset vector		复位向量
    DW  V_IRQ               ; interrupt vector	中断向量
        .ENDS

.END

