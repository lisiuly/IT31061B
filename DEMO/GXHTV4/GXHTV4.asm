;==================================================================================
; The information contained herein is the exclusive property of
; Generalplus Technology Co. And shall not be distributed, reproduced,
; or disclosed in whole in part without prior written permission.
;       (C) COPYRIGHT 2017   Generalplus TECHNOLOGY CO.                            
;                   ALL RIGHTS RESERVED
; The entire notice above must be reproduced on all authorized copies.
;==================================================================================
;==================================================================================
; Name                  : GXHTV4.asm
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



;==========================================
; External declare area
;==========================================
.EXTERN		F_IIC_start
.EXTERN		F_IIC_stop
.EXTERN		F_IIC_Set8bit
.EXTERN		F_RACK
.EXTERN		F_I2C_ReadData
.EXTERN		R_SaveData

;==========================================
; Public declare area
;==========================================16进制数==============================
.PUBLIC		TEMP_INTEGAH
.PUBLIC		TEMP_INTEGAL
.PUBLIC		HUM
.PUBLIC		F_ReadGXHTV4Data
.PUBLIC		F_CAL_HEX_BCD2
.PUBLIC		F_CHANGE_CF
.PUBLIC		R_TempFlag
.PUBLIC		OUT_H
.PUBLIC		OUT_M
.PUBLIC		OUT_L
.PUBLIC		X_M
.PUBLIC		X_L
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0
R_TempFlag		ds	1
D_TempF			equ	0x01	;1 for 'F;  0 for 'C ，上电默认为F此Bit需置１
D_TempError		equ	0x02	;温度出错标志
D_TempFReg		equ	0x04	;TempF for -

INDF0			ds	1
TEMP_INTEGAH	ds	1
TEMP_INTEGAL	ds	1
HUM				ds	1

CNT1	ds		1
CNT2	ds		1
CNT3	ds		1
CNT4	ds		1
CNT5	ds		1
CNT6	ds		1
X_H		ds		1
X_1		ds		1
X_M		ds		1
X_L		ds		1
Y_H		ds		1
Y_L		ds		1
OUT_L	ds		1
OUT_M	ds		1
OUT_1	ds		1
OUT_H	ds		1



; F_IIC_Set8bit 发送的是完整 8bit 地址字节，不是 7bit 地址。
; 这里必须使用 0x44 左移一位后的写地址 0x88，
; 否则起始写命令阶段就会发错地址，设备不会 ACK。
I2C_ID_GXHTV4		.equ				%10001000	; 8bit write address for 7bit slave 0x44
I2C_WRITE_BIT		.equ				%00000000 
I2C_READ_BIT		.equ				%00000001 

; GXHTV4 的测量命令是 1 byte，不是旧 SHT3x 风格的 16bit 0x2400。
CMD_MEASURE_TH		.EQU				0x24



;==========================================
; code starting 
;==========================================
.CODE
;==========================================
; IRQ INTERRUPT SERVICE ROUTINE
;==========================================
;======================================================================
; 通过 D_I2C 底层发送转换命令，再读取 6 字节原始数据。
; 读取成功后更新 TEMP_INTEGAH/TEMP_INTEGAL/HUM。
;======================================================================
F_ReadGXHTV4Data:
		JSR			F_IIC_start
		LDY			#I2C_ID_GXHTV4
		JSR			F_IIC_Set8bit
		JSR			F_RACK
		BCC			F_ReadGXHTV4StopExit
		LDY			#CMD_MEASURE_TH
		JSR			F_IIC_Set8bit
		JSR			F_RACK
		BCC			F_ReadGXHTV4StopExit
		JSR			F_IIC_stop

		JSR			F_GXHTV4WaitReady
		JSR			F_I2C_ReadData

		LDA			R_SaveData+0
		STA			CNT4
		LDA			R_SaveData+1
		STA			CNT5
		LDA			R_SaveData+2
		STA			CNT6
		JSR			F_crc_check_handle
		BCC			F_ReadGXHTV4Data_Exit
		JSR			CAL_IC_TEMP

		LDA			R_SaveData+3
		STA			CNT4
		LDA			R_SaveData+4
		STA			CNT5
		LDA			R_SaveData+5
		STA			CNT6
		JSR			F_crc_check_handle
		BCC			F_ReadGXHTV4Data_Exit
		JSR			CAL_IC_HUM
		RTS

F_ReadGXHTV4StopExit:
		JSR			F_IIC_stop

F_ReadGXHTV4Data_Exit:
		RTS

F_GXHTV4WaitReady:
		; 0x24 是 0.1s 加热测量命令，这里等待约 160ms，先把“时间不够”排除掉。
		LDA			#02H
		PHA
F_GXHTV4WaitReady_A:
		LDY			#0FFH
F_GXHTV4WaitReady_Y:
		LDX			#0FFH
F_GXHTV4WaitReady_X:
		DEX
		BNE			F_GXHTV4WaitReady_X
		DEY
		BNE			F_GXHTV4WaitReady_Y
		PLA
		SEC
		SBC			#01H
		BEQ			F_GXHTV4WaitReady_Done
		PHA
		BNE			F_GXHTV4WaitReady_A
		
F_GXHTV4WaitReady_Done:
		RTS

;======================================================================
;.COMMENT	@
;  Input CNT4,CNT5
;======================================================================
CAL_IC_TEMP:   ;IN:CNT4,CNT5
    ;T=(-450 + ST * 1750/65535)/10
    	LDA            	CNT4
    	STA          	X_H
    	LDA            	CNT5
    	STA           	X_L
    	
    	LDA          	#0D6H        ;1750 =6D6
    	STA           	Y_L
    	LDA           	#06H
    	STA           	Y_H
    	JSR            	MUL_HEX     ;/65536=10000H
    	LDA	    		#0FFH
    	STA	   			Y_H
    	LDA	    		#0FFH
    	STA    			Y_L
		JSR				DIV_HEX		;OUT:X
	
		SEC
		LDA				X_L
		SBC				#0xC2
		LDA				X_M 
		SBC				#0x01
 
		BCC            CAL_TEMP_PLUS
;=======  + =======================
		SEC
		LDA				X_L
		SBC				#0xC2
		STA				TEMP_INTEGAL
		lda				X_M
		SBC				#0x01
     	STA				TEMP_INTEGAH

		SEC
		LDA			TEMP_INTEGAL
		SBC			#0xBC
		LDA			TEMP_INTEGAH
		SBC			#0x02

    	BCC			CAL_TEMP_OUT
    	LDA			#02H
    	STA			TEMP_INTEGAH
    	LDA			#0BCH
    	STA			TEMP_INTEGAL
    	JMP			CAL_TEMP_OUT
CAL_TEMP_PLUS: ; -
		SEC
		LDA			#0C2H
		SBC			X_L 
		STA			TEMP_INTEGAL
		LDA			#0X01
		SBC			X_M 
		STA			TEMP_INTEGAH
;		BSF			TEMP_INTEGAH,BIT7		;-
		LDA			TEMP_INTEGAH
		ORA			#0x80
		STA			TEMP_INTEGAH

		SEC
		LDA			TEMP_INTEGAL
		SBC			#0xC8
		LDA			TEMP_INTEGAH
		SBC			#0x080
		BCC			CAL_TEMP_OUT
    	LDA			#080H
    	STA			TEMP_INTEGAH
    	LDA			#0C8H
    	STA			TEMP_INTEGAL
CAL_TEMP_OUT:
		RTS
;======================================================================
;======================================================================
CAL_IC_HUM:   ;IN:CNT4,CNT5
    ; RH = -6 + 125 * S / 65535，整数链路对结果夹到 0..100。
    	LDA      	CNT4
		STA        	X_H
    	LDA       	CNT5
    	STA        	X_L
	    	LDA      	#07DH
    	STA     	Y_L
    	LDA			#00
    	STA        	Y_H
    	JSR         MUL_HEX     ;/65536=10000H
    	LDA	    	#0FFH
    	STA	   		Y_H
		LDA	    	#0FFH
    	STA    		Y_L
		JSR			DIV_HEX		;OUT:X = floor(125 * S / 65535)

		SEC
		LDA			X_L
		SBC			#06H
		BCS			CAL_HUM_CLAMP_HIGH
		LDA			#00H
		STA			HUM
		RTS

CAL_HUM_CLAMP_HIGH:
		CMP			#064H
		BCC			CAL_HUM_STORE
		LDA			#064H

CAL_HUM_STORE:
		STA			HUM
CAL_HUM_OUT:
;==========================================
;==========================================
		RTS
;==========================
;;*****************
;;crc校验，最高位是1就^0x31
;高位数据放 R_temp1 低位数据放 R_temp0 crc数据放 R_temp2 进
;相等返回 c=1 
F_crc_check_handle:;
	LDA		CNT4
	STA		CNT1
	LDA		CNT5
	STA		CNT2

	LDA		#0x08
	STA 	CNT3
	LDA 	CNT1
	EOR  	#0xff
	STA 	CNT1
F_crc_check_h_loop:
	LDA		CNT1
	AND		#0x80
;	BIT		#BIT7
	BEQ 	F_crc_check_h_loop_clr
F_crc_check_h_loop_set:
	CLC
	ROL 	CNT1 
	LDA 	CNT1
	EOR  	#0x31
	STA 	CNT1
	JMP 	F_crc_check_h_loop_0
F_crc_check_h_loop_clr:
	CLC 	
	ROL 	CNT1
F_crc_check_h_loop_0:
	DEC 	CNT3 
	BNE 	F_crc_check_h_loop
;======================
	LDA		#0x08
	STA 	CNT3
	LDA 	CNT1			;前一位CRC结果
	EOR 	CNT2
	STA 	CNT1
F_crc_check_l_loop:
	LDA		CNT1
	AND		#0x80
;	BIT		#BIT7
	BEQ 	F_crc_check_l_loop_clr
F_crc_check_l_loop_set:
	clc	
	ROL 	CNT1
	LDA 	CNT1
	EOR  	#0x31
	STA 	CNT1
	JMP 	F_crc_check_l_loop_0
F_crc_check_l_loop_clr:
	CLC 	
	ROL 	CNT1
F_crc_check_l_loop_0:
	DEC		CNT3
	BNE 	F_crc_check_l_loop
;================
	LDA 	CNT1
	CMP		CNT6
	BNE		F_crc_check_err
	SEC 
	RTS
F_crc_check_err:
	CLC
	RTS		
	
	
;----------------------------------------
DIV_HEX:;IN:OUT_H,OUT_1,OUT_M,OUT_L; Y_H,Y_L;OUT:X_H,X_1,X_M,X_L
	;余数:CNT5,CNT6: USE:X,Y
	lda		#00
	STA		X_H
	STA		X_1
	STA		X_M
	STA		X_L

	STA		CNT2
	STA		CNT3
	STA		CNT4

	LDA		Y_H;除数为零跳出
	BNE		NDIV1;Z=0
	LDA		Y_L
	BEQ		NDIV_END;Z=1
NDIV1:
	LDX		#32;16
NDIV2:
	CLC
	ROL		OUT_L	;被除数
	ROL		OUT_M
	ROL		OUT_1
	ROL		OUT_H

	ROL		CNT4	;余数
	ROL		CNT3
	ROL		CNT2	;溢出位

	ROL		X_L		;OUT????????
	ROL		X_M
	ROL		X_1
	ROL		X_H

	LDA		CNT2
	BNE		NDIV_SUB	;Z=0
	SEC
	LDA		CNT3
	SBC		Y_H
	BEQ		NDIV_7	;Z=1
	BCS		NDIV_SUB
	JMP		NDIV4	;不够减????
NDIV_7:
	SEC
	LDA		CNT4
	SBC		Y_L
	BCS		NDIV_SUB;C=1
	JMP		NDIV4	;不够减
NDIV_SUB:
	LDA		#00
	STA		CNT2
	SEC
	LDA		CNT4
	SBC		Y_L
	STA		CNT4
	LDA		CNT3
	SBC		Y_H
	STA		CNT3

	INC		X_L	;OUT LOW BIT

NDIV4:
	DEX
	BNE		NDIV2	;Z=0

NDIV_END:
	RTS
;----------------------------
MUL_HEX:;双字节 * 双字节 -->4字节;IN:X_H,X_L ; Y_H,Y_L,
	;OUT:OUT_H,OUT_1,OUT_M,OUT_L;
	LDA		#00H
	STA		OUT_H;清零
	STA		OUT_1
	STA		OUT_M
	STA		OUT_L
	LDX		#$10	;16BIT
MUL_LOOP:
;	CLC
	ASL		OUT_L
	ROL		OUT_M
	ROL		OUT_1
	ROL		OUT_H

	ROL		Y_L
	ROL		Y_H
	BCC		TO_LOOP0	;C=0 JMP
	CLC		;CLEAR C
	LDA		X_L
	ADC		OUT_L
	STA		OUT_L
	LDA		X_H
	ADC		OUT_M
	STA		OUT_M
	LDA		#00
	ADC		OUT_1
	STA		OUT_1
	LDA		#00
	ADC		OUT_H
	STA		OUT_H
TO_LOOP0:
	DEX
	BNE		MUL_LOOP  	;Z=0	
	RTS
		
;===================================		
	
F_CAL_HEX_BCD2:		;高位放在X，低位放在A
	STX	CNT1
	STA	CNT2
;B2_BCD:
;	BC	STATUS,CF		; CLEAR THE CARRY BIT
	LDY		#16D
;	STA		CNT3
	LDA		#00
	STA		OUT_H
	STA		OUT_M
	STA		OUT_L
LOOP16:
;	CLC
    ASL		CNT2
	ROL		CNT1
	ROL		OUT_L
	ROL		OUT_M
	ROL		OUT_H
	DEY
	BNE		ADJDEC
;	JMP	ADJDEC
;	CLRF	STATUS
	RTS

ADJDEC:				;	;存到连续两个BYTE所指向的地址
	LDX		#OUT_L-INDF0
	JSR		ADJBCD

	LDX		#OUT_M-INDF0	;LOW
	JSR		ADJBCD

	LDX		#OUT_H-INDF0
	JSR		ADJBCD
	JMP		LOOP16
        ;==============

        
ADJBCD:
        LDA      	INDF0,X
        STA			CNT4
        LDA			#3
		ADC			CNT4
		STA			CNT5
;		BTFSC		CNT5,BIT3,ADJ1		; TEST IF RESULT > 7
;		%RFC_btsf	CNT5,0x08,ADJ1	
		LDA			CNT5
		AND			#0x08
		BEQ			ADJ1
		LDA			CNT5
		STA			CNT4
ADJ1:
		LDA			#30H
		ADC			CNT4
		STA			CNT5
;		BTFSC		CNT5,BIT7,ADJ2		; TEST IF RESULT > 7
;		%RFC_btsf	CNT5,0x80,ADJ2
		LDA			CNT5
		AND			#0x80
		BEQ			ADJ2
		LDA			CNT5
		STA			CNT4		; SAVE AS MSD
ADJ2:
        LDA	     	CNT4
        STA   		INDF0,X
        RTS
;===================================
F_CHANGE_CF:	;X高位，A低位，C和F的显示转化  C-->F X * 9 / 5 + 32
	STX			CNT1
	STA			CNT2
;	%RFC_bitr	R_TempFlag,D_TempFReg
	LDA		R_TempFlag
	AND		#.not.D_TempFReg
	STA		R_TempFlag
	LDA			#10000000B
	BIT			CNT1
	BEQ			CH_C1
;	%RFC_bits	R_TempFlag,D_TempFReg
	LDA		R_TempFlag
	ORA		#D_TempFReg
	STA		R_TempFlag
CH_C1:
;	%RFC_bitr	CNT1,0x80
	LDA		CNT1
	AND		#.not.0x80
	STA		CNT1
    LDA         #07FH	            ;7F,7FH-->  --.-
	CMP			CNT1
	BNE			CHANGE_F
;	BEQ			CHANGE1_V
;	BTFSS		FLAG1,TEMP_CF,CHANGE_F			;;(1.7:=0显示C;=1显示F) 
;CHANGE1_V:
	JMP			CHANGE_RET
CHANGE_F:		 ;转成 F 法氏度
 	LDA			#00H
	STA			X_H
	LDA			#09H		;*10
	STA			X_L
	LDA			CNT1		;<=50度 
	STA			Y_H	;R_TempRT+1
	LDA			CNT2 		;<=50度 
	STA			Y_L	;R_TempRT+0
	JSR			MUL_HEX		;OUT: OUT_H ..OUT_L
	LDA			#00H
	STA			Y_H	;R_TempRT+1
	LDA			#05H
	STA			Y_L	;R_TempRT+0
	JSR			DIV_HEX		;IN:OUT_H,OUT_1,OUT_M,OUT_L; Y_H,Y_L;OUT:X_H,X_1,X_M,X_L
							;余数:CNT3,CNT4: USE:X,Y
;	%RFC_btst	R_TempFlag,D_TempFReg,CHANGE_PLUS
	LDA		R_TempFlag
	AND		#D_TempFReg
	BNE		CHANGE_PLUS
	CLC	
	LDA			#40H               ;320==140H     ;为正
	ADC			X_L		          ;DIS_TEMP_INTEGAL,A
	STA			X_L    
	LDA			#01H
    ADC         X_M
	STA			X_M
	JMP	  		CHANGE_OUT
CHANGE_PLUS:	;为负
	SEC
	LDA			X_L
	SBC			#41H
	LDA			X_M
	SBC			#01H
	BCS    		CHANGE_SUB	;321 X > 320 为负
;	%RFC_bitr	R_TempFlag,D_TempFReg
	LDA		R_TempFlag
	AND		#.not.D_TempFReg
	STA		R_TempFlag
	SEC
	LDA			#40H
	SBC			X_L
	STA			X_L
	LDA			#01H
	SBC			X_M
	STA			X_M	   ;320 - X	
	JMP			CHANGE_OUT
CHANGE_SUB:	;>=33  为负
	SEC
	LDA			X_L
	SBC			#40H
	STA			X_L
	LDA			X_M
	SBC			#01H
	STA			X_M        ;X- 320

CHANGE_OUT:
    LDA                 X_M
    STA               	CNT1
    LDA                 X_L
   	STA               	CNT2
;;==================================
CHANGE_RET:
;	%RFC_btsf	R_TempFlag,D_TempFReg,CH_R1 
	LDA	R_TempFlag
	AND	#D_TempFReg
	BEQ	CH_R1
;	%RFC_bits	CNT1,0x80
	LDA	CNT1
	ORA	#0x80
	STA	CNT1
CH_R1:
	RTS
;;CHANGE_RET1:        ;
;   ; 	LDA               #7FH
;   ; 	STA               CNT1        ;OUT_M
;;    	STA               CNT2        ;OUT_L
;    ;	RTS
;;===========================================        
;==========================================
.END


