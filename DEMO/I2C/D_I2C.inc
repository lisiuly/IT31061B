;===========================================
;External  global variable Area
;------------------------------
.External PAGE0 R_Wbuff
.External PAGE0 IOC_Datmap
.External		P_IOB_DIR_Map
.External		P_IOC_DIR_Map
.External		P_IOD_DIR_Map
.External		P_IOA_DIR_Map
.EXTERNAL		R_PortD_Data_Buf
.EXTERN		R_SaveData
;===========================================
;External  Funtion Area
;------------------------------
.External	F_IIC_start
.External	F_IIC_stop
.External	F_IIC_Set8bit
.External	F_IIC_get8bit
.External	F_ACK
.External	F_NACK
.External	F_RACK
.External	S_SDA_InF
.External	S_SDA_OutL

.External		B_SCL_F
.External		B_SDA_F
.External		B_SCL_1
.External		B_SDA_1


.External		F_I2C_Initial
.External		F_I2C_WriteData
.External		F_I2C_ReadData
;.External		F_u16_DIV_a

C_SlaveAddr: .EQU		10001000b;00100000b; [RDA5708]; //00100000b;[QN8035];//10100000b;[24c01];//10001010b;[STHTV4]	;Æ÷¼þµØÖ· 
C_Write:	 .EQU		00000000b
C_Read:		 .EQU		00000001b
