# 用法手册——基于光纤的时钟同步

## 0. Introduction

这里要解决的问题是两个 FPGA 板之间的时钟同步。需要同步的不只是时钟频率，还有时间戳 (timestamp，或者说计数器)，因为 FPGA 打包数据的时候需要带有事件的绝对时间。
一种直接的方案是用时钟分发，用同轴线传输时钟。这种方法可以确保时钟频率相同、相位相同，不过还需要有个 reset 信号来对齐两个 FPGA 之间的时间戳。
这里要介绍的方式是通过**光纤通信** (GT 通信) 来进行时钟同步。

## 1. 整体原理简介

需要同步的总共有三个量：频率、时间戳、相位。

1. 频率同步：FPGA 在进行 GT 通信的时候会从高速串行数据中恢复出时钟 `rxoutclk`。所以光纤通信可以天然实现频率同步。
2. 时间戳同步：简单来说是通过光纤通信发送数据告诉对方（master 告诉 slave）现在时间戳是多少。由于光纤通信存在延迟（光纤传播速度 1m/5ns，GT 处理速度 ~ 330ns），所以需要通过类似 PTP (precise time protocol) 协议的方式测量出具体的时间延迟。
3. 相位同步：时间戳同步只能把时钟同步的精度做到一个时钟周期以内，对于 125MHz 时钟，也就是 8ns。对于 ns 级时钟同步，还需要测量 master 与 slave 时钟之间的相位差。这里通过 TDC 来测量相位差。

引入两个名词：master 和 slave，分别为时钟同步的发起方和被同步的一方。一个 master 可以对多个 slaves。

### 1.1. PTP 通信

PTP 通信过程：

1. Master 发一条消息给 Slave。此时 Master 记录自己的时间戳 `t1`。
2. Slave 收到 Master 的消息。此时 Slave 记录自己的时间戳 `t2`。
3. Slave 往 Master 发消息。此时 Slave 记录自己的时间戳 `t3`。
4. Master 收到 Slave 的消息。此时 Master 时间戳 `t4`。

由此一发一收，就可以知道一来一回总共延迟了多久：`t_delay = ((t4-t1)-(t3-t2))/2`。

知道了延迟之后，Master 需要再进行一次 PTP 通信，不过这次是告诉 Slave 去修改时间戳，比如说，修改为 `t1 + t_dealy`。

### 1.2. 相位差测量

把 `t1`, `t2`, `t3`, `t4` 这几个信号接到 TDC 上，可以测出精确的时间差。

测出来具体相位差之后，上位机记录这个差值，并在软件层面上进行数据处理时修正。

## 2. 固件用法

Top module 里面需要例化两个 modules: `GTX wizard IP` 和 `time_sync_manager`。前者是 vivado IP，后者是时钟同步代码。

### 2.1. GTX wizard IP config

- GT selection
  - GT Type: GTX
  - Share Logic: 都行，例程选的是 in example design
- Line rate, refclk selection
  - protocol: start from scratch
  - Line rate (Gbps): 1.25 (千兆网, rxoutclk is 62.5MHz) or 2.5 (if want 125MHz rxoutclk)
  - reference clock (MHz): 125
  - RX 跟 TX 一样
  - 左下角的图框可以交互，从下往上依次是 GT115_ch0 到 GT118_ch3。核心板上的 125MHz 参考时钟是 REFCLK_Q2 (GT117_refclk1)。TX 和 RX 都用 CPLL。
  - 下面三个 (advanced..., PRBS..., Vivado...) 都不选。
- Encoding and clocking
  - External data width (bits): 16
  - encoding: 8b/10b
  - Internal data width (bits): 20
  - RX 跟 TX 一样
  - DRP/system clock frequency (MHz): 100
  - Optional ports 只勾选 `RXCHARISCOMMA` 和 `RXCHARISK`
  - Synchronization and Clocking:
    - tx 和 rx buffer 都**不选**
    - tx 和 rx buffer bypass mode 都选 auto
    - TXUSRCLK source: TXOUTCLK
    - RXUSRCLK source: RXOUTCLK
- Comma alignment and Equalization
  - rx comma detection:
    - use comma detection 勾选
    - comma value: K28.5
    - comma mask: `0001111111`。（前三个 bit 设为 0）
    - decode valid comma only 不选
    - combine... 不选
    - align to: any byte boundary
  - optional ports: 全都不选
  - 其他保持默认
  - optional ports: 全都不选
- PCIE, SATA, PRBS
  - 全都不选，填空题保持默认
- 其余保持默认

编译选 out of context IP 就行。

打包一下之后 GTX module 有这些端口：

<font size=2>

``` verilog
(
// 100MHz DRP clock
input  wire clk_drp_100M,

// 125MHz GTX ref clock
input  wire clk_gtx_p,
input  wire clk_gtx_n,
output wire clk_gtx_125M,

// GTX IO
output wire gtx_tx_p,
            gtx_tx_n,
input  wire gtx_rx_p,
            gtx_rx_n,

// 125MHz TX, RX out clock
output wire clk_txoutclk_bufg,
output wire clk_rxoutclk_bufg,

// GTX data interface
input  wire [15:0] gt_tx_data,
input  wire gt_tx_data_valid,
output wire [15:0] gt_rx_data,
output wire gt_rx_data_valid,

// signals for alignment
input  wire rx_pma_rst_n,       // rx pma reset
output wire gtx_cpll_is_lock,   // pll lock
output wire rx_reset_done,      // rx reset status
output wire [1:0] rx_data_is_comma,
output wire gtx_rx_error        // rx error (not in table)
);
```

</font>

100MHz 时钟由 200MHz 分频产生。
125MHz 时钟通过 `IBUFDS_GTE2` 进行 buffer 给到 GTX Wizard IP。
`txoutclk` 和 `rxoutclk` 分别是 TX 发送数据的时钟和 RX 接收数据的时钟，`rxoutclk` 也就是 GT 恢复出来的时钟了。这俩时钟频率为 62.5MHz for 1.25Gbps，或 125MHz for 2.5Gbps。
下面两部分 (GTX data interface 和 signals for alignment) 都直接连到 `time_sync_manager` 上。除了 pll lock, 这个没用。

### 2.2 time_sync_manager

整体结构：
``` yaml
- time_sync_manager # main
    - ptp_manager   # the most important part
        - buffer_timestamps         # buffer of t2, t3, t4
        - buffer_timestamp_to_uart  # send timestamp to 8-bit width fifo, such as uart
        - tdc_phase_measure         # tdc to measure t1, t2, t3, t4
            - tdc_lite
```

端口：

<font size=2>

``` verilog
(
input  wire clk_txoutclk_bufg,
input  wire clk_rxoutclk_bufg,
input  wire clk_sys_400M,
input  wire clk_drp_100M,
input  wire clk_uart,               // ptp output results by fifo

// gtx data
output reg  [15:0] gt_tx_data,
output reg  gt_tx_data_valid,
input  wire [15:0] gt_rx_data,
input  wire gt_rx_data_valid,
input  wire [ 1:0] gt_rx_data_is_comma,

// *user data*
input  wire [15:0] user_tx_data,
input  wire user_tx_data_valid,
output wire [15:0] user_rx_data,
output wire user_rx_data_valid,

// timestamp for master and slave
output wire [63:0] timestamp_tx,    // master timestamp
output wire [63:0] timestamp_rx,    // slave timestamp

// PTP, only master uses these signals
input  wire ptp_start,              // rising edge trigger
input  wire [15:0] ptp_value,       // delay value
input  wire ptp_value_valid,        // delay valid
input  wire [63:0] tx_load_value,   // master timestamp reset value
input  wire tx_load,                // master timestamp reset

// output fifo interface, only master uses these signals
output wire [7:0] uart_data_out,
input  wire uart_read_enable,
output wire uart_read_empty,
output wire uart_read_valid,

// data alignment and pma reset
input  wire gt_rx_error,
output reg  gt_pma_rst_n,
input  wire gt_rx_rst_done,

// debug
output wire [3:0] flags
);
```

</font>

- 时钟：
  - `txoutclk`, `rxoutclk` 是 GTX module 出来的，GT
  通信用的时钟。
  - `sysclk_400M` 是 TDC 用的时钟
  - `drpclk_100M` 是给 GTX PMA reset 用的时钟。
  - `clk_uart` 是模块自身产生的数据的输出用的时钟，只有 master 用到，时钟频率随意。PTP 通信过程产生的数据会转到 fifo 里面，fifo 数据通过这个时钟输出。
- gtx data：接到 GTX module 上。
- user data: 用户数据，外部可以套个 fifo。
- timestamp for master and slave: master 和 slave 的时间戳，也就是 `txoutclk` 和 `rxoutclk` 的计数器。
- PTP:
  - `ptp_start`: master 发起一次 PTP 通信的触发信号。
  - `ptp_value` 和 `ptp_value_valid`: PTP 通信有两种模式：当 `ptp_value_valid = 0`，为一发一收；反之当 `ptp_value_valid = 1`，为 master 告诉 slave 修改时间戳为 `t1 + ptp_value`。PTP 通信需要很多次一发一收来做统计，以及一次修改时间戳。
  - `tx_load` 是 master reset 自己的 tx 时间戳用的，reset 是高有效，可以都给 0。
- output fifo interface: 时钟同步过程中的数据，每次总共是 48*8-bit。包含了 master 和 slave 的数据，由 master 输出。
- data alignment and pma reset: 接到 GTX module 上。
- debug flags: t1, t2, t3, t4 这几个时刻。

