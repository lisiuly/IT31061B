#ifndef __I2C_H__  // 头文件保护宏，防止重复包含
#define __I2C_H__

// 针对嵌入式系统的类型定义（如果已有stdint.h，可直接用uint8_t/uint16_t）
typedef unsigned char   uint8_t;
typedef unsigned short  uint16_t;
typedef unsigned int    uint32_t;

/******************************************
 * 外部全局变量声明 (对应汇编.External)
 ******************************************/
// PAGE0段 - 读写缓冲区
extern uint8_t R_Wbuff[];

// PAGE0段 - IO控制数据映射表
extern uint8_t IOC_Datmap[];

// IO方向寄存器映射（B/IOC/IOD/IOA端口）
extern volatile uint8_t *P_IOB_DIR_Map;
extern volatile uint8_t *P_IOC_DIR_Map;
extern volatile uint8_t *P_IOD_DIR_Map;
extern volatile uint8_t *P_IOA_DIR_Map;

extern volatile uint8_t *P_IOA_Attrib_Map;
// 保存数据的全局变量
extern uint8_t R_SaveData[];

/******************************************
 * 外部函数声明 (对应汇编.External)
 ******************************************/
// I2C(IIC)核心操作函数
extern void F_IIC_start(void);        // 发送I2C起始信号
extern void F_IIC_stop(void);         // 发送I2C停止信号
extern void F_IIC_Set8bit(uint8_t dat);  // 发送8位数据
extern uint8_t F_IIC_get8bit(void);   // 接收8位数据
extern void F_ACK(void);              // 发送ACK应答
extern void F_NACK(void);             // 发送NACK非应答
extern void F_RACK(void);             // 接收ACK应答

// SDA引脚方向/电平控制
extern void S_SDA_InF(void);          // SDA引脚设置为输入模式
extern void S_SDA_OutL(void);         // SDA引脚输出低电平

// SCL/SDA引脚电平控制函数
extern void B_SCL_F(void);            // SCL引脚设置（具体逻辑需看汇编实现）
extern void B_SDA_F(void);            // SDA引脚设置（具体逻辑需看汇编实现）
extern void B_SCL_1(void);            // SCL引脚置1
extern void B_SDA_1(void);            // SDA引脚置1



// 注：原汇编中的F_u16_DIV_a函数被注释，如需启用请取消注释并补充类型
// extern uint16_t F_u16_DIV_a(uint16_t a, uint16_t b);  // 16位除法函数（参数类型为推测）

#endif  // __I2C_H__