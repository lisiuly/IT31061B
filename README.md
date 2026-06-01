# IT31061B 室内外温湿度接收主机固件工程

## 1. 项目定位

IT31061B 是一个真实产品固件工程，对应一款带 LCD 显示、支持 433MHz ASK 三通道室外发射器的室内外温湿度接收主机。工程基于 Generalplus GPL813 平台开发，核心能力包括室内温湿度采集、三通道 RF 接收与配对、LCD 当前值显示、趋势图标、低电检测、按键交互、背光和蜂鸣器控制。

- 产品功能维护与固件迭代
- RF 协议、同步窗口、掉码规则与长接收逻辑排查
- LCD 显示链、趋势、低电与按键行为对规格验证

当前仓库的产品主链已经裁剪为标准显示页版本，重点保留以下功能：

- 室内当前温湿度显示
- 室外三通道 RF 温湿度显示
- CH 手动切换与 Auto 轮显
- C/F 切换
- 背光、蜂鸣器、低电与趋势图标


## 2. 规格整理

### 2.1 基本功能

- 2 个功能键：`C/F`、`CH`
- 1 个触摸键：`LIGHT`
- 支持 `433MHz ASK` 室外发射器接收，最多 3 个通道
- 支持室内/室外温湿度显示
- 支持温度单位 `C/F` 切换
- 支持温湿度趋势显示
- 支持背光 8 秒
- 支持主机低电与发射器低电图标显示

### 2.2 测量与显示范围

- 室内温度显示范围：`-9.9 C ~ +50.0 C`
- 室内华氏显示范围：详细规则段写为 `+14.0 F ~ +122 F`
- 室外温度显示范围：`-40.0 C ~ +70.0 C`
- 室外华氏显示范围：`-40.0 F ~ +158.0 F`
- 室内/室外湿度显示范围：`1%RH ~ 99%RH`
- 温度分辨率：`0.1`
- 湿度分辨率：`1%RH`
- 室内采样周期：`60 秒`
- 室外更新周期：由 RF 同步接收规则决定

说明：规格摘要里室内华氏下限还出现过 `+14.2 F` 的写法，而详细检测规则写的是 `+14.0 F`。当前代码显示边界建议按详细规则再核一次实物。

### 2.3 页面与交互逻辑

- 标准模式下，短按 `C/F` 切换温度单位
- 标准模式下，短按 `CH` 切换 `CH1 -> CH2 -> CH3 -> Auto`
- 标准模式下，长按 `CH` 2 秒以上清当前通道并进入 3 分钟长接收
- 标准模式下，短按 `LIGHT` 点亮背光 8 秒

当前代码主链只保留标准页，不再驱动旧的 history、48hr、Mold 或 setting 页面。

### 2.4 上电与 RF 接收逻辑

- 主机装电池后，LCD 全显示约 3 秒
- 上电时发出 1 声 BI，并在最后 1 秒点亮背光
- 上电后自动进入 3 分钟 RF 长接收模式
- 长接收期间 RF 图标以 `1Hz` 闪烁，自动扫描接收 3 个通道
- 3 分钟内若收满 3 个通道，则提前退出长接收
- 首次配对成功后，进入常规同步接收模式

常规同步规则按规格整理如下：

- `CH1` 每 `57 秒` 同步一次
- `CH2` 每 `67 秒` 同步一次
- `CH3` 每 `79 秒` 同步一次
- 单次接收窗口规格写为最长 `4 秒`
- 收到有效包后立即关闭接收窗口
- 连续三次接收失败后，RF 图标熄灭，但保留上一笔有效温湿度数值

### 2.5 掉码与重试规则

- 连续 `60 分钟` 接收失败：对应通道进入 `3 分钟` 长接收，不清除已配对 ID
- 若重新收到同 ID，恢复同步接收
- 若仍未收到，该通道户外温湿度显示 `--.- / --%` 闪烁，并关闭同步接收
- 连续 `120 分钟` 接收失败后，继续按小时级策略重复长接收，总共重试 3 次
- 只有手动长按 `CH` 清通道或复位时，才清除通道 ID 并允许重新接收新发射器

### 2.6 趋势、背光与低电说明

- 温度连续累计变化超过 `1.0 C / 1.8 F` 时显示升降趋势
- 温度 1 小时内变化不超过阈值时显示平稳趋势
- 湿度连续累计变化超过 `5%RH` 时显示升降趋势
- 湿度 1 小时内变化不超过阈值时显示平稳趋势
- 电池供电时，按 `LIGHT` 点亮背光 8 秒；8 秒内再次按键会续时
- 发射器工作电压低于 `2.5V` 时，主机在对应通道显示发射器低电图标
- 规格图示里主机低电显示门槛写为 `2.6V`

## 3. 当前代码与规格对应关系

### 3.1 主循环与时基

- [DEMO/Startup.asm](DEMO/Startup.asm)：负责上电初始化、全显、背光时序、主循环、睡眠与唤醒
- `F_2HzWakeUp` 挂接 RF 的半秒调度入口 `F_RF_ServiceHalfSec`
- 主循环按 `RF pending parse -> KeyScan -> PlayKeyTone -> Display` 顺序推进

### 3.2 室内温湿度链路

- [DEMO/GXHTV4/GXHTV4.asm](DEMO/GXHTV4/GXHTV4.asm)：负责传感器原始数据读取与 C/F 换算
- [DEMO/I2C/D_I2C.asm](DEMO/I2C/D_I2C.asm)：软件 I2C 驱动，当前硬件固定 `PD3=SCL`、`PD4=SDA`
- [DEMO/Alarm/Alarm.asm](DEMO/Alarm/Alarm.asm)：负责室内当前温湿度缓存、趋势与显示前缓冲

### 3.3 室外 RF 链路

- [DEMO/RF/RF.asm](DEMO/RF/RF.asm)：负责 RF 状态机、三通道配对、同步窗口、长接收、掉码分级、趋势缓存和通道轮显
- 当前 RF 解码主链采用 `36bit` 帧格式，`MSB first`
- 先认停止位起帧，再把后续低脉宽翻成 `bit1 / bit0`
- 必须连续两帧完全一致才允许落库
- 每个通道分别维护 `Valid / LowBat / Lost / NeedPair / ManualRetry` 状态位、绑定 ID、温湿度值和趋势状态

### 3.4 LCD 显示链路

- [DEMO/LCD/LCD_Display.asm](DEMO/LCD/LCD_Display.asm)：当前产品标准页显示入口
- 室内值来自 Alarm/GXHTV4 缓存
- 室外值来自当前 `R_RFViewChannel` 指向的 RF 通道缓存
- RF 图标、CH 图标、Loop 图标、低电图标与趋势图标都在这个模块集中处理
- [DEMO/LCD/LCD_Display.tab](DEMO/LCD/LCD_Display.tab)：LCD 段位和图标映射表

### 3.5 按键、背光与蜂鸣器

- [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm)：按键扫描、短按/长按分发、背光倒计时和键音触发
- 当前键位扫描映射为：`PE0 = LIGHT`、`PE1 = C/F`、`PE2 = CH`
- [DEMO/Int_Vec.asm](DEMO/Int_Vec.asm)：负责 `2Hz / 128Hz / TimeBaseB` 等中断处理，蜂鸣器输出走 `PB1`
- 背光输出走 `PB0`

## 4. 工程结构

仓库根目录主要由以下部分组成：

- [DEMO](DEMO)：主固件工程目录
- [IT31061B.txt](IT31061B.txt)：规格摘要、接收规则、交互逻辑与调试记录
- [CMT2210LC规格书.pdf](CMT2210LC规格书.pdf)：RF 相关器件资料
- [RF通讯（发码）协议.doc](RF通讯（发码）协议.doc)：发码协议说明
- [LCD](LCD)：LCD 资源文件
- [原理图](原理图)：硬件原理图资料
- [资料](资料)：补充文档和图纸
- [烧录文件](烧录文件)：烧录相关资源

[DEMO](DEMO) 目录中的核心模块如下：

- [DEMO/Startup.asm](DEMO/Startup.asm)：上电、主循环、睡眠与唤醒
- [DEMO/Int_Vec.asm](DEMO/Int_Vec.asm)：中断入口与 2Hz / 128Hz / 蜂鸣器处理
- [DEMO/RF/RF.asm](DEMO/RF/RF.asm)：RF 解码、同步、长接收、掉码与三通道状态机
- [DEMO/Alarm/Alarm.asm](DEMO/Alarm/Alarm.asm)：室内温湿度数据与趋势链路
- [DEMO/LCD/LCD_Display.asm](DEMO/LCD/LCD_Display.asm)：LCD 数值和图标显示
- [DEMO/LCD/LCD_Display.tab](DEMO/LCD/LCD_Display.tab)：LCD 段位/图标映射
- [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm)：按键、背光和键音
- [DEMO/GXHTV4/GXHTV4.asm](DEMO/GXHTV4/GXHTV4.asm)：传感器读数与温度转换
- [DEMO/I2C/D_I2C.asm](DEMO/I2C/D_I2C.asm)：软件 I2C 驱动
- [DEMO/RTC/RTC.asm](DEMO/RTC/RTC.asm)：RTC 与时基逻辑
- [DEMO/sys/Macro.inc](DEMO/sys/Macro.inc)：宏定义、端口初始化和中断初始化
- [DEMO/GPMakefile](DEMO/GPMakefile)：工程构建脚本

## 5. 硬件与 I/O 映射

结合规格和当前代码，主要口线映射如下：

| 引脚 | 功能 | 代码落点 |
| --- | --- | --- |
| `PB0` | 背光 | [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm) |
| `PB1` | 蜂鸣器 | [DEMO/Int_Vec.asm](DEMO/Int_Vec.asm) |
| `PE0` | `LIGHT` | [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm) |
| `PE1` | `C/F` | [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm) |
| `PE2` | `CH` | [DEMO/KEY/KEY.asm](DEMO/KEY/KEY.asm) |
| `PD0` | `RF_EN`，低有效 | [DEMO/RF/RF.asm](DEMO/RF/RF.asm) |
| `PD1` | RF 数据采样输入 | [DEMO/RF/RF.asm](DEMO/RF/RF.asm) |
| `PD3` | 传感器 I2C `SCL` | [DEMO/I2C/D_I2C.asm](DEMO/I2C/D_I2C.asm) |
| `PD4` | 传感器 I2C `SDA` | [DEMO/I2C/D_I2C.asm](DEMO/I2C/D_I2C.asm) |

## 6. 构建与调试

### 6.1 当前建议的验证方式

当前已验证可用的是单文件汇编方式，适合对 RF、LCD、Startup、KEY 等模块做快速回归检查。

示例命令：

```powershell
Set-Location E:\project\IT31061B\DEMO
& "C:\Program Files (x86)\Generalplus\GPIDE_6502 1.3.0\Tools\Compiler\6502\6502_Asm.exe" RF\RF.asm -p GPL813_SERIES -p INS_LIB_NOT_EXIST -Tn -l -d -s -SC -I E:\project\IT31061B\DEMO -i .\GPL813P01Cx_ChipInfo.conf
```

### 6.2 GPMakefile 说明

- [DEMO/GPMakefile](DEMO/GPMakefile) 是工程级构建脚本
- 当前仓库里 `mingw32-make -f GPMakefile` 仍可能因为依赖文件名大小写和路径写法而失败
- 因此在修复构建脚本前，建议优先使用 GPIDE 自带 `6502_Asm.exe` 做单文件验证

## 7. 需要继续核对的规格与实现差异

整理代码和规格后，当前还值得继续核对的点包括：

- 规格里的室内华氏下限存在 `14.2F` 与 `14.0F` 两种写法，建议统一边界定义
- 规格描述的常规同步接收窗口为最长 `2 秒`，而当前 RF 代码常量已经扩到 `4 秒`，虽然收到有效包会提前关窗，但仍需确认是否接受这个实现差异
- 规格图示里的主机低电门槛为 `2.6V`，而当前上电/唤醒代码注释显示把 `P_LVD_Ctrl` 统一写到了 `2.4V` 档位
- [DEMO/LCD/LCD_Display.tab](DEMO/LCD/LCD_Display.tab) 里仍保留多处 `temporary placeholders / replace with real mapping` 注释，说明 LCD 资源表仍需和当前实物玻璃再做一次最终核对

## 8. 适用场景

这份 README 适合以下用途：

- 新接手工程时快速理解代码结构
- 根据规格书核对 RF、显示、按键和掉码规则
- 做单文件汇编验证和问题定位时作为入口索引
- 给后续维护人员统一“规格描述”和“代码落点”的语义