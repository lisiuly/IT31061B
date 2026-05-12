	.IFDEF		GPL813_SERIES

;---------------------------------
GPL813P01Cx		.EQU		1
;---------------------------------

.IFNDEF GPL813X_Body_inc
GPL813X_Body_inc:   .EQU    1
;==================================================================================
; The information contained herein is the exclusive property of
; Generalplus Technology Co. And shall not be distributed, reproduced,
; or disclosed in whole in part without prior written permission.
;       (C) COPYRIGHT 2017   Generalplus TECHNOLOGY CO.                            
;                   ALL RIGHTS RESERVED
; The entire notice above must be reproduced on all authorized copies.
;==================================================================================
;==================================================================================
; Program Name: GPL813 series register declare
; Applied body: GPL813 series
; Programmer  : KenLiu
; Description : 
;             : 
; History version
; Rev #       Date          Who            Comments
; -------  -----------    --------         ----------------------------------------
;==================================================================================
;==================================================================================

		.IFNDEF	GPL813P01Ax
		GPL813P01Ax: 	.EQU		0
		.ENDIF
		.IFNDEF	GPL813P01Bx
		GPL813P01Bx: 	.EQU		0
		.ENDIF
		.IFNDEF	GPL813P01Cx
		GPL813P01Cx: 	.EQU		0
		.ENDIF
 	 
.IF (GPL813P01Ax)
GPL813X		.EQU		1
.ENDIF
.IF (GPL813P01Bx)
GPL813X		.EQU		1
.ENDIF
.IF (GPL813P01Cx)
GPL813X		.EQU		1
.ENDIF
			.IFDEF	GPL813X
		.PAGE0
      
;===================  IO Register  ===================
P_IO_PortA_Dir:     		.EQU	$00
P_IO_PortA_Data:			.EQU	$02
		
P_IO_PortB_Dir:				.EQU	$10
P_IO_PortB_Data:			.EQU	$12	
P_IO_PortB_Attrib:			.EQU	$14

P_IO_PortC_Dir:     		.EQU	$01
P_IO_PortC_Data:			.EQU	$05
P_IO_PortE_Data:     		.EQU	$03
P_IO_PortE_DataLatch:		.EQU	$04

P_IO_Ctrl:    			    .EQU	$06
P_IO_PortE_Dir:				.EQU	$0B
P_IO_PortD_Attrib			.EQU	$15
P_IO_PortD_Dir				.EQU	$11
P_IO_PortD_Data				.EQU	$13

;==============  Sleep/Wakeup Register  ==============
P_WAKEUP_Ctrl:			    .EQU	$08
 D_WakeupTimer1:				.EQU	00100000B
 D_WakeupTimer0:				.EQU	00010000B
 D_WakeupTMBB:					.EQU	00001000B
 D_Wakeup128Hz:					.EQU	00000100B
 D_WakeupTMBA:					.EQU	00000010B
 D_WakeupKey:					.EQU	00000001B
 
P_SYSTEM_Ctrl:			    .EQU	$09

;=================  Timer Register  ==================
P_TIMER_TimeBase_Sel:		.EQU	$0A
P_TIMER_Timer0_Ctrl:		.EQU	$22
 D_TimerEn:						.EQU	10000000B
 D_TimerRiseEdge:				.EQU	00000000B
 D_TimerFallEdge:				.EQU	01000000B
 D_TimerSrcExtA:				.EQU	00000000B
 D_TimerSrcExtA2:				.EQU	00100000B
 D_TimerSrcA_HF:				.EQU	00000000B
 D_TimerSrcA_HFDIV:				.EQU	00000001B
 D_TimerSrcA_EXT:				.EQU	00000010B
 D_TimerSrcA_VDD:				.EQU	00000011B
 D_TimerSrcB_LF:				.EQU	00000000B
 D_TimerSrcB_TMX:				.EQU	00000100B
 D_TimerSrcB_EXTA:				.EQU	00001000B
 D_TimerSrcB_VDD:				.EQU	00001100B
P_TIMER_TM0Data_LB:			.EQU	$20
P_TIMER_TM0Data_HB:			.EQU	$21
P_TIMER_TM0Load_Ctrl:		.EQU	$23

P_TIMER_TM1Data:			.EQU	$25
P_TIMER_Timer1_Ctrl:		.EQU	$26
 D_Timer1En:					.EQU	10000000B
 D_Timer1_LSCK:					.EQU	00000000B
 D_Timer1_TMBB:					.EQU	00000001B 
 D_Timer1_HSCK:					.EQU	00000010B 
 D_Timer1_HFDIV:				.EQU	00000011B
P_TIMER_TM1Load_Ctrl:		.EQU	$27

;==============  CPU & Clock Register  ===============
P_CLK_CPU_Ctrl:				.EQU	$18
 D_RCHF_Msk:					.EQU	11100000B
 D_RCHF225K:					.EQU	00000000B;225k
 D_RCHF500K:					.EQU	01000000B;500k
 D_RCHF1800K:					.EQU	10000000B;1800k
 D_RCHF1000K:					.EQU	11000000B;1000k
 D_RCHF4000K:					.EQU	00100000B;4000k
 
 D_CPU_Msk:						.EQU	00000111B
 D_CPU_HF:						.EQU	00000000B;HF
 D_CPU_HF2:						.EQU	00000001B;HF/2
 D_CPU_HF4:						.EQU	00000010B;HF/4
 D_CPU_HF8:						.EQU	00000011B;HF/8
 D_CPU_HF16:					.EQU	00000100B;HF/16
P_CLK_HFDIV_Ctrl:			.EQU	$1A
P_CLK_32768_En:				.EQU	$0C
 D_LFEnable:					.EQU	00000000B 
 D_LFDisable:					.EQU	10000000B
 D_X32K_WEAK:					.EQU	00000100B
 D_X32K_STRO:					.EQU	00000010B
 D_CAP_EN:						.EQU	00000001B ;With internal CAP
 D_CAP_DIS:						.EQU	00000000B ;With external CAP
; D_256TMX_En:                   .EQU	00100000B

;=================  INT/NMI Register  ================
P_INT_Ctrl:					.EQU	$0D
 D_IntMask:						.EQU	11111111B
 D_Ext2Int:						.EQU	10000000B
 D_LvdInt:						.EQU	01000000B
 D_Timer0Int:					.EQU	00100000B
 D_TMBBInt:						.EQU	00010000B
 D_TMBAInt:						.EQU	00001000B
 D_128HzInt:					.EQU	00000100B
 D_2KHzInt:						.EQU	00000010B
 D_ExtInt:						.EQU	00000001B
 
P_INT_2KHz_Clear:			.EQU	$41
P_INT_128Hz_Clear:			.EQU	$42
P_INT_TimeBaseA_Clear:		.EQU	$43
P_INT_TimeBaseB_Clear:		.EQU	$44

P_INT_Timer0_Clear:			.EQU	$45
P_INT_Ext_Clear:			.EQU	$40

P_INT_Ctrl2:				.EQU	$2D
 D_Int2Mask:             		.EQU	00000011B
 D_Timer1Int:    				.EQU	00000001B
P_INT_Ext2_Clear:			.EQU	$47			
P_INT_Timer1_Clear:			.EQU	$48

;===================  LCD Register  ==================
P_LCD_Ctrl:					.EQU	$07
 D_LcdConfigMask:       		.EQU	11111101B
 D_Duty_1_8:					.EQU	10001000B
 D_Duty_1_6:					.EQU	11001000B
 D_Duty_1_5:					.EQU	00000100B
 D_Duty_1_4:   					.EQU	01000100B
 D_Duty_1_3:					.EQU	10000100B
 
 D_Bias_1_4:					.EQU	00000000B
 D_Bias_1_3:					.EQU	00100000B
 D_Bias_1_2:					.EQU	00010000B
 D_ScanEnable:					.EQU	00000001B
P_LCD_VLCD_Ctrl:			.EQU	$19
 D_Halt_Normal:					.EQU	00110000B
 D_Halt_Green:					.EQU	00100000B
 D_VLCD_28:						.EQU	00000000B
 D_VLCD_30:						.EQU	00000001B
 D_VLCD_33:						.EQU	00000010B
 D_VLCD_VDD:					.EQU	00000011B
;===============   Watch Dog Register  ===============
P_WDT_Flag_Clear:			.EQU	$0F

;==================  Reset Register  ==================
P_Reset_Status:			.EQU	$0E
 D_FlagC:						.EQU	00000001B;Reset in normal mode
 D_FlagON:						.EQU	00000010B;Reset in standby mode
 
;==================  AUDIO Register  =================
; Buzzer Output Control (PD[1:0] is buzzer output)
P_AUDIO_BZ_Ctrl:			.EQU	$16
 D_C32KOUT:						.EQU	10000000B
 D_Buzzer1:						.EQU	00000010B
 D_Buzzer0:						.EQU	00000001B

;==================  LVD Register  ===================
P_LVD_Ctrl:					.EQU	$1B
 D_LVD_State:					.EQU	00000001B
 D_LVD_22:						.EQU	00000000B
 D_LVD_24:						.EQU	01000000B
 D_LVD_27:						.EQU	10000001B
 D_LVD_33:						.EQU	11000001B
P_INT_LVD_Clear:			.EQU	$46

;================  RFC Control Register  ==============
P_RFC_Ctrl:					.EQU	$17
 D_EXT1EDG:						.EQU	10000000B
 D_EXT2EDG:						.EQU	01000000B
 D_RFCEN:						.EQU	00000001B
;=================  PWM Register  =====================
P_PWMIO_Ctrl:				.EQU	$3030
P_PWMIO_IO0_DUTY:			.EQU	$3032
P_PWMIO_IO1_DUTY:			.EQU	$3033
P_PWMIO_IO2_DUTY:			.EQU	$3034
P_PWMIO_IO3_DUTY:			.EQU	$3035

;**********************************************************************
;ROM Checksum
;**********************************************************************
;.IF (GPL813P01Ax+GPL813P01Bx+GPL813P01Cx)
;	D_BankNum:						.EQU	1	
;.ENDIF

	D_Bank0UserRomStartAddr:		.EQU	0xE000		;0x4800 ~ 0x7FDF:User ROM Code
	D_Bank0UserRomEndAddr:			.EQU	0xFFDF
	D_NMIandResetVectorStartAddr:	.EQU	0xFFFC		;0xFFF8 ~ 0xFFF9:User ROM Code, 0xFFFA ~ 0xFFFF:NMI & Reset & IRQ vector
	D_NMIandResetVectorEndAddr:		.EQU	0xFFFF

; ========================================================================================
; Macro Name	: M_UserRomChecksum
; Parameters	: None
; Return Value	: R_ChecksumResult: bit[7:0]
;				: R_ChecksumResult + 1: bit[15:8]
;				: R_ChecksumResult + 2: bit[23:16]
;				: R_ChecksumResult + 3: bit[31:24]
; Description	: Calculate user ROM area code checksum
; Destroy		: A, Y
; Example		: %M_UserRomChecksum	R_ChecksumAddrPtr, R_ChecksumResult
; ========================================================================================	
%M_UserRomChecksum:	.MACRO	R_ChecksumAddrPtr, R_ChecksumResult
	
	LDA		#0
	STA		R_ChecksumResult						;Result Byte0
	STA		R_ChecksumResult + 1				;Result Byte1
	STA		R_ChecksumResult + 2				;Result Byte2
	STA		R_ChecksumResult + 3				;Result Byte3
;=================== Bank 0 ==================================================	
	LDA		#.HIGH.D_Bank0UserRomStartAddr
	STA		R_ChecksumAddrPtr + 1				;Start High Byte
	LDA		#.LOW.D_Bank0UserRomStartAddr
	STA		R_ChecksumAddrPtr						;Start Low Byte
		
	LDY		#0	

L_ChecksumLoop1?
	STA		P_WDT_Flag_Clear	
	CLC
	LDA		(R_ChecksumAddrPtr),Y
	ADC		R_ChecksumResult						;Result Low Byte
	STA		R_ChecksumResult						;Result Low Byte
	BCC		L_CheckAddress1?
	INC		R_ChecksumResult + 1				;Result Byte1
	BNE		L_CheckAddress1?
	INC		R_ChecksumResult + 2				;Result Byte3
	BNE		L_CheckAddress1?
	INC		R_ChecksumResult + 3				;Result Byte4
		
L_CheckAddress1?:
	LDA		R_ChecksumAddrPtr + 1				;Address Pointer HB
	CMP		#.HIGH.D_Bank0UserRomEndAddr		;End High Byte
	BNE		L_IncreaseAdd1?
	
	LDA		R_ChecksumAddrPtr						;Address Pointer LB
	CMP		#.LOW.D_Bank0UserRomEndAddr			;End Low Byte
	BEQ		L_ExitRomSum1?
	
L_IncreaseAdd1?:
	INC		R_ChecksumAddrPtr						;Address Pointer LB
	BNE		L_ChecksumLoop1?
	INC		R_ChecksumAddrPtr + 1				;Address Pointer HB
	JMP		L_ChecksumLoop1?	
		
L_ExitRomSum1?:	

;===================NMI & Reset Vector==================================================		
	LDA		#.HIGH.D_NMIandResetVectorStartAddr
	STA		R_ChecksumAddrPtr + 1				; Start High Byte
	LDA		#.LOW.D_NMIandResetVectorStartAddr
	STA		R_ChecksumAddrPtr						;Start Low Byte
		
L_ChecksumLoop2?
	STA		P_WDT_Flag_Clear		
	CLC
	LDA		(R_ChecksumAddrPtr),Y
	ADC		R_ChecksumResult						;Result Low Byte
	STA		R_ChecksumResult						;Result Low Byte
	BCC		L_CheckAddress2?
	INC		R_ChecksumResult + 1				;Result Byte2
	BNE		L_CheckAddress2?
	INC		R_ChecksumResult + 2				;Result Byte3
	BNE		L_CheckAddress2?
	INC		R_ChecksumResult + 3				;Result Byte4
		
L_CheckAddress2?:
	LDA		R_ChecksumAddrPtr + 1				;Address Pointer HB
	CMP		#.HIGH.D_NMIandResetVectorEndAddr	;End High Byte
	BNE		L_IncreaseAdd2?
	
	LDA		R_ChecksumAddrPtr						;Address Pointer LB
	CMP		#.LOW.D_NMIandResetVectorEndAddr	;End Low Byte
	BEQ		L_ExitRomSum2?
	
L_IncreaseAdd2?:
	INC		R_ChecksumAddrPtr						;Address Pointer LB
	BNE		L_ChecksumLoop2?
	INC		R_ChecksumAddrPtr + 1				;Address Pointer HB
	JMP		L_ChecksumLoop2?	
		
L_ExitRomSum2?:	
;;=====================Bank area================================================		
	
	.ENDM
;================================================================================

			.ENDIF
.ENDIF
	.ENDIF
	