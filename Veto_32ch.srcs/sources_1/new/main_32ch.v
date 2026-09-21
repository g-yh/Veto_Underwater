`timescale 1ns / 1ps

module main_32ch (
    // FPGA 200M时钟
    input clk_200M_p,
    input clk_200M_n,

    //--------------------------------
    // Si5345
    //--------------------------------
    // Si5345 SPI
    output si5345_cs_n,
    inout  si5345_sdio,
    output si5345_sclk,

    // 提供给Si5345 IN0的125M差分时钟
    output si5345_clk_in0_p,
    output si5345_clk_in0_n,

    // Si5345控制
    output si5345_i2c_sel,
    output si5345_in_sel0,
    output si5345_in_sel1,
    output si5345_oeb,
    output si5345_rstb,
    input  si5345_lolb,

    //--------------------------------
    // AD9253
    //--------------------------------
    // AD9253 SPI
    output [7:0] ad9253_cs_n,
    inout        ad9253_sdio,
    output       ad9253_sclk,

    // AD9253 控制
    output ad9253_sync,
    output ad9253_pdwn,

    // AD9253 数据
    input [63:0] ad9253_data_p,
    input [63:0] ad9253_data_n,
    input [ 7:0] ad9253_fco_p,
    input [ 7:0] ad9253_fco_n,
    input [ 7:0] ad9253_dco_p,
    input [ 7:0] ad9253_dco_n,

    //--------------------------------
    // DAC128S085
    //--------------------------------
    output [7:0] dac128s085_cs_n,
    inout  [7:0] dac128s085_sdio,
    output [7:0] dac128s085_sclk,

    //--------------------------------
    // MAX40026
    //--------------------------------
    input [31:0] max40026_p,
    input [31:0] max40026_n,

    //--------------------------------
    // GT
    //--------------------------------
    input wire clk_gtx_125M_p,
    input wire clk_gtx_125M_n,

    output wire clk_125M_en,

    input  wire SFP1_rx_p,  // SFP receive
    SFP1_rx_n,
    output wire SFP1_tx_p,  // SFP send
    SFP1_tx_n,

    // input  wire SFP2_rx_p,  // SFP receive
    // SFP2_rx_n,
    // output wire SFP2_tx_p,  // SFP send
    // SFP2_tx_n,

    // input wire gt_refclk_15625_p,
    // input wire gt_refclk_15625_n,

    output wire SFP_tx_disable1,  // set low
    output wire SFP_tx_disable2,  // set low

    output wire gt_link_up_out_led    // GT link established
);

    localparam ADC_NUM = 4'd8;
    localparam CHANNEL_NUM = 4'd4;
    localparam TRIG_TOTAL = 16'd57;
    localparam TRIG_PRE = 16'd10;
    localparam HEAD_LEN = 16'd7;

    assign clk_125M_en = 1;
    assign SFP_tx_disable1 = 0;
    assign SFP_tx_disable2 = 0;
    assign gt_link_up_out_led = gt_link_up;
    // UART 慢控已改为 GT 慢控，uart 端口不再使用
    assign uart_tx = 1'b1;

    wire rst_n;
    wire rst_n_used;
    wire trig_rst_n;
    (* dont_touch="true" *) vio_0 vio_inst (
        .clk       (clk_200M),            // input wire clk
        .probe_out0(rst_n),
        .probe_out1(trig_rst_n)
    );

    // assign rst_n = 1'b1;

    //--------------------------------
    // clock manager
    //--------------------------------
    wire clk_400M;
    wire clk_200M;
    wire clk_15625M;
    wire clk_125M;
    wire clk_100M;
    wire clk_20M;

    wire clk_gtx_125M;

    clock_manager instance_clock_manager (
        .clk_200M_p(clk_200M_p),
        .clk_200M_n(clk_200M_n),
        .clk_gtx_125M_p(clk_gtx_125M_p),
        .clk_gtx_125M_n(clk_gtx_125M_n),

        .clk_400M(clk_400M),
        .clk_200M(clk_200M),
        .clk_125M(clk_125M),
        .clk_100M(clk_100M),
        .clk_20M(clk_20M),
        .clk_gtx_125M(clk_gtx_125M)
    );

    //--------------------------------
    // si5345
    //--------------------------------
    // 定义Si5345硬件控制信号
    assign si5345_i2c_sel = 1'b0;
    assign si5345_oeb = 1'b0;
    assign si5345_rstb = 1'b1;

    // 125M时钟单端转差分
    OBUFDS #(
        .SLEW("FAST")
    ) instance_obufds_si5345_clk_in0 (
        .I (clk_125M),
        .O (si5345_clk_in0_p),
        .OB(si5345_clk_in0_n)
    );

    wire        si5345_spi_start;
    wire        si5345_rw;
    wire [15:0] si5345_data_in;
    wire        si5345_spi_busy;
    wire        si5345_spi_done;

    wire        si5345_sdio_in;
    wire        si5345_sdio_out;
    wire [15:0] si5345_data_out;
    wire [ 3:0] si5345_bit_cnt;
    wire [ 1:0] si5345_spi_state;

    spi_3wire_master_16bit #(
        .CLK_DIV(100)
    ) si5345_spi_inst (
        .clk    (clk_rxoutclk_bufg),
        .rst_n  (rst_n),
        .start  (si5345_spi_start),
        .rw     (si5345_rw),
        .data_in(si5345_data_in),
        .busy   (si5345_spi_busy),
        .done   (si5345_spi_done),
        .sclk   (si5345_sclk),
        .sdio   (si5345_sdio),

        // 调试信号连接
        .sdio_in  (si5345_sdio_in),
        .sdio_out (si5345_sdio_out),
        .shift_reg(si5345_data_out),
        .bit_cnt  (si5345_bit_cnt),
        .state    (si5345_spi_state)
    );

    //--------------------------------
    // ad9253
    //--------------------------------
    assign ad9253_sync = 0;
    assign ad9253_pdwn = 0;

    wire                               ad9253_spi_start;
    wire                               ad9253_rw;
    wire [                        7:0] ad9253_data_in;
    wire                               ad9253_spi_busy;
    wire                               ad9253_spi_done;
    wire                               ad9253_sdio_in;
    wire                               ad9253_sdio_out;
    wire [                        7:0] ad9253_data_out;
    wire [                        2:0] ad9253_bit_cnt;
    wire [                        1:0] ad9253_spi_state;

    // 32个通道的输出数据(每通道高8bit, 低8bit)
    wire [ADC_NUM*CHANNEL_NUM*2*8-1:0] ad9253_data_chx;

    // 定义bitslip控制信号数组
    wire [  ADC_NUM*CHANNEL_NUM*2-1:0] bitslip_chx;

    wire [ADC_NUM*CHANNEL_NUM*2*5-1:0] idelay_tap;
    wire                               idelay_ld;

    // ADC 帧时钟：统一由 GT 接收时钟驱动
    wire adc_fco;
    assign adc_fco = clk_rxoutclk_bufg;

    ad9253_selectio_top ad9253_selectio_top_inst (
        .spi_clk          (clk_rxoutclk_bufg),
        .selectio_ref_clk (clk_200M),
        .rst_n    (si5345_lolb && (&ad9253_config_done) && rst_n),
        .spi_rst_n(rst_n),

        // AD9253 SPI
        .ad9253_sdio     (ad9253_sdio),
        .ad9253_sclk     (ad9253_sclk),
        .ad9253_spi_start(ad9253_spi_start),
        .ad9253_rw       (ad9253_rw),
        .ad9253_data_in  (ad9253_data_in),
        .ad9253_spi_busy (ad9253_spi_busy),
        .ad9253_spi_done (ad9253_spi_done),
        .ad9253_sdio_in  (ad9253_sdio_in),
        .ad9253_sdio_out (ad9253_sdio_out),
        .ad9253_data_out (ad9253_data_out),
        .ad9253_bit_cnt  (ad9253_bit_cnt),
        .ad9253_spi_state(ad9253_spi_state),

        // AD9253 数据 - 使用所有8位数据输入
        .ad9253_data_p(ad9253_data_p),
        .ad9253_data_n(ad9253_data_n),
        .ad9253_dco_p (ad9253_dco_p),
        .ad9253_dco_n (ad9253_dco_n),

        // 32个通道的输出数据
        .ad9253_data_chx(ad9253_data_chx),

        .adc_fco(adc_fco),

        // bitslip控制信号数组
        .bitslip_chx(bitslip_chx),

        .in_delay_tap_in(idelay_tap),
        .idelay_ld      (idelay_ld)
    );

    //--------------------------------
    // dac128s085
    //--------------------------------
    wire [   ADC_NUM-1:0] dac128s085_spi_start;

    wire [ADC_NUM*16-1:0] dac128s085_data_in;
    wire [   ADC_NUM-1:0] dac128s085_spi_busy;
    wire [   ADC_NUM-1:0] dac128s085_spi_done;

    genvar dac_num;
    generate
        for (dac_num = 0; dac_num < 8; dac_num = dac_num + 1) begin : dac_gen
            spi_3wire_master_16bit_negedge #(
                .CLK_DIV(100)
            ) dac128s085_spi_inst (
                .clk    (clk_rxoutclk_bufg),
                .rst_n  (rst_n),
                .start  (dac128s085_spi_start[dac_num]),
                .rw     (0),
                .data_in(dac128s085_data_in[dac_num*16+:16]),
                .busy   (dac128s085_spi_busy[dac_num]),
                .done   (dac128s085_spi_done[dac_num]),
                .sclk   (dac128s085_sclk[dac_num]),
                .sdio   (dac128s085_sdio[dac_num])
            );
        end
    endgenerate

    //--------------------------------
    // max40026
    //--------------------------------
    wire [ADC_NUM*CHANNEL_NUM-1:0] max40026_ch;

    // 差分转单端
    genvar m;
    generate
        for (m = 0; m < ADC_NUM * CHANNEL_NUM; m = m + 1) begin : max40026_input_gen
            IBUFDS #(
                .DIFF_TERM("TRUE"),
                .IBUF_LOW_PWR("TRUE"),
                .IOSTANDARD("DEFAULT")
            ) max40026_ch_ibufds_inst (
                .I (max40026_p[m]),
                .IB(max40026_n[m]),
                .O (max40026_ch[m])
            );
        end
    endgenerate

    //--------------------------------
    // tdc
    //--------------------------------
    wire [11*ADC_NUM*CHANNEL_NUM - 1:0] tdc_raw_rise;
    wire [11*ADC_NUM*CHANNEL_NUM - 1:0] tdc_raw_fall;
    wire [     ADC_NUM*CHANNEL_NUM-1:0] tdc_signal;

    wire [10*ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_in;
    wire [   ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_en;

    wire [     ADC_NUM*CHANNEL_NUM-1:0] cali_flag;
    reg  [                         3:0] cali_cnt;
    reg                                 cali_pulse;

    // IBUFDS_GTE2 ibufds_gte2_inst (
    //     .I    (gt_refclk_15625_p),
    //     .IB   (gt_refclk_15625_n),
    //     .CEB  (1'b0),
    //     .O    (clk_15625M),
    //     .ODIV2()
    // );

    always @(posedge clk_200M or negedge rst_n) begin
        if (!rst_n) begin
            cali_cnt   <= 4'd0;
            cali_pulse <= 1'b0;
        end else begin
            if (cali_cnt == 4'd15) begin
                cali_cnt   <= 4'd0;
                cali_pulse <= 1'b1;  // 输出一个周期脉冲
            end else begin
                cali_pulse <= 1'b0;
                cali_cnt   <= cali_cnt + 1'b1;
            end

        end
    end

    genvar tdc_gen;
    generate
        for (
            tdc_gen = 0; tdc_gen < ADC_NUM * CHANNEL_NUM; tdc_gen = tdc_gen + 1
        ) begin : tdc_generator

            assign tdc_signal[tdc_gen] = cali_flag[tdc_gen] ? cali_pulse : max40026_ch[tdc_gen];

            lib_tdc #(
                .N_carry4   (175),  // 25 carry4 per nanosecond
                .N_bins_bits(10)     // = log2(4*N_carry4)
            ) instance_tdc (
                .clk(adc_fco),  // input clock
                .signal(tdc_signal[tdc_gen]),  // input signal
                .tdc_raw_rise(tdc_raw_rise[tdc_gen*11+:11]),  // tdc output raw result. 1 + N, the first is enable signal
                .tdc_raw_fall(tdc_raw_fall[tdc_gen*11+:11])
            );

            assign tdc_cali_in[tdc_gen*10+:10] = tdc_raw_rise[tdc_gen*11+:10];
            assign tdc_cali_en[tdc_gen]         = tdc_raw_rise[tdc_gen*11+10];
        end
    endgenerate

    //--------------------------------
    // ringbuffer
    //--------------------------------
    wire [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_trig;
    wire [ADC_NUM*CHANNEL_NUM*16-1:0] ringbuffer_out;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_data_valid;

    genvar rb_idx;
    generate
        for (rb_idx = 0; rb_idx < ADC_NUM * CHANNEL_NUM; rb_idx = rb_idx + 1) begin : ringbuffer_gen

            assign ringbuffer_trig[rb_idx] = tdc_raw_rise[11*rb_idx+10] && !fifo_sync_prog_full[rb_idx];

            ringbuffer #(
                .DATA_WIDTH (16),
                .DEPTH      (4096),
                .HEAD_LENGTH(HEAD_LEN),
                .TRIG_PRE   (TRIG_PRE),
                .TRIG_TOTAL (TRIG_TOTAL),
                .CHANNEL_ID (rb_idx)
            ) ringbuffer_inst (
                .clk       (adc_fco),
                .rst_n     (si5345_lolb && (&ad9253_config_done) && rst_n && trig_rst_n),
                .din       (ad9253_data_chx[rb_idx*16+:16]),
                .tdc_data  (tdc_raw_rise[rb_idx*11+:10]),
                .time_cnt  (ptp_timestamp_rx[47:0]),
                .trig      (ringbuffer_trig[rb_idx]),
                .dout      (ringbuffer_out[rb_idx*16+:16]),
                .data_valid(ringbuffer_data_valid[rb_idx])
            );
        end
    endgenerate

    //--------------------------------
    // fifo_sync * 32
    //--------------------------------
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_wr_en;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_rd_en;
    wire [ADC_NUM*CHANNEL_NUM*16-1:0] fifo_sync_dout;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_full;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_empty;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_prog_full;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_prog_empty;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] fifo_sync_valid;

    genvar fs_idx;
    generate
        for (fs_idx = 0; fs_idx < ADC_NUM * CHANNEL_NUM; fs_idx = fs_idx + 1) begin : fifo_sync_gen
            // assign fifo_sync_wr_en[fs_idx] = (fs_idx < 29) ? ringbuffer_data_valid[fs_idx] : 0;
            assign fifo_sync_wr_en[fs_idx] = ringbuffer_data_valid[fs_idx];

            fifo_sync fifo_sync_inst (
                .clk(adc_fco),  // input wire clk
                .srst(~(si5345_lolb && (&ad9253_config_done) && rst_n && trig_rst_n)),  // input wire srst
                .din(ringbuffer_out[fs_idx*16+:16]),  // input wire [15 : 0] din
                .wr_en(fifo_sync_wr_en[fs_idx]),  // input wire wr_en
                .rd_en(fifo_sync_rd_en[fs_idx]),  // input wire rd_en
                .prog_empty_thresh(TRIG_TOTAL + HEAD_LEN),  // input wire [10 : 0] prog_empty_thresh
                .prog_full_thresh(11'd2048 - (TRIG_TOTAL + HEAD_LEN)),  // input wire [10 : 0] prog_full_thresh
                .dout(fifo_sync_dout[fs_idx*16+:16]),  // output wire [15 : 0] dout
                .full(fifo_sync_full[fs_idx]),  // output wire full
                .empty(fifo_sync_empty[fs_idx]),  // output wire empty
                .prog_full(fifo_sync_prog_full[fs_idx]),  // output wire prog_full
                .prog_empty(fifo_sync_prog_empty[fs_idx]),  // output wire prog_empty
                .valid(fifo_sync_valid[fs_idx])  // output wire valid
            );
        end
    endgenerate

    //--------------------------------
    // arbiter
    //--------------------------------
    wire [15:0] arbiter_out;
    wire        fifo_async_wr_en;
    wire [ 4:0] current_ch;

    arbiter_32ch #(
        .TRIG_WIDTH(16),
        .ADC_NUM(ADC_NUM),
        .CHANNEL_NUM(CHANNEL_NUM)
    ) arbiter_32ch_inst (
        .clk(adc_fco),  // input wire clk
        .rst_n(si5345_lolb && (&ad9253_config_done) && rst_n && trig_rst_n),  // input wire rst_n
        .trig_total(TRIG_TOTAL + HEAD_LEN),  // input wire [15:0] trig_total
        .pre_fifo_empty(fifo_sync_prog_empty),  // input wire [3:0] fifo_empty
        .post_fifo_full(fifo_async_prog_full),  // input wire post_fifo_full
        .data(fifo_sync_dout),  // input wire [511:0] data
        .pre_fifo_rd_en(fifo_sync_rd_en),  // output reg [3:0] fifo_rd_en
        .data_out(arbiter_out),  // output reg [15:0] data_out
        .post_fifo_wr_en(fifo_async_wr_en),  // output reg fifo_wr_en
        .current_ch(current_ch)  // output reg [4:0] current_ch
    );

    // --------------------------------
    // fifo_async_gt
    // --------------------------------
    reg         fifo_async_rd_en;
    wire [15:0] fifo_async_data_out;
    wire        fifo_async_full;
    wire        fifo_async_empty;
    wire        fifo_async_prog_full;
    wire        fifo_async_prog_empty;

    fifo_async_gt inst_fifo_async_gt (
        .rst(~(si5345_lolb && (&ad9253_config_done) && rst_n && trig_rst_n)),
        .wr_clk(adc_fco),
        .rd_clk(clk_txoutclk_bufg),
        .din(arbiter_out),
        .wr_en(fifo_async_wr_en),
        .rd_en(fifo_async_rd_en),
        .prog_empty_thresh((TRIG_TOTAL + HEAD_LEN)),
        .prog_full_thresh(11'd2048 - (TRIG_TOTAL + HEAD_LEN)),
        .dout(fifo_async_data_out),
        .full(fifo_async_full),
        .empty(fifo_async_empty),
        .prog_full(fifo_async_prog_full),
        .prog_empty(fifo_async_prog_empty),
        .wr_rst_busy(),
        .rd_rst_busy()
    );



    // --------------------------------
    // gtx_interface
    // --------------------------------
    wire rx_pma_rst_n;
    wire rx_reset_done;

    wire clk_txoutclk_bufg;
    wire clk_rxoutclk_bufg;

    wire [15:0] gt_tx_data;
    wire gt_tx_data_valid;
    wire [15:0] gt_rx_data;
    wire gt_rx_data_valid;

    wire gtx_cpll_is_lock;
    wire [1:0] rx_data_is_comma;
    wire gtx_rx_error;

    interface_gtx instance_gtx_interface(
        // system
        .rx_pma_rst_n   (rx_pma_rst_n),

        // 100MHz DRP clock
        .clk_drp_100M   (clk_100M),

        // 125MHz GTX ref clock
        .clk_gtx_125M   (clk_gtx_125M),

        // GTX IO
        .gtx_tx_p       (SFP1_tx_p),
        .gtx_tx_n       (SFP1_tx_n),
        .gtx_rx_p       (SFP1_rx_p),
        .gtx_rx_n       (SFP1_rx_n),
        
        // 125MHz TX, RX out clock
        .clk_txoutclk_bufg  (clk_txoutclk_bufg),
        .clk_rxoutclk_bufg  (clk_rxoutclk_bufg),

        // GTX data
        .gt_tx_data         (gt_tx_data),
        .gt_tx_data_valid   (gt_tx_data_valid),
        .gt_rx_data         (gt_rx_data),
        .gt_rx_data_valid   (gt_rx_data_valid),

        // states for alignment
        .gtx_cpll_is_lock   (gtx_cpll_is_lock),
        .rx_reset_done      (rx_reset_done),
        .rx_data_is_comma   (rx_data_is_comma),
        .gtx_rx_error       (gtx_rx_error)
    );

    //--------------------------------
    // clk sync
    //--------------------------------
    wire [63:0] ptp_timestamp_tx;
    wire [63:0] ptp_timestamp_rx;

    wire [3:0] ptp_flags;
    wire gt_link_up;
    wire ptp_working;

    //--------------------------------
    // slow control user data (via GT)
    //--------------------------------
    wire [15:0] user_rx_data;
    wire        user_rx_data_valid;
    wire [15:0] user_tx_data_mux;
    wire        user_tx_data_valid_mux;
    wire        slow_control_active;
    wire [ 7:0] brd_num;

    // FIFO 读侧（txoutclk 域，main 控制读）
    wire [15:0] sc_fifo_dout;
    wire        sc_fifo_empty;
    reg         sc_fifo_rd_en;

    time_sync_manager instance_time_sync_manager (
        .clk_txoutclk_bufg  (clk_txoutclk_bufg),
        .clk_rxoutclk_bufg  (clk_rxoutclk_bufg),
        .clk_sys_400M       (clk_400M),
        .clk_drp_100M       (clk_100M),
        .clk_uart           (clk_200M),

        // gtx data
        .gt_tx_data         (gt_tx_data),
        .gt_tx_data_valid   (gt_tx_data_valid),
        .gt_rx_data         (gt_rx_data),
        .gt_rx_data_valid   (gt_rx_data_valid),
        .gt_rx_data_is_comma(rx_data_is_comma),

        // user data (GT slow control)
        .user_tx_data       (user_tx_data_mux),
        .user_tx_data_valid (user_tx_data_valid_mux),
        .user_rx_data       (user_rx_data),
        .user_rx_data_valid (user_rx_data_valid),

        // timestamp
        .timestamp_tx       (ptp_timestamp_tx),
        .timestamp_rx       (ptp_timestamp_rx),     // slave only uses this
        .ptp_start          (1'b0),                 // slave: no local start
        .ptp_value          (16'b0),
        .ptp_value_valid    (1'b0),
        .tx_load_value      (64'b0),
        .tx_load            (0),
        
        // uart interface (master only, slave unused)
        .uart_data_out      (),
        .uart_read_enable   (1'b0),
        .uart_read_empty    (),
        .uart_read_valid    (),

        // data alignment and pma reset
        .gt_rx_error        (gtx_rx_error),
        .gt_pma_rst_n       (rx_pma_rst_n),
        .gt_rx_rst_done     (rx_reset_done),
        .gt_link_up         (gt_link_up),

        // flags
        .flags              (ptp_flags),

        // ptp working flag
        .ptp_working        (ptp_working)
    );

    //--------------------------------
    // working flags
    //--------------------------------
    // ptp_working_flag: 1 while PTP exchange is active, else 0
    wire ptp_working_flag;
    assign ptp_working_flag = ptp_working;

    // slow_control_flag: 1 while slow control is being transferred, else 0
    wire slow_control_flag;
    assign slow_control_flag = slow_control_active;

     //--------------------------------
     // GT 发送帧头状态机：区分 慢控回复/W-packet Ack 与 ADC 事件数据
     //   W-packet ack: 16'hFFF3 + 16'hFFFF (1 word)
     //   慢控回复: 16'hFFF1 + 1 个 word
     //   ADC 事件: 16'hFFF0 + TRIG_TOTAL+HEAD_LEN 个 word
     //   空闲:      16'hBC3C
     //--------------------------------
     localparam TX_FRM_IDLE = 2'd0;
     localparam TX_FRM_SC   = 2'd1;
     localparam TX_FRM_EVT  = 2'd2;
     localparam TX_FRM_ACK  = 2'd3;

     reg [1:0] tx_frm_state;
     reg [5:0] tx_evt_cnt;
     reg [15:0] sc_dout_cached;

    // 事件数据长度（word）
    localparam EVT_WORDS = TRIG_TOTAL + HEAD_LEN;

    assign user_tx_data_mux       = tx_frm_data;
    assign user_tx_data_valid_mux = tx_frm_valid;

    reg [15:0] tx_frm_data;
    reg        tx_frm_valid;

    always @(posedge clk_txoutclk_bufg or negedge rst_n) begin
        if (!rst_n) begin
            tx_frm_state   <= TX_FRM_IDLE;
            tx_frm_valid   <= 1'b0;
            tx_evt_cnt     <= 6'd0;
            fifo_async_rd_en <= 1'b0;
            sc_fifo_rd_en    <= 1'b0;
        end else begin
            case (tx_frm_state)
                // 空闲：慢控优先，其次事件
                 TX_FRM_IDLE: begin
                    tx_frm_valid <= 1'b0;
                    fifo_async_rd_en <= 1'b0;
                    sc_fifo_rd_en    <= 1'b0;
                    if (ack_req) begin
                        tx_frm_state <= TX_FRM_ACK;
                        tx_frm_data  <= 16'hFFF3;
                        tx_frm_valid <= 1'b1;
                    end else if (~sc_fifo_empty) begin
                        sc_dout_cached <= sc_fifo_dout;
                        tx_frm_state <= TX_FRM_SC;
                        tx_frm_data  <= 16'hFFF1;
                        tx_frm_valid <= 1'b1;
                    end else if (~fifo_async_prog_empty) begin
                        // 至少一个完整事件已缓冲
                        tx_frm_state <= TX_FRM_EVT;
                        tx_frm_data  <= 16'hFFF0;
                        tx_frm_valid <= 1'b1;
                        tx_evt_cnt   <= 6'd0;
                    end
                end
                // 慢控回复：只读出一个数据字并发送，随即回到 IDLE（不排空 FIFO）
                TX_FRM_SC: begin
                    tx_frm_data  <= sc_dout_cached;
                    tx_frm_valid <= 1'b1;
                    sc_fifo_rd_en <= ~sc_fifo_empty;
                    tx_frm_state <= TX_FRM_IDLE;
                end
                // W-packet ack: 0xFFF3 + ack marker (0xFFFF)
                TX_FRM_ACK: begin
                    tx_frm_data  <= 16'hFFFF;
                    tx_frm_valid <= 1'b1;
                    tx_frm_state <= TX_FRM_IDLE;
                end
                // ADC 事件：转发 fifo_async_data_out，共 EVT_WORDS 个
                TX_FRM_EVT: begin
                    tx_frm_data      <= fifo_async_data_out;
                    tx_frm_valid     <= 1'b1;
                    fifo_async_rd_en <= 1'b1;
                    if (tx_evt_cnt == EVT_WORDS[5:0] - 6'd1) begin
                        tx_frm_state <= TX_FRM_IDLE;
                        tx_evt_cnt   <= 6'd0;
                    end else begin
                        tx_evt_cnt <= tx_evt_cnt + 6'd1;
                    end
                end
                default: begin
                    tx_frm_state <= TX_FRM_IDLE;
                    sc_fifo_rd_en <= 1'b0;
                end
            endcase
        end
    end

    //--------------------------------
    // slow control (via GT, replaces uart slow control)
    //--------------------------------
    // adc_fco 现为 clk_rxoutclk_bufg，与 slow_control_manager 同域。
    // AD9253_BIT_SLIP 用 fco_rise 计数等待对齐，改用 rxoutclk 域的周期脉冲。
    reg [ 7:0] ad9253_fco_cnt_rx;
    always @(posedge adc_fco or negedge rst_n) begin
        if (!rst_n) begin
            ad9253_fco_cnt_rx <= 0;
        end else begin
            ad9253_fco_cnt_rx <= ad9253_fco_cnt_rx + 1'b1;
        end
    end
    wire ad9253_fco_rise;
    assign ad9253_fco_rise = (ad9253_fco_cnt_rx == 8'd0);

    wire [ADC_NUM-1:0] ad9253_config_done;
    slow_control_manager #(
        .ADC_NUM(ADC_NUM),
        .CHANNEL_NUM(CHANNEL_NUM)
    ) u_slow_control_manager (
        .clk  (clk_rxoutclk_bufg),
        .clk_tx (clk_txoutclk_bufg),
        .rst_n(rst_n),

        // GT 慢控收发接口
        .user_rx_data       (user_rx_data),
        .user_rx_data_valid (user_rx_data_valid),

        // FIFO 读侧（txoutclk 域）
        .sc_fifo_dout  (sc_fifo_dout),
        .sc_fifo_rd_en (sc_fifo_rd_en),
        .sc_fifo_empty (sc_fifo_empty),

        // 标志
        .slow_control_active   (slow_control_active),
        .ack_req               (ack_req_raw),
        .brd_num               (brd_num),

        // Si5345接口
        .si5345_spi_busy (si5345_spi_busy),   // input wire si5345_spi_busy
        .si5345_bit_cnt  (si5345_bit_cnt),    // input wire [3:0] si5345_bit_cnt
        .si5345_spi_done (si5345_spi_done),   // input wire si5345_spi_done
        .si5345_rw       (si5345_rw),         // output si5345_rw
        .si5345_data_in  (si5345_data_in),    // output [15:0] si5345_data_in
        .si5345_spi_start(si5345_spi_start),  // output si5345_spi_start
        .si5345_cs_n     (si5345_cs_n),       // output si5345_cs_n
        .si5345_data_out (si5345_data_out),   // input wire [15:0] si5345_data_out

        // AD9253接口
        .ad9253_spi_done   (ad9253_spi_done),    // input wire ad9253_spi_done
        .ad9253_spi_busy   (ad9253_spi_busy),    // input wire ad9253_spi_busy
        .ad9253_rw         (ad9253_rw),          // output ad9253_rw
        .ad9253_data_in    (ad9253_data_in),     // output [7:0] ad9253_data_in
        .ad9253_spi_start  (ad9253_spi_start),   // output ad9253_spi_start
        .ad9253_cs_n       (ad9253_cs_n),        // output [7:0] ad9253_cs_n
        .ad9253_data_out   (ad9253_data_out),    // input wire [7:0] ad9253_data_out
        .ad9253_config_done(ad9253_config_done), // output [7:0] ad9253_config_done

        // DAC128S085接口
        .dac128s085_spi_done (dac128s085_spi_done),   // input wire dac128s085_spi_done
        .dac128s085_spi_busy (dac128s085_spi_busy),   // input wire dac128s085_spi_busy
        .dac128s085_data_in  (dac128s085_data_in),    // output [511:0] dac128s085_data_in
        .dac128s085_spi_start(dac128s085_spi_start),  // output dac128s085_spi_start
        .dac128s085_cs_n     (dac128s085_cs_n),       // output dac128s085_cs_n

        // Bit slip控制
        .ad9253_fco_rise(ad9253_fco_rise),  // input wire ad9253_fco_rise
        .ad9253_data_chx(ad9253_data_chx),  // input wire [511:0] ad9253_data_chx
        .bitslip_chx    (bitslip_chx),      // output bitslip_chx

        // idelay
        .idelay_tap(idelay_tap),
        .idelay_ld (idelay_ld),

        // tdc
        .tdc_cali_in(tdc_cali_in),
        .tdc_cali_en(tdc_cali_en),
        .cali_flag  (cali_flag),

        .state(sc_state),
        .next_state(sc_next_state)
    );

    wire [5:0] sc_state;
    wire [5:0] sc_next_state;

    // ack_req 跨时钟域同步（rxoutclk -> txoutclk）
    reg ack_req_r1, ack_req_r2;
    wire ack_req;
    always @(posedge clk_txoutclk_bufg or negedge rst_n) begin
        if (!rst_n) begin
            ack_req_r1 <= 1'b0;
            ack_req_r2 <= 1'b0;
        end else begin
            ack_req_r1 <= ack_req_raw;
            ack_req_r2 <= ack_req_r1;
        end
    end
    assign ack_req = ack_req_r2;
    //--------------------------------
    // ILA debug (added for board bring-up)
    //--------------------------------
    ila_rxout u_ila_rxout (
        .clk (clk_rxoutclk_bufg),
        .probe0 (ad9253_data_chx[15:0]),
        .probe1 (tdc_raw_rise[10:0]),
        .probe2 (ringbuffer_trig[0]),
        .probe3 (ringbuffer_data_valid[0]),
        .probe4 (fifo_sync_dout[15:0]),
        .probe5 (fifo_sync_valid[0]),
        .probe6 (fifo_sync_prog_full[0]),
        .probe7 (fifo_sync_empty[0]),
        .probe8 (arbiter_out[15:0]),
        .probe9 (fifo_async_wr_en),
        .probe10(fifo_async_prog_full),
        .probe11(fifo_async_full),
        .probe12(current_ch[4:0]),
        .probe13(ad9253_fco_rise),
        .probe14(idelay_ld),
        .probe15(si5345_lolb),
        .probe16(bitslip_chx[1:0]),
        .probe17(ad9253_config_done[7:0]),
        .probe18(user_rx_data[15:0]),
        .probe19(user_rx_data_valid),
        .probe20(brd_num[7:0]),
        .probe21(slow_control_active),
        .probe22(sc_state),
        .probe23(sc_next_state)
    );

    ila_txout u_ila_txout (
        .clk (clk_txoutclk_bufg),
        .probe0 (tx_frm_state[1:0]),
        .probe1 (tx_frm_valid),
        .probe2 (tx_frm_data[15:0]),
        .probe3 (tx_evt_cnt[5:0]),
        .probe4 (fifo_async_data_out[15:0]),
        .probe5 (fifo_async_rd_en),
        .probe6 (fifo_async_prog_empty),
        .probe7 (fifo_async_empty),
        .probe8 (sc_fifo_dout[15:0]),
        .probe9 (sc_fifo_empty),
        .probe10(sc_fifo_rd_en),
        .probe11(gt_tx_data[15:0]),
        .probe12(gt_tx_data_valid),
        .probe13(gt_rx_data[15:0]),
        .probe14(gt_rx_data_valid),
        .probe15(rx_data_is_comma[1:0]),
        .probe16(gtx_cpll_is_lock),
        .probe17(rx_reset_done),
        .probe18(gtx_rx_error),
        .probe19(rx_pma_rst_n),
        .probe20(gt_link_up),
        .probe21(user_tx_data_mux),
        .probe22(user_tx_data_valid_mux)
    );
endmodule
