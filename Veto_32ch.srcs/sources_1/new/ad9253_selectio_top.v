`timescale 1ns / 1ps

module ad9253_selectio_top (
    input clk,
    input rst_n,
    input spi_rst_n,

    // AD9253 SPI
    inout        ad9253_sdio,
    output       ad9253_sclk,
    input        ad9253_spi_start,
    input        ad9253_rw,
    input  [7:0] ad9253_data_in,
    output       ad9253_spi_busy,
    output       ad9253_spi_done,
    output       ad9253_sdio_in,
    output       ad9253_sdio_out,
    output [7:0] ad9253_data_out,
    output [2:0] ad9253_bit_cnt,
    output [1:0] ad9253_spi_state,

    // AD9253 数据 - 所有通道的数据输入
    input [63:0] ad9253_data_p,
    input [63:0] ad9253_data_n,
    input [ 7:0] ad9253_dco_p,
    input [ 7:0] ad9253_dco_n,

    // 32个通道的输出数据(每通道高8bit, 低8bit)
    output [511:0] ad9253_data_chx,

    // output [3:0] ad9253_clk_div_out,
    output adc_fco,

    // 每个通道的bitslip控制信号
    input [63:0] bitslip_chx,

    input [319:0] in_delay_tap_in,
    input         idelay_ld
);

    reg  [63:0] bitslip_chx_pulse;
    wire [ 3:0] ad9253_clk_div_out;

    // 使用generate语句生成所有通道的bitslip脉冲逻辑
    genvar bitslip_idx;
    generate
        for (bitslip_idx = 0; bitslip_idx < 64; bitslip_idx = bitslip_idx + 1) begin : bitslip_gen

            // ADC编号 0~7
            localparam integer ADC_IDX = bitslip_idx / 8;

            // 不同ADC对应不同clk_div
            wire bitslip_clk;

            assign bitslip_clk =
                (ADC_IDX == 0 || ADC_IDX == 2) ? ad9253_clk_div_out[0] :
                (ADC_IDX == 1 || ADC_IDX == 3) ? ad9253_clk_div_out[1] :
                (ADC_IDX == 4 || ADC_IDX == 6) ? ad9253_clk_div_out[2] :
                                                ad9253_clk_div_out[3];

            // bitslip pulse generation
            reg bitslip_sync1, bitslip_sync2;
            reg bitslip_sync2_d;

            always @(posedge bitslip_clk) begin
                bitslip_sync1 <= bitslip_chx[bitslip_idx];
                bitslip_sync2 <= bitslip_sync1;
                bitslip_sync2_d <= bitslip_sync2;

                bitslip_chx_pulse[bitslip_idx] <= bitslip_sync2 & ~bitslip_sync2_d;
            end

        end
    endgenerate

    // SPI配置
    spi_3wire_master_8bit #(
        .CLK_DIV(100)
    ) ad9253_spi_inst (
        .clk      (clk),
        .rst_n    (spi_rst_n),
        .start    (ad9253_spi_start),
        .rw       (ad9253_rw),
        .data_in  (ad9253_data_in),
        .done     (ad9253_spi_done),
        .sclk     (ad9253_sclk),
        .sdio     (ad9253_sdio),
        .sdio_in  (ad9253_sdio_in),
        .sdio_out (ad9253_sdio_out),
        .shift_reg(ad9253_data_out),
        .busy     (ad9253_spi_busy),
        .bit_cnt  (ad9253_bit_cnt),
        .state    (ad9253_spi_state)
    );


    wire [  3:0] delay_locked;
    wire [511:0] data_in_to_device;

    selectio_wiz_0 AD_1_3_Bk18 (
        .data_in_from_pins_p({
            ad9253_data_p[23:16], ad9253_data_p[7:0]
        }),  // input [15:0] data_in_from_pins_p
        .data_in_from_pins_n({
            ad9253_data_n[23:16], ad9253_data_n[7:0]
        }),  // input [15:0] data_in_from_pins_n
        .data_in_to_device(data_in_to_device[127:0]),  // output [127:0] data_in_to_device
        .in_delay_reset(idelay_ld),  // input in_delay_reset                    
        .in_delay_data_ce(16'b0),  // input [15  :0] in_delay_data_ce      
        .in_delay_data_inc(16'hFFFF),  // input [15  :0] in_delay_data_inc     
        .in_delay_tap_in({
            in_delay_tap_in[119:80], in_delay_tap_in[39:0]
        }),  // input [79:0] in_delay_tap_in          
        .in_delay_tap_out(),  // output [79:0] in_delay_tap_out          

        .delay_locked(delay_locked[0]),  // output delay_locked                      
        .ref_clock(clk),  // input ref_clock                         
        .bitslip({
            bitslip_chx_pulse[23:16], bitslip_chx_pulse[7:0]
        }),  // input bitslip                           
        .clk_in_p(ad9253_dco_p[0]),  // input clk_in_p                          
        .clk_in_n(ad9253_dco_n[0]),  // input clk_in_n
        .clk_div_out(ad9253_clk_div_out[0]),  // output clk_div_out                       
        .clk_reset(~rst_n),  // input clk_reset
        .io_reset(~rst_n)  // input io_reset
    );

    selectio_wiz_1 AD_2_4_Bk15 (
        .data_in_from_pins_p({
            ad9253_data_p[31:24], ad9253_data_p[15:8]
        }),  // input [15:0] data_in_from_pins_p
        .data_in_from_pins_n({
            ad9253_data_n[31:24], ad9253_data_n[15:8]
        }),  // input [15:0] data_in_from_pins_n
        .data_in_to_device(data_in_to_device[255:128]),  // output [127:0] data_in_to_device
        .in_delay_reset(idelay_ld),  // input in_delay_reset                    
        .in_delay_data_ce(16'b0),  // input [15  :0] in_delay_data_ce      
        .in_delay_data_inc(16'hFFFF),  // input [15  :0] in_delay_data_inc     
        .in_delay_tap_in({
            in_delay_tap_in[159:120], in_delay_tap_in[79:40]
        }),  // input [79:0] in_delay_tap_in          
        .in_delay_tap_out(),  // output [79:0] in_delay_tap_out          

        .delay_locked(delay_locked[1]),  // output delay_locked                      
        .ref_clock(clk),  // input ref_clock                         
        .bitslip({
            bitslip_chx_pulse[31:24], bitslip_chx_pulse[15:8]
        }),  // input bitslip                           
        .clk_in_p(ad9253_dco_p[1]),  // input clk_in_p                          
        .clk_in_n(ad9253_dco_n[1]),  // input clk_in_n
        .clk_div_out(ad9253_clk_div_out[1]),  // output clk_div_out                       
        .clk_reset(~rst_n),  // input clk_reset
        .io_reset(~rst_n)  // input io_reset
    );

    selectio_wiz_2 AD_5_7_Bk17 (
        .data_in_from_pins_p({
            ad9253_data_p[55:48], ad9253_data_p[39:32]
        }),  // input [15:0] data_in_from_pins_p
        .data_in_from_pins_n({
            ad9253_data_n[55:48], ad9253_data_n[39:32]
        }),  // input [15:0] data_in_from_pins_n
        .data_in_to_device(data_in_to_device[383:256]),  // output [127:0] data_in_to_device
        .in_delay_reset(idelay_ld),  // input in_delay_reset                    
        .in_delay_data_ce(16'b0),  // input [15  :0] in_delay_data_ce      
        .in_delay_data_inc(16'hFFFF),  // input [15  :0] in_delay_data_inc     
        .in_delay_tap_in({
            in_delay_tap_in[279:240], in_delay_tap_in[199:160]
        }),  // input [79:0] in_delay_tap_in          
        .in_delay_tap_out(),  // output [79:0] in_delay_tap_out          

        .delay_locked(delay_locked[2]),  // output delay_locked                      
        .ref_clock(clk),  // input ref_clock                         
        .bitslip({
            bitslip_chx_pulse[55:48], bitslip_chx_pulse[39:32]
        }),  // input bitslip                           
        .clk_in_p(ad9253_dco_p[4]),  // input clk_in_p                          
        .clk_in_n(ad9253_dco_n[4]),  // input clk_in_n
        .clk_div_out(ad9253_clk_div_out[2]),  // output clk_div_out                       
        .clk_reset(~rst_n),  // input clk_reset
        .io_reset(~rst_n)  // input io_reset
    );

    selectio_wiz_3 AD_6_8_Bk16 (
        .data_in_from_pins_p({
            ad9253_data_p[63:56], ad9253_data_p[47:40]
        }),  // input [15:0] data_in_from_pins_p
        .data_in_from_pins_n({
            ad9253_data_n[63:56], ad9253_data_n[47:40]
        }),  // input [15:0] data_in_from_pins_n
        .data_in_to_device(data_in_to_device[511:384]),  // output [127:0] data_in_to_device
        .in_delay_reset(idelay_ld),  // input in_delay_reset                    
        .in_delay_data_ce(16'b0),  // input [15  :0] in_delay_data_ce      
        .in_delay_data_inc(16'hFFFF),  // input [15  :0] in_delay_data_inc     
        .in_delay_tap_in({
            in_delay_tap_in[319:280], in_delay_tap_in[239:200]
        }),  // input [79:0] in_delay_tap_in          
        .in_delay_tap_out(),  // output [79:0] in_delay_tap_out          

        .delay_locked(delay_locked[3]),  // output delay_locked                      
        .ref_clock(clk),  // input ref_clock                         
        .bitslip({
            bitslip_chx_pulse[63:56], bitslip_chx_pulse[47:40]
        }),  // input bitslip                           
        .clk_in_p(ad9253_dco_p[5]),  // input clk_in_p                          
        .clk_in_n(ad9253_dco_n[5]),  // input clk_in_n
        .clk_div_out(ad9253_clk_div_out[3]),  // output clk_div_out                       
        .clk_reset(~rst_n),  // input clk_reset
        .io_reset(~rst_n)  // input io_reset
    );

    BUFG bufg_dac128s085 (
        .I(ad9253_clk_div_out[0]),
        .O(adc_fco)
    );

    wire [  7:0] async_fifo_full;
    wire [  7:0] async_fifo_empty;
    wire [511:0] ad9253_data_async;

    // ADC1
    assign ad9253_data_async[63:0] = {
        // lane 7
        data_in_to_device[15-8+0*128],
        data_in_to_device[31-8+0*128],
        data_in_to_device[47-8+0*128],
        data_in_to_device[63-8+0*128],
        data_in_to_device[79-8+0*128],
        data_in_to_device[95-8+0*128],
        data_in_to_device[111-8+0*128],
        data_in_to_device[127-8+0*128],

        // lane 6
        data_in_to_device[15-9+0*128],
        data_in_to_device[31-9+0*128],
        data_in_to_device[47-9+0*128],
        data_in_to_device[63-9+0*128],
        data_in_to_device[79-9+0*128],
        data_in_to_device[95-9+0*128],
        data_in_to_device[111-9+0*128],
        data_in_to_device[127-9+0*128],

        // lane 5
        data_in_to_device[15-10+0*128],
        data_in_to_device[31-10+0*128],
        data_in_to_device[47-10+0*128],
        data_in_to_device[63-10+0*128],
        data_in_to_device[79-10+0*128],
        data_in_to_device[95-10+0*128],
        data_in_to_device[111-10+0*128],
        data_in_to_device[127-10+0*128],

        // lane 4
        data_in_to_device[15-11+0*128],
        data_in_to_device[31-11+0*128],
        data_in_to_device[47-11+0*128],
        data_in_to_device[63-11+0*128],
        data_in_to_device[79-11+0*128],
        data_in_to_device[95-11+0*128],
        data_in_to_device[111-11+0*128],
        data_in_to_device[127-11+0*128],

        // lane 3
        data_in_to_device[15-12+0*128],
        data_in_to_device[31-12+0*128],
        data_in_to_device[47-12+0*128],
        data_in_to_device[63-12+0*128],
        data_in_to_device[79-12+0*128],
        data_in_to_device[95-12+0*128],
        data_in_to_device[111-12+0*128],
        data_in_to_device[127-12+0*128],

        // lane 2
        data_in_to_device[15-13+0*128],
        data_in_to_device[31-13+0*128],
        data_in_to_device[47-13+0*128],
        data_in_to_device[63-13+0*128],
        data_in_to_device[79-13+0*128],
        data_in_to_device[95-13+0*128],
        data_in_to_device[111-13+0*128],
        data_in_to_device[127-13+0*128],

        // lane 1
        data_in_to_device[15-14+0*128],
        data_in_to_device[31-14+0*128],
        data_in_to_device[47-14+0*128],
        data_in_to_device[63-14+0*128],
        data_in_to_device[79-14+0*128],
        data_in_to_device[95-14+0*128],
        data_in_to_device[111-14+0*128],
        data_in_to_device[127-14+0*128],

        // lane 0
        data_in_to_device[15-15+0*128],
        data_in_to_device[31-15+0*128],
        data_in_to_device[47-15+0*128],
        data_in_to_device[63-15+0*128],
        data_in_to_device[79-15+0*128],
        data_in_to_device[95-15+0*128],
        data_in_to_device[111-15+0*128],
        data_in_to_device[127-15+0*128]
    };

    async_fifo aync_fifo_adc1 (
        .rst        (~rst_n),                   // input wire rst
        .wr_clk     (ad9253_clk_div_out[0]),    // input wire wr_clk
        .rd_clk     (adc_fco),                  // input wire rd_clk
        .din        (ad9253_data_async[63:0]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                     // input wire wr_en
        .rd_en      (~async_fifo_empty[0]),     // input wire rd_en
        .dout       (ad9253_data_chx[63:0]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[0]),       // output wire full
        .empty      (async_fifo_empty[0]),      // output wire empty
        .wr_rst_busy(),                         // output wire wr_rst_busy
        .rd_rst_busy()                          // output wire rd_rst_busy
    );

    // ADC3
    assign ad9253_data_async[191:128] = {
        // lane 7
        data_in_to_device[15-0+0*128],
        data_in_to_device[31-0+0*128],
        data_in_to_device[47-0+0*128],
        data_in_to_device[63-0+0*128],
        data_in_to_device[79-0+0*128],
        data_in_to_device[95-0+0*128],
        data_in_to_device[111-0+0*128],
        data_in_to_device[127-0+0*128],

        // lane 6
        data_in_to_device[15-1+0*128],
        data_in_to_device[31-1+0*128],
        data_in_to_device[47-1+0*128],
        data_in_to_device[63-1+0*128],
        data_in_to_device[79-1+0*128],
        data_in_to_device[95-1+0*128],
        data_in_to_device[111-1+0*128],
        data_in_to_device[127-1+0*128],

        // lane 5
        data_in_to_device[15-2+0*128],
        data_in_to_device[31-2+0*128],
        data_in_to_device[47-2+0*128],
        data_in_to_device[63-2+0*128],
        data_in_to_device[79-2+0*128],
        data_in_to_device[95-2+0*128],
        data_in_to_device[111-2+0*128],
        data_in_to_device[127-2+0*128],

        // lane 4
        data_in_to_device[15-3+0*128],
        data_in_to_device[31-3+0*128],
        data_in_to_device[47-3+0*128],
        data_in_to_device[63-3+0*128],
        data_in_to_device[79-3+0*128],
        data_in_to_device[95-3+0*128],
        data_in_to_device[111-3+0*128],
        data_in_to_device[127-3+0*128],

        // lane 3
        data_in_to_device[15-4+0*128],
        data_in_to_device[31-4+0*128],
        data_in_to_device[47-4+0*128],
        data_in_to_device[63-4+0*128],
        data_in_to_device[79-4+0*128],
        data_in_to_device[95-4+0*128],
        data_in_to_device[111-4+0*128],
        data_in_to_device[127-4+0*128],

        // lane 2
        data_in_to_device[15-5+0*128],
        data_in_to_device[31-5+0*128],
        data_in_to_device[47-5+0*128],
        data_in_to_device[63-5+0*128],
        data_in_to_device[79-5+0*128],
        data_in_to_device[95-5+0*128],
        data_in_to_device[111-5+0*128],
        data_in_to_device[127-5+0*128],

        // lane 1
        data_in_to_device[15-6+0*128],
        data_in_to_device[31-6+0*128],
        data_in_to_device[47-6+0*128],
        data_in_to_device[63-6+0*128],
        data_in_to_device[79-6+0*128],
        data_in_to_device[95-6+0*128],
        data_in_to_device[111-6+0*128],
        data_in_to_device[127-6+0*128],

        // lane 0
        data_in_to_device[15-7+0*128],
        data_in_to_device[31-7+0*128],
        data_in_to_device[47-7+0*128],
        data_in_to_device[63-7+0*128],
        data_in_to_device[79-7+0*128],
        data_in_to_device[95-7+0*128],
        data_in_to_device[111-7+0*128],
        data_in_to_device[127-7+0*128]
    };

    async_fifo aync_fifo_adc3 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[0]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[191:128]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[2]),        // input wire rd_en
        .dout       (ad9253_data_chx[191:128]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[2]),          // output wire full
        .empty      (async_fifo_empty[2]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ADC2
    assign ad9253_data_async[127:64] = {
        // lane 7
        data_in_to_device[15-8+1*128],
        data_in_to_device[31-8+1*128],
        data_in_to_device[47-8+1*128],
        data_in_to_device[63-8+1*128],
        data_in_to_device[79-8+1*128],
        data_in_to_device[95-8+1*128],
        data_in_to_device[111-8+1*128],
        data_in_to_device[127-8+1*128],

        // lane 6
        data_in_to_device[15-9+1*128],
        data_in_to_device[31-9+1*128],
        data_in_to_device[47-9+1*128],
        data_in_to_device[63-9+1*128],
        data_in_to_device[79-9+1*128],
        data_in_to_device[95-9+1*128],
        data_in_to_device[111-9+1*128],
        data_in_to_device[127-9+1*128],

        // lane 5
        data_in_to_device[15-10+1*128],
        data_in_to_device[31-10+1*128],
        data_in_to_device[47-10+1*128],
        data_in_to_device[63-10+1*128],
        data_in_to_device[79-10+1*128],
        data_in_to_device[95-10+1*128],
        data_in_to_device[111-10+1*128],
        data_in_to_device[127-10+1*128],

        // lane 4
        data_in_to_device[15-11+1*128],
        data_in_to_device[31-11+1*128],
        data_in_to_device[47-11+1*128],
        data_in_to_device[63-11+1*128],
        data_in_to_device[79-11+1*128],
        data_in_to_device[95-11+1*128],
        data_in_to_device[111-11+1*128],
        data_in_to_device[127-11+1*128],

        // lane 3
        data_in_to_device[15-12+1*128],
        data_in_to_device[31-12+1*128],
        data_in_to_device[47-12+1*128],
        data_in_to_device[63-12+1*128],
        data_in_to_device[79-12+1*128],
        data_in_to_device[95-12+1*128],
        data_in_to_device[111-12+1*128],
        data_in_to_device[127-12+1*128],

        // lane 2
        data_in_to_device[15-13+1*128],
        data_in_to_device[31-13+1*128],
        data_in_to_device[47-13+1*128],
        data_in_to_device[63-13+1*128],
        data_in_to_device[79-13+1*128],
        data_in_to_device[95-13+1*128],
        data_in_to_device[111-13+1*128],
        data_in_to_device[127-13+1*128],

        // lane 1
        data_in_to_device[15-14+1*128],
        data_in_to_device[31-14+1*128],
        data_in_to_device[47-14+1*128],
        data_in_to_device[63-14+1*128],
        data_in_to_device[79-14+1*128],
        data_in_to_device[95-14+1*128],
        data_in_to_device[111-14+1*128],
        data_in_to_device[127-14+1*128],

        // lane 0
        data_in_to_device[15-15+1*128],
        data_in_to_device[31-15+1*128],
        data_in_to_device[47-15+1*128],
        data_in_to_device[63-15+1*128],
        data_in_to_device[79-15+1*128],
        data_in_to_device[95-15+1*128],
        data_in_to_device[111-15+1*128],
        data_in_to_device[127-15+1*128]
    };

    async_fifo aync_fifo_adc2 (
        .rst        (~rst_n),                     // input wire rst
        .wr_clk     (ad9253_clk_div_out[1]),      // input wire wr_clk
        .rd_clk     (adc_fco),                    // input wire rd_clk
        .din        (ad9253_data_async[127:64]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                       // input wire wr_en
        .rd_en      (~async_fifo_empty[1]),       // input wire rd_en
        .dout       (ad9253_data_chx[127:64]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[1]),         // output wire full
        .empty      (async_fifo_empty[1]),        // output wire empty
        .wr_rst_busy(),                           // output wire wr_rst_busy
        .rd_rst_busy()                            // output wire rd_rst_busy
    );

    // ADC4
    assign ad9253_data_async[255:192] = {
        // lane 7
        data_in_to_device[15-0+1*128],
        data_in_to_device[31-0+1*128],
        data_in_to_device[47-0+1*128],
        data_in_to_device[63-0+1*128],
        data_in_to_device[79-0+1*128],
        data_in_to_device[95-0+1*128],
        data_in_to_device[111-0+1*128],
        data_in_to_device[127-0+1*128],

        // lane 6
        data_in_to_device[15-1+1*128],
        data_in_to_device[31-1+1*128],
        data_in_to_device[47-1+1*128],
        data_in_to_device[63-1+1*128],
        data_in_to_device[79-1+1*128],
        data_in_to_device[95-1+1*128],
        data_in_to_device[111-1+1*128],
        data_in_to_device[127-1+1*128],

        // lane 5
        data_in_to_device[15-2+1*128],
        data_in_to_device[31-2+1*128],
        data_in_to_device[47-2+1*128],
        data_in_to_device[63-2+1*128],
        data_in_to_device[79-2+1*128],
        data_in_to_device[95-2+1*128],
        data_in_to_device[111-2+1*128],
        data_in_to_device[127-2+1*128],

        // lane 4
        data_in_to_device[15-3+1*128],
        data_in_to_device[31-3+1*128],
        data_in_to_device[47-3+1*128],
        data_in_to_device[63-3+1*128],
        data_in_to_device[79-3+1*128],
        data_in_to_device[95-3+1*128],
        data_in_to_device[111-3+1*128],
        data_in_to_device[127-3+1*128],

        // lane 3
        data_in_to_device[15-4+1*128],
        data_in_to_device[31-4+1*128],
        data_in_to_device[47-4+1*128],
        data_in_to_device[63-4+1*128],
        data_in_to_device[79-4+1*128],
        data_in_to_device[95-4+1*128],
        data_in_to_device[111-4+1*128],
        data_in_to_device[127-4+1*128],

        // lane 2
        data_in_to_device[15-5+1*128],
        data_in_to_device[31-5+1*128],
        data_in_to_device[47-5+1*128],
        data_in_to_device[63-5+1*128],
        data_in_to_device[79-5+1*128],
        data_in_to_device[95-5+1*128],
        data_in_to_device[111-5+1*128],
        data_in_to_device[127-5+1*128],

        // lane 1
        data_in_to_device[15-6+1*128],
        data_in_to_device[31-6+1*128],
        data_in_to_device[47-6+1*128],
        data_in_to_device[63-6+1*128],
        data_in_to_device[79-6+1*128],
        data_in_to_device[95-6+1*128],
        data_in_to_device[111-6+1*128],
        data_in_to_device[127-6+1*128],

        // lane 0
        data_in_to_device[15-7+1*128],
        data_in_to_device[31-7+1*128],
        data_in_to_device[47-7+1*128],
        data_in_to_device[63-7+1*128],
        data_in_to_device[79-7+1*128],
        data_in_to_device[95-7+1*128],
        data_in_to_device[111-7+1*128],
        data_in_to_device[127-7+1*128]
    };

    async_fifo aync_fifo_adc4 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[1]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[255:192]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[3]),        // input wire rd_en
        .dout       (ad9253_data_chx[255:192]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[3]),          // output wire full
        .empty      (async_fifo_empty[3]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ADC5
    assign ad9253_data_async[319:256] = {
        // lane 7
        data_in_to_device[15-8+2*128],
        data_in_to_device[31-8+2*128],
        data_in_to_device[47-8+2*128],
        data_in_to_device[63-8+2*128],
        data_in_to_device[79-8+2*128],
        data_in_to_device[95-8+2*128],
        data_in_to_device[111-8+2*128],
        data_in_to_device[127-8+2*128],

        // lane 6
        data_in_to_device[15-9+2*128],
        data_in_to_device[31-9+2*128],
        data_in_to_device[47-9+2*128],
        data_in_to_device[63-9+2*128],
        data_in_to_device[79-9+2*128],
        data_in_to_device[95-9+2*128],
        data_in_to_device[111-9+2*128],
        data_in_to_device[127-9+2*128],

        // lane 5
        data_in_to_device[15-10+2*128],
        data_in_to_device[31-10+2*128],
        data_in_to_device[47-10+2*128],
        data_in_to_device[63-10+2*128],
        data_in_to_device[79-10+2*128],
        data_in_to_device[95-10+2*128],
        data_in_to_device[111-10+2*128],
        data_in_to_device[127-10+2*128],

        // lane 4
        data_in_to_device[15-11+2*128],
        data_in_to_device[31-11+2*128],
        data_in_to_device[47-11+2*128],
        data_in_to_device[63-11+2*128],
        data_in_to_device[79-11+2*128],
        data_in_to_device[95-11+2*128],
        data_in_to_device[111-11+2*128],
        data_in_to_device[127-11+2*128],

        // lane 3
        data_in_to_device[15-12+2*128],
        data_in_to_device[31-12+2*128],
        data_in_to_device[47-12+2*128],
        data_in_to_device[63-12+2*128],
        data_in_to_device[79-12+2*128],
        data_in_to_device[95-12+2*128],
        data_in_to_device[111-12+2*128],
        data_in_to_device[127-12+2*128],

        // lane 2
        data_in_to_device[15-13+2*128],
        data_in_to_device[31-13+2*128],
        data_in_to_device[47-13+2*128],
        data_in_to_device[63-13+2*128],
        data_in_to_device[79-13+2*128],
        data_in_to_device[95-13+2*128],
        data_in_to_device[111-13+2*128],
        data_in_to_device[127-13+2*128],

        // lane 1
        data_in_to_device[15-14+2*128],
        data_in_to_device[31-14+2*128],
        data_in_to_device[47-14+2*128],
        data_in_to_device[63-14+2*128],
        data_in_to_device[79-14+2*128],
        data_in_to_device[95-14+2*128],
        data_in_to_device[111-14+2*128],
        data_in_to_device[127-14+2*128],

        // lane 0
        data_in_to_device[15-15+2*128],
        data_in_to_device[31-15+2*128],
        data_in_to_device[47-15+2*128],
        data_in_to_device[63-15+2*128],
        data_in_to_device[79-15+2*128],
        data_in_to_device[95-15+2*128],
        data_in_to_device[111-15+2*128],
        data_in_to_device[127-15+2*128]
    };

    async_fifo aync_fifo_adc5 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[2]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[319:256]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[4]),        // input wire rd_en
        .dout       (ad9253_data_chx[319:256]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[4]),          // output wire full
        .empty      (async_fifo_empty[4]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ADC7
    assign ad9253_data_async[447:384] = {
        // lane 7
        data_in_to_device[15-0+2*128],
        data_in_to_device[31-0+2*128],
        data_in_to_device[47-0+2*128],
        data_in_to_device[63-0+2*128],
        data_in_to_device[79-0+2*128],
        data_in_to_device[95-0+2*128],
        data_in_to_device[111-0+2*128],
        data_in_to_device[127-0+2*128],

        // lane 6
        data_in_to_device[15-1+2*128],
        data_in_to_device[31-1+2*128],
        data_in_to_device[47-1+2*128],
        data_in_to_device[63-1+2*128],
        data_in_to_device[79-1+2*128],
        data_in_to_device[95-1+2*128],
        data_in_to_device[111-1+2*128],
        data_in_to_device[127-1+2*128],

        // lane 5
        data_in_to_device[15-2+2*128],
        data_in_to_device[31-2+2*128],
        data_in_to_device[47-2+2*128],
        data_in_to_device[63-2+2*128],
        data_in_to_device[79-2+2*128],
        data_in_to_device[95-2+2*128],
        data_in_to_device[111-2+2*128],
        data_in_to_device[127-2+2*128],

        // lane 4
        data_in_to_device[15-3+2*128],
        data_in_to_device[31-3+2*128],
        data_in_to_device[47-3+2*128],
        data_in_to_device[63-3+2*128],
        data_in_to_device[79-3+2*128],
        data_in_to_device[95-3+2*128],
        data_in_to_device[111-3+2*128],
        data_in_to_device[127-3+2*128],

        // lane 3
        data_in_to_device[15-4+2*128],
        data_in_to_device[31-4+2*128],
        data_in_to_device[47-4+2*128],
        data_in_to_device[63-4+2*128],
        data_in_to_device[79-4+2*128],
        data_in_to_device[95-4+2*128],
        data_in_to_device[111-4+2*128],
        data_in_to_device[127-4+2*128],

        // lane 2
        data_in_to_device[15-5+2*128],
        data_in_to_device[31-5+2*128],
        data_in_to_device[47-5+2*128],
        data_in_to_device[63-5+2*128],
        data_in_to_device[79-5+2*128],
        data_in_to_device[95-5+2*128],
        data_in_to_device[111-5+2*128],
        data_in_to_device[127-5+2*128],

        // lane 1
        data_in_to_device[15-6+2*128],
        data_in_to_device[31-6+2*128],
        data_in_to_device[47-6+2*128],
        data_in_to_device[63-6+2*128],
        data_in_to_device[79-6+2*128],
        data_in_to_device[95-6+2*128],
        data_in_to_device[111-6+2*128],
        data_in_to_device[127-6+2*128],

        // lane 0
        data_in_to_device[15-7+2*128],
        data_in_to_device[31-7+2*128],
        data_in_to_device[47-7+2*128],
        data_in_to_device[63-7+2*128],
        data_in_to_device[79-7+2*128],
        data_in_to_device[95-7+2*128],
        data_in_to_device[111-7+2*128],
        data_in_to_device[127-7+2*128]
    };

    async_fifo aync_fifo_adc7 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[2]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[447:384]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[6]),        // input wire rd_en
        .dout       (ad9253_data_chx[447:384]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[6]),          // output wire full
        .empty      (async_fifo_empty[6]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ADC6
    assign ad9253_data_async[383:320] = {
        // lane 7
        data_in_to_device[15-8+3*128],
        data_in_to_device[31-8+3*128],
        data_in_to_device[47-8+3*128],
        data_in_to_device[63-8+3*128],
        data_in_to_device[79-8+3*128],
        data_in_to_device[95-8+3*128],
        data_in_to_device[111-8+3*128],
        data_in_to_device[127-8+3*128],

        // lane 6
        data_in_to_device[15-9+3*128],
        data_in_to_device[31-9+3*128],
        data_in_to_device[47-9+3*128],
        data_in_to_device[63-9+3*128],
        data_in_to_device[79-9+3*128],
        data_in_to_device[95-9+3*128],
        data_in_to_device[111-9+3*128],
        data_in_to_device[127-9+3*128],

        // lane 5
        data_in_to_device[15-10+3*128],
        data_in_to_device[31-10+3*128],
        data_in_to_device[47-10+3*128],
        data_in_to_device[63-10+3*128],
        data_in_to_device[79-10+3*128],
        data_in_to_device[95-10+3*128],
        data_in_to_device[111-10+3*128],
        data_in_to_device[127-10+3*128],

        // lane 4
        data_in_to_device[15-11+3*128],
        data_in_to_device[31-11+3*128],
        data_in_to_device[47-11+3*128],
        data_in_to_device[63-11+3*128],
        data_in_to_device[79-11+3*128],
        data_in_to_device[95-11+3*128],
        data_in_to_device[111-11+3*128],
        data_in_to_device[127-11+3*128],

        // lane 3
        data_in_to_device[15-12+3*128],
        data_in_to_device[31-12+3*128],
        data_in_to_device[47-12+3*128],
        data_in_to_device[63-12+3*128],
        data_in_to_device[79-12+3*128],
        data_in_to_device[95-12+3*128],
        data_in_to_device[111-12+3*128],
        data_in_to_device[127-12+3*128],

        // lane 2
        data_in_to_device[15-13+3*128],
        data_in_to_device[31-13+3*128],
        data_in_to_device[47-13+3*128],
        data_in_to_device[63-13+3*128],
        data_in_to_device[79-13+3*128],
        data_in_to_device[95-13+3*128],
        data_in_to_device[111-13+3*128],
        data_in_to_device[127-13+3*128],

        // lane 1
        data_in_to_device[15-14+3*128],
        data_in_to_device[31-14+3*128],
        data_in_to_device[47-14+3*128],
        data_in_to_device[63-14+3*128],
        data_in_to_device[79-14+3*128],
        data_in_to_device[95-14+3*128],
        data_in_to_device[111-14+3*128],
        data_in_to_device[127-14+3*128],

        // lane 0
        data_in_to_device[15-15+3*128],
        data_in_to_device[31-15+3*128],
        data_in_to_device[47-15+3*128],
        data_in_to_device[63-15+3*128],
        data_in_to_device[79-15+3*128],
        data_in_to_device[95-15+3*128],
        data_in_to_device[111-15+3*128],
        data_in_to_device[127-15+3*128]
    };

    async_fifo aync_fifo_adc6 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[3]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[383:320]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[5]),        // input wire rd_en
        .dout       (ad9253_data_chx[383:320]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[5]),          // output wire full
        .empty      (async_fifo_empty[5]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ADC8
    assign ad9253_data_async[511:448] = {
        // lane 7
        data_in_to_device[15-0+3*128],
        data_in_to_device[31-0+3*128],
        data_in_to_device[47-0+3*128],
        data_in_to_device[63-0+3*128],
        data_in_to_device[79-0+3*128],
        data_in_to_device[95-0+3*128],
        data_in_to_device[111-0+3*128],
        data_in_to_device[127-0+3*128],

        // lane 6
        data_in_to_device[15-1+3*128],
        data_in_to_device[31-1+3*128],
        data_in_to_device[47-1+3*128],
        data_in_to_device[63-1+3*128],
        data_in_to_device[79-1+3*128],
        data_in_to_device[95-1+3*128],
        data_in_to_device[111-1+3*128],
        data_in_to_device[127-1+3*128],

        // lane 5
        data_in_to_device[15-2+3*128],
        data_in_to_device[31-2+3*128],
        data_in_to_device[47-2+3*128],
        data_in_to_device[63-2+3*128],
        data_in_to_device[79-2+3*128],
        data_in_to_device[95-2+3*128],
        data_in_to_device[111-2+3*128],
        data_in_to_device[127-2+3*128],

        // lane 4
        data_in_to_device[15-3+3*128],
        data_in_to_device[31-3+3*128],
        data_in_to_device[47-3+3*128],
        data_in_to_device[63-3+3*128],
        data_in_to_device[79-3+3*128],
        data_in_to_device[95-3+3*128],
        data_in_to_device[111-3+3*128],
        data_in_to_device[127-3+3*128],

        // lane 3
        data_in_to_device[15-4+3*128],
        data_in_to_device[31-4+3*128],
        data_in_to_device[47-4+3*128],
        data_in_to_device[63-4+3*128],
        data_in_to_device[79-4+3*128],
        data_in_to_device[95-4+3*128],
        data_in_to_device[111-4+3*128],
        data_in_to_device[127-4+3*128],

        // lane 2
        data_in_to_device[15-5+3*128],
        data_in_to_device[31-5+3*128],
        data_in_to_device[47-5+3*128],
        data_in_to_device[63-5+3*128],
        data_in_to_device[79-5+3*128],
        data_in_to_device[95-5+3*128],
        data_in_to_device[111-5+3*128],
        data_in_to_device[127-5+3*128],

        // lane 1
        data_in_to_device[15-6+3*128],
        data_in_to_device[31-6+3*128],
        data_in_to_device[47-6+3*128],
        data_in_to_device[63-6+3*128],
        data_in_to_device[79-6+3*128],
        data_in_to_device[95-6+3*128],
        data_in_to_device[111-6+3*128],
        data_in_to_device[127-6+3*128],

        // lane 0
        data_in_to_device[15-7+3*128],
        data_in_to_device[31-7+3*128],
        data_in_to_device[47-7+3*128],
        data_in_to_device[63-7+3*128],
        data_in_to_device[79-7+3*128],
        data_in_to_device[95-7+3*128],
        data_in_to_device[111-7+3*128],
        data_in_to_device[127-7+3*128]
    };

    async_fifo aync_fifo_adc8 (
        .rst        (~rst_n),                      // input wire rst
        .wr_clk     (ad9253_clk_div_out[3]),       // input wire wr_clk
        .rd_clk     (adc_fco),                     // input wire rd_clk
        .din        (ad9253_data_async[511:448]),  // input wire [63 : 0] din
        .wr_en      (1'b1),                        // input wire wr_en
        .rd_en      (~async_fifo_empty[7]),        // input wire rd_en
        .dout       (ad9253_data_chx[511:448]),    // output wire [63 : 0] dout
        .full       (async_fifo_full[7]),          // output wire full
        .empty      (async_fifo_empty[7]),         // output wire empty
        .wr_rst_busy(),                            // output wire wr_rst_busy
        .rd_rst_busy()                             // output wire rd_rst_busy
    );

    // ila_0 ila_ad9253_top_inst (
    //     .clk    (adc_fco),
    //     .probe0 (0),
    //     .probe1 (0),
    //     .probe2  (ad9253_data_chx[71:64]),
    //     .probe3  (ad9253_data_chx[79:72]),
    //     .probe4  (ad9253_data_chx[87:80]),
    //     .probe5  (ad9253_data_chx[95:88]),
    //     .probe6  (ad9253_data_chx[103:96]),
    //     .probe7  (ad9253_data_chx[111:104]),
    //     .probe8  (ad9253_data_chx[119:112]),
    //     .probe9  (ad9253_data_chx[127:120]),
    //     .probe10(bitslip_chx[15:0])
    // );
endmodule
