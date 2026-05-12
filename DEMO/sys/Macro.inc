
;==========================================
; Constant define area
C_SramAddrStart		    .EQU		0080H	;SRAM start address
C_SramAddrEnd   		.EQU		00FFH	;SRAM end address
C_DPRAMAddrStart		.EQU		3E00H	;DPRAM start address
C_DPRAMAddrEnd   		.EQU		3FFFH	;DPRAM end address

D_Bit0					equ		01H
D_Bit1					equ		02H
D_Bit2					equ		04H
D_Bit3					equ		08H
D_Bit4					equ		10H
D_Bit5					equ		20H
D_Bit6					equ		40H
D_Bit7					equ		80H

C_High		equ	0x01
C_Input		equ	0x00

;PCDir for 1  is output, for 0 is input
C_PC0Dir	equ	D_Bit0
C_PC1Dir	equ	D_Bit1
C_PC2Dir	equ	D_Bit2
C_PC3Dir	equ	D_Bit3
C_PC6Dir	equ	D_Bit6
C_PC7Dir	equ	D_Bit7

D_BLight	equ	D_Bit2
D_Pulse		equ	D_Bit3
D_LVD		equ	D_Bit5


C_MusicOne	equ	21
C_MusicAll	equ	22
C_MusicStop	equ	23
C_MinVol	equ	31
C_MaxVol	equ	45

;;============================================================================
;Macro Name: %M_ClearWatchDog
;Purpose: Clear Watchdog
;Destroy: A
;;============================================================================
%M_ClearWatchDog:		.MACRO 
	LDA		#D_WDT_Clear
	STA		P_WDT_Flag_Clear			; Clear WDT
	.ENDM
;;============================================================================
;Macro Name: %M_DisAllInt
;Purpose: Disable all interrupt 
;Destroy: A
;;============================================================================
%F_InitINT:		.MACRO
		LDA		#00000111b		;2HZ （bit0~2) for 111 is 4K 			;timeBaseA 2hz timeBaseB 16hz
		STA		P_TIMER_TimeBase_Sel		
		LDA		#D_2KHzInt+D_128HzInt+D_TMBAInt+D_TMBBInt;+D_Timer0Int
		STA		P_INT_Ctrl
		LDA		#00
		STA		P_INT_Ctrl2		;disable TMR1 INT
;		LDA		#D_TimerEn+D_TimerFallEdge+D_TimerSrcA_VDD+D_TimerSrcB_LF
;		STA		P_TIMER_Timer0_Ctrl
;		LDA		#0xC8
;		LDA		#0xFC
;		STA		P_TIMER_TM0Data_LB		;8k
;		LDA		#0xFF
;		STA		P_TIMER_TM0Data_HB
	.ENDM
;;============================================================================
;Macro Name: %DisableLCD
;Purpose: Disable LCD
;Destroy: A
;;============================================================================
%DisableLCD:		.MACRO
	
		LDA		#(D_Duty_1_5+D_Bias_1_4)	;+D_ScanEnable)
		STA		P_LCD_Ctrl		;1/11duty,1/4bias,normal scan
		
		LDA     #D_VLCD_33         ;VLCD = 4.5V (max value)
		STA     P_LCD_VLCD_Ctrl
	.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%M_InitLCD
; Description:	Initialize LCD configuration after power on
;-----------------------------------------------------------------------------	
;%M_InitLCD:		.MACRO
;    LDA		#D_LCDMode_Normal+D_LCDSetting_3Bias_4Duty+D_LCDGreenMode_En
;;	LDA		#(D_LCDMode_Normal+D_LCDSetting_3Bias_4Duty)
;	STA		P_LCD_Ctrl		;1/4duty,1/3bias,normal scan
;
;	.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%FillLcdDpram
; Description:	Fill LCD DPRAM $50 ~$5F
;-----------------------------------------------------------------------------
;%FillLcdDpram	.MACRO	mData
;		
;		%M_ClearWatchDog
;		LDX		#00H
;		LDA     mData
;?L_ClrDpramLoop:
;		STA		$50,X
;		INX
;		CPX		#10H
;		BNE		?L_ClrDpramLoop	
;
;	.ENDM

;;==========================================================================
;;Macro Name: %M_SetPC7_InputPL                 Attrib     Dir    Data
;;Purpose: Set PortC7 iutput pull low            0          0      1
;;Destroy: A
;;==========================================================================
;%M_SetPC7_InputPL:	.MACRO
;	    LDA		P_IO_PortC_Attrib
;		AND     #7FH
;		STA		P_IO_PortC_Attrib
;		
;		LDA		P_IO_PortC_Dir
;		AND     #7FH
;		STA		P_IO_PortC_Dir
;		
;		LDA		P_IO_PortC_Buffer
;		ORA		#10000000B
;		STA		P_IO_PortC_Data
;
;			.ENDM
;;==========================================================================
;;Macro Name: %M_SetPC7_InputPH               Attrib     Dir    Data
;;Purpose: Set PortC7 iutput pull high         1          0      1
;;Destroy: A
;;==========================================================================
;%M_SetPC7_InputPH:	.MACRO
;	    LDA		P_IO_PortC_Attrib
;		ORA     #80H
;		STA		P_IO_PortC_Attrib
;		
;		LDA		P_IO_PortC_Dir
;		AND     #7FH
;		STA		P_IO_PortC_Dir
;		
;		LDA		P_IO_PortC_Buffer
;		ORA		#10000000B
;		STA		P_IO_PortC_Data
;
;			.ENDM
;;==========================================================================
;;Macro Name: %M_SetPC7_Output               Attrib     Dir    Data
;;Purpose: Set PortC7 driving  low            0          1      0
;;Destroy: A
;;==========================================================================
;%M_SetPC7_OutputL:	.MACRO
;        LDA		P_IO_PortC_Attrib
;		AND     #7FH
;		STA		P_IO_PortC_Attrib
;		
;		LDA		P_IO_PortC_Dir
;		ORA     #80H
;		STA		P_IO_PortC_Dir
;		
;		LDA		P_IO_PortC_Buffer
;		AND		#01111111b
;		STA		P_IO_PortC_Data
;			.ENDM
;;==========================================================================
;;Macro Name: %M_SetPC7_Output             Attrib     Dir    Data
;;Purpose: Set PortC7 driving  high          0         1      1
;;Destroy: A
;;==========================================================================
;%M_SetPC7_OutputH:	.MACRO
;        LDA		P_IO_PortC_Attrib
;		AND     #7FH
;		STA		P_IO_PortC_Attrib
;		
;		LDA		P_IO_PortC_Dir
;		ORA     #80H
;		STA		P_IO_PortC_Dir
;		
;		LDA		P_IO_PortC_Buffer
;		ORA		#10000000B
;		STA		P_IO_PortC_Data
;		
;			.ENDM
;----------------------------------------------------------
;/***********************************************/
;         i.L=1 
%bits:   .MACRO   i,L             ;BYTE i;  
          lda     i               ;ex.  
          ora     #L              ;  %bits 10H,_BIT0
		                   ;  10H.0=1
          sta     i               ;
         .ENDM    

;/***********************************************/
;         i.L=0
%bitr:   .MACRO   i,L             ;BYTE i;  
          lda     i               ;ex.  
          and     #.NOT.L         ;  %bitr 10H,_BIT0;  10H.0=0
          sta     i
         .ENDM    

;/***********************************************/
;         if(i.L==1) goto N
%btst:   .MACRO   i,L,N           ;BYTE i;  
          lda     i               ;ex.   
          and     #L              ;  %btst 10H,_BIT0,N
          bne     N               ;  if(10H.0=1) goto N 
         .ENDM    
                                  
;/***********************************************/
;         if(i.L==0) goto N
%btsf:   .MACRO   i,L,N           ;BYTE i;    
          lda     i               ;ex.   
          and     #L              ;  %btsf 10H,_BIT0,N
          beq     N               ;  if(10H.0=0) goto N 
         .ENDM    
;/***********************************************/
;         if(i==#0) goto N
%jz:     .MACRO   i,N             ;BYTE i;
          lda     i               ;ex.
          beq     N               ;  %jz 10H,N
         .ENDM                    ;  if(10H==#0) goto N

;/***********************************************/
;         if(i!=#0) goto N
%jnz:    .MACRO   i,N             ;BYTE i;
          lda     i               ;ex.
          bne     N               ;  %jnz 10H,N
         .ENDM                    ;  if($10!=#0) goto N
            
;-----------------------------------------------------------------------------
; Macro Name:	%InitSystem
; Description:	Initial system port
;-----------------------------------------------------------------------------
%InitSystem		.MACRO
		LDA		#0
		STA		P_Reset_Status	;Clear AC key reset flag
		%Enable32KLF
	.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%Disable32KLF
; Description:	Disable Low Frequency
;-----------------------------------------------------------------------------
%Disable32KLF	.MACRO

		LDA		#D_LFDisable
		STA		P_CLK_32768_En

		.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%Enable32KLF
; Description:	Enable Low Frequency
;-----------------------------------------------------------------------------
%Enable32KLF		.MACRO

		LDA		#D_LFEnable
		STA		P_CLK_32768_En

	.ENDM		
;-----------------------------------------------------------------------------
; Macro Name:	%InitLCD
; Description:	Initialize LCD configuration after power on
;-----------------------------------------------------------------------------	
%InitLCD:		.MACRO

		LDA		#(D_Duty_1_5+D_Bias_1_3+D_ScanEnable)
		STA		P_LCD_Ctrl		;1/11duty,1/4bias,normal scan
		
		LDA     #D_VLCD_28            ;VLCD = 4.5V (max value)
;		LDA		#D_VLCD_VDD
		STA     P_LCD_VLCD_Ctrl
	
	.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%FillSram
; Description:	Fill data to SRAM whole space
; Input:		mData
;-----------------------------------------------------------------------------	
%FillSram		.MACRO	mData
		
		LDA		#.LOW.(C_SramAddrStart+2)
		STA		C_SramAddrStart
		LDA		#.HIGH.(C_SramAddrStart+2)
		STA		C_SramAddrStart+1
		
		LDX     #0
?L_FillLoop#:
        LDA     mData
		STA     (C_SramAddrStart,X)
		
		LDA     C_SramAddrStart+1
		CMP     #.HIGH.C_SramAddrEnd
		BCC     ?L_IncSramAddr#
		LDA     C_SramAddrStart
		CMP     #.LOW.C_SramAddrEnd
		BCS     ?L_End#
		
?L_IncSramAddr#:    ;Increase sram address
        INC     C_SramAddrStart
		BNE     ?L_FillLoop#
		INC     C_SramAddrStart+1
		%WatchDogClear
        JMP     ?L_FillLoop#
?L_End#:
        
        LDA     mData
        STA     C_SramAddrStart
        STA     C_SramAddrStart+1
        
        LDX		#00H
?L_HSRAMloop:
		LDA		mData
		STA		$180,X
		INX	
		CPX		#80H
		BNE		?L_HSRAMloop
		
	.ENDM
	
;-----------------------------------------------------------------------------
; Macro Name:	%ClrSRAM
; Description:	Clear SRAM $60 ~ $95F
;-----------------------------------------------------------------------------	
%ClrSRAM:	.MACRO

		%FillSram	#0

	.ENDM
;-----------------------------------------------------------------------------
;-----------------------------------------------------------------------------
; Macro Name:	%FillLcdDpram
; Description:	Fill LCD DPRAM $3E00 ~$3FFF
;-----------------------------------------------------------------------------
%FillLcdDpram	.MACRO	mData
		
		%WatchDogClear
		LDX		#00H
		LDY		#00H
?L_ClrDpramLoop:
		LDA     mData
		STA		$3E00,X
		INY
		CPY		#04H
		BNE		?L_ClrDpramLoopI
		LDY		#00H
		TXA
		CLC
		ADC		#0CH
		TAX
?L_ClrDpramLoopI:		
		INX
		CPX		#80H
		BNE		?L_ClrDpramLoop
	.ENDM
;-----------------------------------------------------------------------------
%F_Initinal_IO	.MACRO
		LDA		#00000000b		
		STA		P_IO_PortA_Dir
		LDA		#00000000b		
		STA		P_IO_PortA_Data	
		
		LDA		#0
		STA		P_IO_PortB_Attrib
		LDA		#00000011b		
		STA		P_IO_PortB_Dir
		LDA		#00000000b		
		STA		P_IO_PortB_Data		;PB1蜂鸣器，PB0背光

		LDA		#00H
		STA		P_IO_PortC_Dir
		LDA		#00000000b
		STA		P_IO_PortC_Data	
		
		LDA		#00h
		STA		P_IO_PortD_Attrib		
		LDA		#00000001b		
		STA		P_IO_PortD_Dir
		STA		P_IOD_DIR_Map	
		LDA		#00000010b
		STA		P_IO_PortD_Data		
		STA		R_PortD_Data_Buf

		LDA		#00000000b			;PE0/PE1/PE2 全部作为按键输入
		STA		P_IO_PortE_Dir
		LDA		#00000000b			
		STA		P_IO_PortE_Data		
		
		LDA		#00
		STA		P_IO_Ctrl			;all as normal IO
		.ENDM
;-----------------------------------------------------------------------------
; Clear watch dog
%WatchDogClear	 .MACRO

	   STA	   P_WDT_Flag_Clear

	   .ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%ClrPage0_60H_6FH
; Description:	Clear SRAM $60 ~ $7F
;-----------------------------------------------------------------------------	
%ClrPage0_60H_6FH:	.MACRO

		LDX		#0FH
		LDA		#0
		
?L_ClrLoop#:
		STA		$60,X
		DEX
		BPL		?L_ClrLoop#	

	.ENDM

;
;%EnableRR:		.MACRO	
;;RT=>PD4	RR=>PD3	
;		LDA		#D_Bit4+D_Bit5
;        STA		RFC_IO_Attrib
;		LDA		RB_IOD_Dir_temp
;		AND		#11000011b
;        ORA     #D_Bit5+D_Bit4+D_Bit3
;		STA		RFC_IO_Dir
;		LDA		RFC_IO_Data
;		ORA     #D_Bit2
;		STA     RFC_IO_Data
;		
;	.ENDM
;;------------------------
;%EnableRT:		.MACRO
;	
;		LDA		#D_Bit5+D_Bit3
;        STA		RFC_IO_Attrib
;		LDA		RB_IOD_Dir_temp
;		AND		#11000011b
;        ORA     #D_Bit5+D_Bit4+D_Bit3
;		STA		RFC_IO_Dir
;		LDA		RFC_IO_Data
;		ORA     #D_Bit2
;		STA     RFC_IO_Data
;		
;	.ENDM
;;===================================================
;;%EnableRR:		.MACRO	
;;;RT=>PD4	RR=>PD3	
;;;		LDA		RB_IOD_Dir_temp
;;;		LDA		#D_Bit3+D_Bit4
;;		LDA		#D_Bit4
;;        STA		RFC_IO_Attrib
;;		LDA		RB_IOD_Dir_temp
;;		AND		#11100001b
;;;        ORA     #D_Bit5+D_Bit4+D_Bit3
;;		ORA		#D_Bit4+D_Bit3
;;		STA		RFC_IO_Dir
;;		STA		RB_IOD_Dir_temp
;;		LDA		RFC_IO_Data
;;		AND		#11100011b
;;		ORA     #D_Bit2
;;		STA     RFC_IO_Data
;;		
;;	.ENDM
;;;------------------------
;;%EnableRT:		.MACRO
;;	
;;		LDA		#D_Bit3
;;;		LDA		#D_Bit4+D_Bit5
;;        STA		RFC_IO_Attrib
;;		LDA		RB_IOD_Dir_temp
;;		AND		#11100001b
;;        ORA     #D_Bit4+D_Bit3;+D_Bit5
;;		STA		RFC_IO_Dir
;;		STA		RB_IOD_Dir_temp
;;		LDA		RFC_IO_Data
;;		AND		#11100011b
;;		ORA     #D_Bit2
;;		STA     RFC_IO_Data
;;		
;;	.ENDM
;;------------------------
;%EnableRH:		.MACRO
;		LDA		#D_Bit3;+D_Bit5
;        STA		RFC_IO_Attrib
;        LDA		RB_IOD_Dir_temp
;        AND		#11100001b
;        ORA     #D_Bit4+D_Bit3;+D_Bit5
;		STA		RFC_IO_Dir
;		STA		RB_IOD_Dir_temp
;		LDA		RFC_IO_Data
;		AND		#11100011b
;		ORA     #D_Bit2
;		STA     RFC_IO_Data
;	.ENDM	
;==============================================
%SetTimerData   .MACRO  c_data

        LDA     #.LOW.c_data
        STA     P_TIMER_TM0Data_LB
        LDA     #.HIGH.c_data
        STA     P_TIMER_TM0Data_HB
        STA     P_TIMER_TM0Load_Ctrl
        
	.ENDM
;-----------------------------------------------------------------------------
; Macro Name:	%PushAll                                                        
; Description:	Push                                                          
;-----------------------------------------------------------------------------
%PushAll:		.MACRO                                                            
		PHP                                                                         
		PHA                                                                         
		TXA                                                                         
		PHA                                                                         
		TYA                                                                         
		PHA                                                                         
                                                                       
			.ENDM                                                                   
;-----------------------------------------------------------------------------
; Macro Name:	%PopAll                                                         
; Description:	Pop                                                           
;-----------------------------------------------------------------------------
%PopAll:		.MACRO                                                            
                                                    
		PLA                                                                         
		TAY                                                                         
		PLA                                                                         
		TAX                                                                         
		PLA                                                                         
		PLP                                                                         
			.ENDM	                                
		
;==========================================================================
LCDConvert		.MACRO  com,seg
;			DB	com*8+(seg/8)+00H,1<<(seg.AND.07H)
;			DB	(com*8+07H)-(seg/8),1<<(seg.AND.07H)	;LB25B
;			DB	com*4+(seg/8)+50H,1<<(seg.AND.07H)	;L11A\B
;			DB	com*6+(seg/8)+20H,1<<(seg.AND.07H)	;L31B
;LCDConvert:		.Macro	com,seg
;			DB	com*4+(seg/8)+A0H,1<<(seg.AND.07H)	;GPL10A
			DB	com*10H+(seg/8)+00H,1<<(seg.AND.07H)	;GPL813P01;
			
			.ENDM
			
%LCD7S        .MACRO   i1c,i1s,i2c,i2s,i3c,i3s,i4c,i4s,i5c,i5s,i6c,i6s,i7c,i7s
               LCDConvert    i1c,i1s
               LCDConvert    i2c,i2s
               LCDConvert    i3c,i3s
               LCDConvert    i4c,i4s
               LCDConvert    i5c,i5s
               LCDConvert    i6c,i6s
               LCDConvert    i7c,i7s
               .ENDM
               
%LCD8S:        .MACRO   i1c,i1s,i2c,i2s,i3c,i3s,i4c,i4s,i5c,i5s,i6c,i6s,i7c,i7s,i8c,i8s
               LCDConvert    i1c,i1s
               LCDConvert    i2c,i2s
               LCDConvert    i3c,i3s
               LCDConvert    i4c,i4s
               LCDConvert    i5c,i5s
               LCDConvert    i6c,i6s
               LCDConvert    i7c,i7s
		       LCDConvert    i8c,i8s
               .ENDM  
             
;**********************************************************************
%Define_IOPort:	.Macro
			lda	#(PortCD0Output+PortCD1Output+PortCD2Output+PortCD3Output)
			sta	P_00H_Port_Ctrl
			lda	#03H		;D_PortCDScan
			sta	P_03H_PortCD_Data
			.ENDM	

;================================================================
;Kind   :Count Loop
;================================================================
;-------------------------------------------------------------------------
%DJNZ:               .MACRO       Var,Lable    ;  !=0
                      DEC          Var
                      BNE          Lable
                     .ENDM
