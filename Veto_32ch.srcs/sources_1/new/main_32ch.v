`timescale 1ns / 1ps

module main_32ch (
    // FPGA 200M时钟
    input clk_200M_p,
    input clk_200M_n,

    input  wire uart_rx,  // UART接收数据
    output wire uart_tx,  // UART发送数据

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

    input wire gt_refclk_15625_p,
    input wire gt_refclk_15625_n,

    output wire SFP_tx_disable1,  // set low
    output wire SFP_tx_disable2,  // set low

    output wire gt_link_up_out    // GT link established
);

    localparam ADC_NUM = 4'd8;
    localparam CHANNEL_NUM = 4'd4;
    localparam TRIG_TOTAL = 16'd57;
    localparam TRIG_PRE = 16'd10;
    localparam HEAD_LEN = 16'd7;

    assign clk_125M_en = 1;
    assign SFP_tx_disable1 = 0;
    assign SFP_tx_disable2 = 0;
    assign gt_link_up_out = gt_link_up;

    wire rst_n;
    wire trig_rst_n;
    wire tdc_trig_flag;
    (* dont_touch="true" *) vio_0 vio_inst (
        .clk       (clk_200M),            // input wire clk
        .probe_out0(rst_n),
        .probe_out1(trig_rst_n),
        .probe_out2(tdc_trig_flag)
    );

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
        .clk    (clk_200M),
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

    wire                               adc_fco;

    ad9253_selectio_top ad9253_selectio_top_inst (
        .clk      (clk_200M),
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
                .clk    (clk_200M),
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

    // // 同步和边沿检测逻辑
    // reg [ADC_NUM*CHANNEL_NUM-1:0] max40026_sync1, max40026_sync2;
    // wire [ADC_NUM*CHANNEL_NUM-1:0] max40026_ch_pos_edge;  // 各通道上升沿脉冲
    // wire [ADC_NUM*CHANNEL_NUM-1:0] max40026_ch_neg_edge;  // 各通道下降沿脉冲

    // genvar n;
    // generate
    //     for (n = 0; n < ADC_NUM * CHANNEL_NUM; n = n + 1) begin : max40026_edge_detect_gen
    //         always @(posedge adc_fco or negedge rst_n) begin
    //             if (!rst_n) begin
    //                 max40026_sync1[n] <= 0;
    //                 max40026_sync2[n] <= 0;
    //             end else begin
    //                 max40026_sync1[n] <= max40026_ch[n];
    //                 max40026_sync2[n] <= max40026_sync1[n];
    //             end
    //         end

    //         // 边沿检测逻辑
    //         assign max40026_ch_pos_edge[n] = ~max40026_sync2[n] & max40026_sync1[n];  // 上升沿
    //         assign max40026_ch_neg_edge[n] = max40026_sync2[n] & ~max40026_sync1[n];  // 下降沿
    //     end
    // endgenerate

    //--------------------------------
    // tdc
    //--------------------------------
    wire [11*ADC_NUM*CHANNEL_NUM - 1:0] tdc_raw_rise;
    wire [11*ADC_NUM*CHANNEL_NUM - 1:0] tdc_raw_fall;
    wire [     ADC_NUM*CHANNEL_NUM-1:0] tdc_signal;

    wire [     ADC_NUM*CHANNEL_NUM-1:0] cali_flag;
    reg  [                         3:0] cali_cnt;
    reg                                 cali_pulse;

    wire [   ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_empty;
    wire [   ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_full;
    wire [   ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_valid;
    wire [   ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_wr_en;
    wire [   ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_rd_en;
    wire [10*ADC_NUM*CHANNEL_NUM - 1:0] fifo_tdc_dout;

    IBUFDS_GTE2 ibufds_gte2_inst (
        .I    (gt_refclk_15625_p),
        .IB   (gt_refclk_15625_n),
        .CEB  (1'b0),
        .O    (clk_15625M),
        .ODIV2()
    );

    always @(posedge clk_15625M or negedge rst_n) begin
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

            assign fifo_tdc_wr_en[tdc_gen] = tdc_raw_rise[tdc_gen*11+10] && ~fifo_tdc_full[tdc_gen] && cali_flag[tdc_gen];
            assign fifo_tdc_rd_en[tdc_gen] = ~fifo_tdc_empty[tdc_gen];

            fifo_tdc fifo_tdc_inst (
                .rst(~(si5345_lolb && (&ad9253_config_done) && rst_n)),  // input wire rst
                .wr_clk(adc_fco),  // input wire wr_clk
                .rd_clk(clk_200M),  // input wire rd_clk
                .din(tdc_raw_rise[tdc_gen*11+:10]),  // input wire [9 : 0] din
                .wr_en(fifo_tdc_wr_en[tdc_gen]),  // input wire wr_en
                .rd_en(fifo_tdc_rd_en[tdc_gen]),  // input wire rd_en
                .dout(fifo_tdc_dout[tdc_gen*10+:10]),  // output wire [9 : 0] dout
                .full(fifo_tdc_full[tdc_gen]),  // output wire full
                .empty(fifo_tdc_empty[tdc_gen]),  // output wire empty
                .valid(fifo_tdc_valid[tdc_gen]),  // output wire valid
                .wr_rst_busy(),  // output wire wr_rst_busy
                .rd_rst_busy()  // output wire rd_rst_busy
            );
        end
    endgenerate

    // ila_tdc ila_tdc_inst (
    //     .clk       (clk_200M),
    //     .probe0    (tdc_signal),
    //     .probe1    (tdc_raw_rise),
    //     .probe2    (tdc_raw_fall),
    //     .probe3    (cali_pulse),
    //     .probe4    (cali_flag)
    // );


    //--------------------------------
    // ringbuffer
    //--------------------------------
    wire [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_trig;
    // reg  [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_trig_d;
    // wire [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_trig_rise;
    wire [ADC_NUM*CHANNEL_NUM*16-1:0] ringbuffer_out;
    wire [   ADC_NUM*CHANNEL_NUM-1:0] ringbuffer_data_valid;

    // always @(posedge adc_fco) begin
    //     ringbuffer_trig_d <= ringbuffer_trig;
    // end

    // assign ringbuffer_trig_rise = ringbuffer_trig & ~ringbuffer_trig_d;

    reg  [                      47:0] time_cnt;
    always @(posedge adc_fco) begin
        if (~(si5345_lolb && (&ad9253_config_done) && rst_n)) begin
            time_cnt <= 48'd0;
        end else begin
            time_cnt <= time_cnt + 1'b1;
        end
    end

    genvar rb_idx;
    generate
        for (rb_idx = 0; rb_idx < ADC_NUM * CHANNEL_NUM; rb_idx = rb_idx + 1) begin : ringbuffer_gen

            // assign ringbuffer_trig[rb_idx] = tdc_raw_rise[11*rb_idx+10] && !fifo_sync_prog_full[rb_idx];
            wire trig_src;
            assign trig_src =
            tdc_trig_flag ?
            tdc_raw_rise[11*rb_idx+10] :
            (ad9253_data_chx[rb_idx*16+15 -: 14] < 14'd7100);

            assign ringbuffer_trig[rb_idx] = trig_src && !fifo_sync_prog_full[rb_idx];

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
                .time_cnt  (time_cnt),
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
                .prog_full_thresh(11'd2047 - (TRIG_TOTAL + HEAD_LEN)),  // input wire [10 : 0] prog_full_thresh
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



    // // --------------------------------
    // // fifo_async_aurora
    // // --------------------------------
    // wire        fifo_async_rd_en;
    // wire [63:0] fifo_async_data_out;
    // wire        fifo_async_full;
    // wire        fifo_async_empty;
    // wire        fifo_async_prog_full;
    // wire        fifo_async_prog_empty;
    // wire        fifo_async_valid;

    // fifo_async_aurora inst_fifo_async_aurora (
    //     .rst(~(si5345_lolb && (&ad9253_config_done) && rst_n && trig_rst_n)),  // input wire rst
    //     .wr_clk(adc_fco),  // input wire wr_clk
    //     .rd_clk(aurora_usr_clk),  // input wire rd_clk
    //     .din(arbiter_out),  // input wire [15 : 0] din
    //     .wr_en(fifo_async_wr_en),  // input wire wr_en
    //     .rd_en(fifo_async_rd_en),  // input wire rd_en
    //     .prog_empty_thresh((TRIG_TOTAL + HEAD_LEN) / 4),  // input wire [8 : 0] prog_empty_thresh
    //     .prog_full_thresh(11'd2047 - (TRIG_TOTAL + HEAD_LEN)),    // input wire [10 : 0] prog_full_thresh
    //     .dout(fifo_async_data_out),  // output wire [63 : 0] dout
    //     .full(fifo_async_full),  // output wire full
    //     .empty(fifo_async_empty),  // output wire empty
    //     .prog_full(fifo_async_prog_full),  // output wire prog_full
    //     .prog_empty(fifo_async_prog_empty),  // output wire prog_empty
    //     .wr_rst_busy(),  // output wire wr_rst_busy
    //     .rd_rst_busy(),  // output wire rd_rst_busy
    //     .valid(fifo_async_valid)
    // );

    // assign fifo_async_rd_en = !fifo_async_empty && s_axi_tx_tready;
    // assign s_axi_tx_tvalid  = fifo_async_valid;

    // //--------------------------------
    // // Aurora
    // //--------------------------------
    // wire        aurora_channel_up;
    // wire        aurora_lane_up;
    // wire        aurora_hard_err;
    // wire        aurora_soft_err;
    // wire        gt_pll_lock;

    // wire [63:0] s_axi_tx_tdata;
    // wire        s_axi_tx_tvalid;
    // wire        s_axi_tx_tready;
    // wire [63:0] m_axi_rx_tdata;
    // wire        m_axi_rx_tvalid;

    // wire        aurora_usr_clk;
    // wire        aurora_reset_out;
    // aurora_64b66b_0 inst_aurora_64b66b_0 (
    //     .rxp(SFP1_rx_p),  // input wire [0 : 0] rxp
    //     .rxn(SFP1_rx_n),  // input wire [0 : 0] rxn
    //     .gt_refclk1_p(clk_125M_p),  // input wire gt_refclk1_p
    //     .gt_refclk1_n(clk_125M_n),  // input wire gt_refclk1_n
    //     .reset_pb(~rst_n),  // input wire reset_pb
    //     .power_down(1'b0),  // input wire power_down
    //     .pma_init(1'b0),  // input wire pma_init
    //     .loopback               (3'b000),                 // input wire [2 : 0] loopback, 000 normal，010 near-end PCS, 100, PMA loopback
    //     .txp(SFP1_tx_p),  // output wire [0 : 0] txp
    //     .txn(SFP1_tx_n),  // output wire [0 : 0] txn
    //     .hard_err(aurora_hard_err),  // output wire hard_err
    //     .soft_err(aurora_soft_err),  // output wire soft_err
    //     .channel_up(aurora_channel_up),  // output wire channel_up
    //     .lane_up(aurora_lane_up),  // output wire [0 : 0] lane_up
    //     .tx_out_clk(),  // output wire tx_out_clk
    //     .drp_clk_in(clk_200M),  // input wire drp_clk_in
    //     .gt_pll_lock(gt_pll_lock),  // output wire gt_pll_lock
    //     .s_axi_tx_tdata(fifo_async_data_out),  // input wire [0 : 63] s_axi_tx_tdata
    //     .s_axi_tx_tvalid(s_axi_tx_tvalid),  // input wire s_axi_tx_tvalid
    //     .s_axi_tx_tready(s_axi_tx_tready),  // output wire s_axi_tx_tready
    //     .m_axi_rx_tdata(m_axi_rx_tdata),  // output wire [0 : 63] m_axi_rx_tdata
    //     .m_axi_rx_tvalid(m_axi_rx_tvalid),  // output wire m_axi_rx_tvalid
    //     .mmcm_not_locked_out(),  // output wire mmcm_not_locked_out
    //     .drpaddr_in(0),  // input wire [8 : 0] drpaddr_in
    //     .drpdi_in(0),  // input wire [15 : 0] drpdi_in
    //     .qpll_drpaddr_in(0),  // input wire [7 : 0] qpll_drpaddr_in
    //     .qpll_drpdi_in(0),  // input wire [15 : 0] qpll_drpdi_in
    //     .drprdy_out(),  // output wire drprdy_out
    //     .drpen_in(0),  // input wire drpen_in
    //     .drpwe_in(0),  // input wire drpwe_in
    //     .qpll_drprdy_out(0),  // output wire qpll_drprdy_out
    //     .qpll_drpen_in(0),  // input wire qpll_drpen_in
    //     .qpll_drpwe_in(0),  // input wire qpll_drpwe_in
    //     .drpdo_out(),  // output wire [15 : 0] drpdo_out
    //     .qpll_drpdo_out(),  // output wire [15 : 0] qpll_drpdo_out
    //     .init_clk(clk_200M),  // input wire init_clk
    //     .link_reset_out(link_reset_out),  // output wire link_reset_out
    //     .user_clk_out(aurora_usr_clk),  // output wire user_clk_out
    //     .sync_clk_out(),  // output wire sync_clk_out
    //     .gt_qpllclk_quad3_out(),  // output wire gt_qpllclk_quad3_out
    //     .gt_qpllrefclk_quad3_out(),  // output wire gt_qpllrefclk_quad3_out
    //     .gt_qpllrefclklost_out(),  // output wire gt_qpllrefclklost_out
    //     .gt_qplllock_out(),  // output wire gt_qplllock_out
    //     .gt_rxcdrovrden_in(1'b0),  // input wire gt_rxcdrovrden_in
    //     .sys_reset_out(aurora_reset_out),  // output wire sys_reset_out
    //     .gt_reset_out()  // output wire gt_reset_out
    // );

    // ila_aurora ila_aurora_inst (
    //     .clk   (aurora_usr_clk),
    //     .probe0(aurora_channel_up),
    //     .probe1(fifo_async_data_out),
    //     .probe2(s_axi_tx_tvalid),
    //     .probe3(s_axi_tx_tready),
    //     .probe4(m_axi_rx_tdata),
    //     .probe5(m_axi_rx_tvalid)
    // );

    // //--------------------------------
    // // gtx_interface
    // //--------------------------------
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
    wire start_ptp;
    wire [7:0] uart_ptp_data;

    wire [63:0] ptp_timestamp_tx;
    wire [63:0] ptp_timestamp_rx;
    wire [15:0] timestamp_rx_delay;
    wire timestamp_rx_delay_valid;

    reg  uart_ptp_read_enable;
    wire uart_ptp_read_empty;
    wire uart_ptp_read_valid;

    wire [3:0] ptp_flags;
    wire gt_link_up;

    // gt user data
    wire [15:0] user_tx_data;
    wire user_tx_data_valid;
    wire [15:0] user_rx_data;
    wire user_rx_data_valid;

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

        // user data
        .user_tx_data       (user_tx_data),
        .user_tx_data_valid (user_tx_data_valid),
        .user_rx_data       (user_rx_data),
        .user_rx_data_valid (user_rx_data_valid),

        // timestamp
        .timestamp_tx       (ptp_timestamp_tx),
        .timestamp_rx       (ptp_timestamp_rx),     // slave only uses this
        .ptp_start          (start_ptp),            // rising edge trigger
        .ptp_value          (timestamp_rx_delay),   // delay value calculated by software
        .ptp_value_valid    (timestamp_rx_delay_valid),
        .tx_load_value      (64'b0),
        .tx_load            (0),
        
        // uart interface, only master used
        .uart_data_out      (uart_ptp_data),
        .uart_read_enable   (uart_ptp_read_enable),
        .uart_read_empty    (uart_ptp_read_empty),
        .uart_read_valid    (uart_ptp_read_valid),

        // data alignment and pma reset
        .gt_rx_error        (gtx_rx_error),
        .gt_pma_rst_n       (rx_pma_rst_n),
        .gt_rx_rst_done     (rx_reset_done),
        .gt_link_up         (gt_link_up),

        // flags
        .flags              (ptp_flags)
    );


    //--------------------------------
    // uart
    //--------------------------------
    reg ad9253_fco_buf_sync1, ad9253_fco_buf_sync2;
    always @(posedge clk_200M or negedge rst_n) begin
        if (!rst_n) begin
            ad9253_fco_buf_sync1 <= 0;
            ad9253_fco_buf_sync2 <= 0;
        end else begin
            ad9253_fco_buf_sync1 <= adc_fco;
            ad9253_fco_buf_sync2 <= ad9253_fco_buf_sync1;
        end
    end
    wire ad9253_fco_rise;
    assign ad9253_fco_rise = ad9253_fco_buf_sync1 & ~ad9253_fco_buf_sync2;  // 检测上升沿

    wire [ADC_NUM-1:0] ad9253_config_done;
    uart_controller_32ch #(
        .ADC_NUM(ADC_NUM),
        .CHANNEL_NUM(CHANNEL_NUM)
    ) u_uart_controller_32ch (
        .clk  (clk_200M),  // input wire clk
        .rst_n(rst_n),     // input wire rst_n

        // UART接口
        .uart_rx(uart_rx),  // input wire uart_rx
        .uart_tx(uart_tx),  // output wire uart_tx

        // Si5345接口
        .si5345_spi_busy (si5345_spi_busy),   // input wire si5345_spi_busy
        .si5345_bit_cnt  (si5345_bit_cnt),    // input wire [3:0] si5345_bit_cnt
        .si5345_spi_done (si5345_spi_done),   // input wire si5345_spi_done
        .si5345_rw       (si5345_rw),         // output reg si5345_rw
        .si5345_data_in  (si5345_data_in),    // output reg [15:0] si5345_data_in
        .si5345_spi_start(si5345_spi_start),  // output reg si5345_spi_start
        .si5345_cs_n     (si5345_cs_n),       // output reg si5345_cs_n
        .si5345_data_out (si5345_data_out),   // input wire [15:0] si5345_data_out

        // AD9253接口
        .ad9253_spi_done   (ad9253_spi_done),    // input wire ad9253_spi_done
        .ad9253_spi_busy   (ad9253_spi_busy),    // input wire ad9253_spi_busy
        .ad9253_rw         (ad9253_rw),          // output reg ad9253_rw
        .ad9253_data_in    (ad9253_data_in),     // output reg [7:0] ad9253_data_in
        .ad9253_spi_start  (ad9253_spi_start),   // output reg ad9253_spi_start
        .ad9253_cs_n       (ad9253_cs_n),        // output reg ad9253_cs_n
        .ad9253_data_out   (ad9253_data_out),    // input wire [7:0] ad9253_data_out
        .ad9253_config_done(ad9253_config_done), // output reg ad9253_config_done

        // DAC128S085接口
        .dac128s085_spi_done (dac128s085_spi_done),   // input wire dac128s085_spi_done
        .dac128s085_spi_busy (dac128s085_spi_busy),   // input wire dac128s085_spi_busy
        .dac128s085_data_in  (dac128s085_data_in),    // output reg [15:0] dac128s085_data_in
        .dac128s085_spi_start(dac128s085_spi_start),  // output reg dac128s085_spi_start
        .dac128s085_cs_n     (dac128s085_cs_n),       // output reg dac128s085_cs_n

        // Bit slip控制
        .ad9253_fco_rise(ad9253_fco_rise),  // input wire ad9253_fco_rise
        .ad9253_data_chx(ad9253_data_chx),  // input wire [7:0] ad9253_d0_chx [3:0]
        .bitslip_chx    (bitslip_chx),      // output wire bitslip0

        // idelay
        .idelay_tap(idelay_tap),
        .idelay_ld (idelay_ld),

        // tdc
        .tdc_cali_in(fifo_tdc_dout),
        .tdc_cali_en(fifo_tdc_valid),
        .cali_flag  (cali_flag)
    );

    wire fifo_sync_prog_full_any;
    assign fifo_sync_prog_full_any = |fifo_sync_prog_full;

    ila_adc ila_adc_inst (
        .clk    (adc_fco),
        .probe0 (max40026_ch),
        .probe1 (ad9253_data_chx[79:64]),
        .probe2 (ringbuffer_trig[4]),
        .probe3 (ringbuffer_data_valid[4]),
        .probe4 (fifo_sync_empty[4]),
        .probe5 (fifo_sync_prog_empty[4]),
        .probe6 (fifo_sync_prog_full_any),
        .probe7 (fifo_sync_dout[79:64]),
        .probe8 (fifo_sync_valid[4]),
        .probe9 (fifo_sync_rd_en[4]),
        .probe10(arbiter_out),
        .probe11(fifo_async_wr_en),
        .probe12(fifo_async_full),
        .probe13(fifo_async_empty),
        .probe14(fifo_async_prog_full),
        .probe15(fifo_async_prog_empty),
        .probe16(fifo_async_data_out),
        .probe17(fifo_async_rd_en),
        .probe18(current_ch),
        .probe19(fifo_tdc_wr_en[4]),
        .probe20(fifo_tdc_full[4]),
        .probe21(fifo_tdc_empty[4]),
        .probe22(fifo_tdc_rd_en[4]),
        .probe23(fifo_tdc_valid[4]),
        .probe24(ringbuffer_out[79:64])
    );
    // .probe18(s_axi_tx_tvalid),
    // .probe19(0),
    // .probe20(s_axi_tx_tready),
    // .probe21(aurora_channel_up),
    // .probe22(aurora_lane_up),
    // .probe23(m_axi_rx_tvalid)
endmodule
