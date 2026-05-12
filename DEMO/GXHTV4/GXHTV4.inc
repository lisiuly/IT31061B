;==================================================================================
; The information contained herein is the exclusive property of
; Generalplus Technology Co. And shall not be distributed, reproduced,
; or disclosed in whole in part without prior written permission.
;       (C) COPYRIGHT 2017   Generalplus TECHNOLOGY CO.
;		ALL RIGHTS RESERVED
; The entire notice above must be reproduced on all authorized copies.
;==================================================================================
;==================================================================================
;==================================================================================
;==========================================
; External declare area
;==========================================
.External	F_ReadGXHTV4Data
.External	F_CAL_HEX_BCD2
.External	F_CHANGE_CF

.External	R_TempFlag
D_TempF			equ	0x01	;1 for 'F;  0 for 'C ，上电默认为F此Bit需置１
D_TempError		equ	0x02	;温度出错标志
D_TempFReg		equ	0x04	;TempF for -
D_WithRTRH		equ	0x80	;带湿度功能，上电需定义

.External	TEMP_INTEGAH			;温度整数和符号位
.External	TEMP_INTEGAL			;温度小数部分
.External	HUM				;湿度整数部分

.External	OUT_H				;HEX转BCD 时，最高位
.External	OUT_M				;HEX转BCD 时，第二位
.External	OUT_L				;HEX转BCD 时，第三位 低4bit 为温度小数部分
.External	X_M					;CF计算输出高字节
.External	X_L					;CF计算输出低字节


