;==================================================================================
; Name                  : D_I2C.asm
; Applied Body          : GPL813X
; Programmer            : 
; Description           : 模拟IIC通讯(发送端)
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
;.INCLUDE	GPL815P.inc
;.INCLUDE	sys\System.inc
;.INCLUDE	define.inc

;==========================================
; Constant define area
;==========================================
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2C_SDA:	.equ		00010000B		;PD4 - SDA引脚掩码
I2C_SCL:	.equ		00001000B		;PD3 - SCL引脚掩码
I2C_SCL_SDA_VAL: .EQU	00011000B	; PD4+PD3组合置位值
P_I2C_Dat:	.equ		P_IO_PortD_Data


C_SlaveAddr: .EQU		10001000b;00100000b; [RDA5708]; //00100000b;[QN8035];//10100000b;[24c01];//10001010b;[STHTV4]	;器件地址 
C_Write:	 .EQU		00000000b
C_Read:		 .EQU		00000001b
;==========================================
; External declare area
;==========================================




;==========================================
; Public declare area
;==========================================
.PUBLIC		R_Wbuff
.PUBLIC		R_Wbuff1
.PUBLIC		P_IOB_DIR_Map
.PUBLIC		P_IOC_DIR_Map
.PUBLIC		P_IOD_DIR_Map
.PUBLIC		P_IOA_DIR_Map
.PUBLIC		P_IOA_Attrib_Map	
.PUBLIC		R_SaveData
.PUBLIC		R_PortD_Data_Buf
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0
R_Wbuff				.DS	1
R_Wbuff1			.ds	1
P_IOB_DIR_Map		.DS	1		;
P_IOC_DIR_Map		.DS	1		;
P_IOD_DIR_Map		.DS	1		;
P_IOA_DIR_Map		.DS	1	
R_PortD_Data_Buf	ds	1

P_IOA_Attrib_Map	ds	1
R_SaveData			ds	6
R_ACK_Timeout		ds	1
R_ACK_Err			ds	1
;==========================================
; code starting 
;==========================================
.CODE
;-------------SetIO Pin------------------------
;***************************************
B_SDA_0:	;Set SDA output L
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SDA
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		AND		#.not.I2C_SDA
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
			RTS			
;***************************************
.public			B_SDA_1
B_SDA_1:	;Set SDA output H
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SDA
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#I2C_SDA
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
			RTS	
;***************************************			
B_SCL_0:	;Set SCL output L
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SCL
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		AND		#.not.I2C_SCL
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
		RTS	
;***************************************
.PUBLIC		B_SCL_1
B_SCL_1:	;Set SCL output H
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SCL
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#I2C_SCL
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data
		RTS	
;***************************************			
B_SCLSDA_0:	;Set SCL & SDA output L
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SCL_SDA_VAL
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		AND		#.not.I2C_SCL_SDA_VAL
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data		;SCL
		RTS				
;***************************************			
B_SCLSDA_1:	;Set SCL & SDA output H
		LDA		P_IOD_DIR_Map
		ORA		#I2C_SCL_SDA_VAL
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#I2C_SCL_SDA_VAL
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data		;SCL
		RTS	
;***************************************
.PUBLIC		B_SDA_F
B_SDA_F:	;Release SDA so the slave can drive ACK/data bits
		LDA		P_IOD_DIR_Map
		AND		#.not.I2C_SDA
		STA		P_IOD_DIR_Map
		STA		P_IO_PortD_Dir
		LDA		R_PortD_Data_Buf
		ORA		#I2C_SDA
		STA		R_PortD_Data_Buf
		STA		P_IO_PortD_Data		;SDA
		RTS


; 旧 PA4/PA5 版本的注释实现已移除，当前硬件固定为 PD3=SCL、PD4=SDA。
F_I2C_Delay:
		LDA		#00
	   STA	   P_WDT_Flag_Clear
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP

			RTS
;=========================================================
.PUBLIC	F_IIC_start			
;****************************************			
F_IIC_start:	; SCL == H, SDA = H to L
		JSR		B_SCLSDA_1
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay
		JSR		B_SDA_0
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay	
			RTS
;=========================================================
.PUBLIC	F_IIC_stop				
;****************************************			
F_IIC_stop:		; SCL == L, SDA = L to H
		JSR		B_SCLSDA_0
		JSR		F_I2C_Delay
		JSR		B_SCL_1
		JSR		F_I2C_Delay
		JSR		B_SDA_1
		JSR		F_I2C_Delay	
			RTS	
;=========================================================
.PUBLIC	F_IIC_Set8bit			
;****************************************	
F_IIC_Set8bit:	; Y = input 8bit data value	
		JSR		B_SCL_0
		JSR		F_I2C_Delay
		;X = bit count; Y = be write byte
		LDX		#8
	?loop:	
		TYA               ; 先把Y加载到A，不修改Y
		AND		#0x80        ; 提取最高位（0x80=10000000B）
		BEQ		?set_0       ; 最高位为0 → 发0
	?set_1:	
		JSR		B_SDA_1		
		JMP		?next
	?set_0:
		JSR		B_SDA_0
	?next:	
		JSR		F_I2C_Delay
		JSR		B_SCL_1
		JSR		F_I2C_Delay
		JSR		B_SCL_0
		JSR		F_I2C_Delay
		; 移位操作放在最后（判断完再移位）
		TYA
		ASL		A			; 左移1位，准备下一位
		TAY	
		DEX		
		BNE		?loop	
		RTS	
;		TYA
;		ASL		A			;从高到低开始传
;	;	LSR		A			;从低到高开始传
;		TAY	
;		BCS		?set_1
;	?set_0:
;		JSR		B_SDA_0
;		JMP		?next
;	?set_1:	
;		JSR		B_SDA_1		
;	?next:	
;		JSR		F_I2C_Delay
;		JSR		B_SCL_1
;		JSR		F_I2C_Delay
;		JSR		B_SCL_0
;		JSR		F_I2C_Delay
;		DEX		
;		BNE		?loop	
;			RTS
;=========================================================	
.PUBLIC	F_IIC_get8bit			
;****************************************			
F_IIC_get8bit:	; Y = output 8bit data value
		;设置SDA口为Input floating状态
		JSR		B_SDA_F
		;X表示bit的个数,Y表示读出的值
		LDX		#8
		LDY		#0
	?loop:
		; SCK = 1 and Delay		
		JSR		B_SCL_1
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay
		; Get SDA and Save to Y
		LDA		P_I2C_Dat
		AND		#I2C_SDA
		CMP		#I2C_SDA
		TYA
		ROL		A			;从高到低接收
	;	ROR		A			;从低到高接收
		TAY
		;SCK = 0 and Delay
		JSR		B_SCL_0
		JSR		F_I2C_Delay	
		JSR		F_I2C_Delay
		; Check finish of 8 bit move out or not
		DEX
		BNE		?loop
		;设置SDA output	low, 接下来是SACK或SNACK,
		JSR		B_SDA_0		
			RTS	
;=========================================================
.PUBLIC	F_ACK	;发送ACK
;****************************************			
F_ACK:	;Check ACK & Send ACK [[no check ACK but only wait one scycle]]
		JSR		B_SDA_0
		JSR		F_I2C_Delay
		JSR		B_SCL_1
		JSR		F_I2C_Delay
		JSR		B_SCL_0
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay
			RTS	
;=========================================================
.PUBLIC	F_RACK  ;接收ACK
;****************************************						
F_RACK:
		JSR		B_SDA_F
		JSR		F_I2C_Delay	
		;------------------------
		LDA		#0		
		STA		R_ACK_Err
		STA		R_ACK_Timeout	
		JSR		B_SCL_1
		JSR		F_I2C_Delay
	?wait:	
		LDA		#00
	   STA	   P_WDT_Flag_Clear

		INC		R_ACK_Timeout
		
		LDA		R_ACK_Timeout
		CMP		#0x80			; 超时阈值（可调整，如0x80≈1ms，需匹配你的F_I2C_Delay时长）
		BCS		?ACK_Timeout
		
		LDA		P_I2C_Dat	
		AND		#I2C_SDA
		BNE		?wait
		
	;	BNE		?FailRACK
		JSR		B_SCL_0
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay
		;设置SDA output	low,
		JSR		B_SDA_0
		SEC				; ACK received
		RTS
	?ACK_Timeout:
		LDA		#0x01	
		STA		R_ACK_Err
		JSR		B_SCL_0
		JSR		F_I2C_Delay
		JSR		F_I2C_Delay
		JSR		B_SDA_0
		CLC				; ACK timeout / NAK
		RTS


			
;=========================================================	
.PUBLIC F_NACK	;发送NACK		
;****************************************			
F_NACK: ;Send NACK
		JSR		B_SDA_1
		JSR		F_I2C_Delay
		JSR		B_SCL_1
		JSR		F_I2C_Delay
		JSR		B_SCL_0
		JSR		F_I2C_Delay
			RTS	
			
;****************************************************************************************
;函数名称: F_I2C_Initial
;功能描述: 初始I2C_SCK,I2C_SDA两个IO为output high
;****************************************************************************************
.PUBLIC F_I2C_Initial
;~~~~~~~~~~~~~~~~~~~~~~~~
F_I2C_Initial:				
;		LDA		P_12C_DirMap
;		ORA		#(I2C_SCK+I2C_SDA)
;		STA		P_12C_DirMap
;		STA		P_I2C_Dir			
	
;		LDA		P_12C_DatMap
;		ORA		#(I2C_SCK+I2C_SDA)
;		STA		P_12C_DatMap
;		STA		P_I2C_Dat
			RTS			
;******************************************************************************************************
; 名    称: F_I2C_WriteData
; 输    入: A->设备的特殊寄存器地址; X->写入的值
; 输    出:			
; 描    述: 对I2C设备写入1个byte数据
;*****************************************************************************************************
.PUBLIC	F_I2C_WriteData			
;~~~~~~~~~~~~~~~~~~~~	
F_I2C_WriteData: ;设备地址长度1 byte; 数据长度1 word
;		STA		R_Wbuff+0
		STX		R_Wbuff1		
		JSR		F_IIC_start		
		LDY		#(C_SlaveAddr+C_Write)
		JSR		F_IIC_Set8bit
;		JSR		F_ACK	
		
;		LDY		R_Wbuff+0
;		JSR		F_IIC_Set8bit
;		JSR		F_ACK
		JSR		F_RACK		
		LDA		R_ACK_Err
		BNE		I2C_Write_Err	; 超时/无应答，跳转到错误处理
			
		LDY		R_Wbuff1		
		JSR		F_IIC_Set8bit	
		JSR		F_RACK                    ; 检测数据应答
		LDA		R_ACK_Err
		BNE		I2C_Write_Err            ; 数据无应答，跳转到错误处理		
		JSR		F_IIC_stop
		
		RTS
	I2C_Write_Err:
		JSR		F_IIC_stop
		RTS
;******************************************************************************************************
; 名    称: F_I2C_ReadData
; 输    入: A->设备的特殊寄存器地址;
; 输    出:	R_Wbuff+0		
; 描    述: 读出I2C设备寄存器1个byte数据
;*****************************************************************************************************
.PUBLIC	F_I2C_ReadData			
;~~~~~~~~~~~~~~~~~~~~
F_I2C_ReadData:
;		STA		R_Wbuff+0
;		PHA
;		TXA
;		PHA
;		TYA
;		PHA	
;		JSR		F_IIC_start         
;		LDY		R_Wbuff+0
;		JSR		F_IIC_Set8bit
;		JSR		F_ACK
;		JSR		F_IIC_stop		
		JSR		F_IIC_start ; 重新启动I2C总线
		LDY		#(C_SlaveAddr+C_Read)
		JSR		F_IIC_Set8bit
;		JSR		F_ACK	
		JSR		F_RACK
		LDA		R_ACK_Err
		BNE		I2C_Write_Err	; 超时/无应答
			
		JSR		F_IIC_get8bit
		STY		R_SaveData+0
		JSR		F_ACK	
		
		JSR		F_IIC_get8bit
		STY		R_SaveData+1
		JSR		F_ACK
		
		JSR		F_IIC_get8bit
		STY		R_SaveData+2
		JSR		F_ACK		
		
		JSR		F_IIC_get8bit
		STY		R_SaveData+3
		JSR		F_ACK	
		
		JSR		F_IIC_get8bit
		STY		R_SaveData+4
		JSR		F_ACK		
		
		JSR		F_IIC_get8bit
		STY		R_SaveData+5
		JSR		F_NACK
		
		JSR		F_IIC_stop
		

	;-------------------
;		PLA
;		TAY
;		PLA
;		TAX
;		PLA	
			RTS
		
	

;============================================================================================================
.END

