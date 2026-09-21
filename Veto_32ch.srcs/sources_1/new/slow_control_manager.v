// slow_control_manager
// 仿照 uart_controller_32ch.v 的状态机改写。
// 区别：原来的慢控通过 UART(8bit 串行) 收发，现在改为通过 GT 收发。
//
// 跨时钟域：状态机运行在 rxoutclk 域（clk），发送数据通过内部异步 FIFO
//   跨到 txoutclk 域（clk_tx），读侧自动消费，main 直接用 sc_fifo_dout/valid。
//   数据格式（16bit）：data[15:8] = 板子编号，data[7:0] = 慢控数据/命令
// brd_num：第一次收到慢控数据时锁存 user_rx_data[15:8]，
//          之后再收到的数据高 8 位与 brd_num 匹配才处理。
module slow_control_manager #(
    parameter ADC_NUM = 8,
    parameter CHANNEL_NUM = 4
) (
    input  wire clk,       // rxoutclk 域（状态机 + FIFO 写侧）
    input  wire clk_tx,    // txoutclk 域（FIFO 读侧）
    input  wire rst_n,

    // GT 慢控收发接口
    input  wire [15:0] user_rx_data,
    input  wire        user_rx_data_valid,

    // FIFO 读侧（txoutclk 域，供 main 接 GT user_tx_data）
    //   握手：main 通过 sc_fifo_empty 判断是否有数据，用 sc_fifo_rd_en 逐字弹出
    output wire [15:0] sc_fifo_dout,
    input  wire        sc_fifo_rd_en,     // main 控制读（txoutclk 域）
    output wire        sc_fifo_empty,    // FIFO 真实空标志（txoutclk 域）

    // 标志
    output wire        slow_control_active,   // 慢控传输进行中（state != IDLE）
    output reg  [7:0]  brd_num,               // 锁存的板子编号
    output wire        ack_req,                // 收到数据需回复ack帧

    // Si5345接口
    input  wire        si5345_spi_busy,
    input  wire [ 3:0] si5345_bit_cnt,
    input  wire        si5345_spi_done,
    output reg         si5345_rw,
    output reg  [15:0] si5345_data_in,
    output reg         si5345_spi_start,
    output reg         si5345_cs_n,
    input  wire [15:0] si5345_data_out,

    // AD9253接口
    input  wire               ad9253_spi_done,
    input  wire               ad9253_spi_busy,
    output reg                ad9253_rw,
    output reg  [        7:0] ad9253_data_in,
    output reg                ad9253_spi_start,
    output reg  [ADC_NUM-1:0] ad9253_cs_n,
    input  wire [        7:0] ad9253_data_out,
    output reg  [ADC_NUM-1:0] ad9253_config_done,

    // DAC128S085接口
    input wire [ADC_NUM-1:0] dac128s085_spi_done,
    input wire [ADC_NUM-1:0] dac128s085_spi_busy,

    output reg [ADC_NUM*16-1:0] dac128s085_data_in,
    output reg [   ADC_NUM-1:0] dac128s085_spi_start,
    output reg [   ADC_NUM-1:0] dac128s085_cs_n,

    // Bit slip控制
    input  wire                               ad9253_fco_rise,
    input  wire [ADC_NUM*CHANNEL_NUM*2*8-1:0] ad9253_data_chx,
    output reg  [    ADC_NUM*CHANNEL_NUM*2:0] bitslip_chx,

    // idelay
    output reg [ADC_NUM*CHANNEL_NUM*2*5-1:0] idelay_tap,
    output reg                               idelay_ld,

    // tdc
    input  wire [10*ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_in,
    input  wire [   ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_en,
    output reg  [   ADC_NUM*CHANNEL_NUM - 1:0] cali_flag,

    output reg  [ 5:0] state,
    output reg  [ 5:0] next_state
);

    //--------------------------------
    // 接收侧：clk 接 clk_rxoutclk_bufg，user_rx_data/user_rx_data_valid
    // 与 clk 同步（time_sync_manager 输出，位于 rxoutclk 域），无需同步。
    //--------------------------------
    wire rx_valid_pulse = user_rx_data_valid;    // 同步域内的有效脉冲
    wire [7:0] rx_addr = user_rx_data[15:8];
    wire [7:0] rx_data = user_rx_data[7:0];

    // brd_num 锁存 + 板号匹配
    reg brd_num_set;
    wire addr_match = brd_num_set ? (rx_addr == brd_num) : 1'b1;
    wire rx_use = rx_valid_pulse & addr_match;

    // ack_req: 每次 rx_use 都拉高一个周期，main 据此发送 FFF3+FFFF ack 帧
    reg ack_req_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ack_req_r <= 1'b0;
        else
            ack_req_r <= rx_use;
    end
    assign ack_req = ack_req_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brd_num    <= 8'd0;
            brd_num_set <= 1'b0;
        end else if (rx_valid_pulse && !brd_num_set) begin
            brd_num     <= rx_addr;
            brd_num_set <= 1'b1;
        end
    end

    //--------------------------------
    // 状态机
    //--------------------------------
    localparam IDLE = 6'd0;
    localparam GET_SI5345_CONF_BYTES = 6'd1;
    localparam RECEIVE_SI5345_CONF_DATA = 6'd2;
    localparam CONFIG_SI5345 = 6'd3;

    localparam RECEIVE_SI5345_READ_DATA = 6'd4;
    localparam READ_SI5345_REG = 6'd5;
    localparam SEND_SI5345_DATA = 6'd6;

    localparam GET_AD9253_NUM_WR = 6'd7;
    localparam GET_AD9253_CONF_BYTES = 6'd8;
    localparam RECEIVE_AD9253_CONF_DATA = 6'd9;
    localparam CONFIG_AD9253 = 6'd10;

    localparam GET_AD9253_NUM_RD = 6'd11;
    localparam RECEIVE_AD9253_READ_DATA = 6'd12;
    localparam READ_AD9253_REG = 6'd13;
    localparam SEND_AD9253_DATA = 6'd14;

    localparam GET_AD9253_BIT_SLIP_NUM = 6'd15;
    localparam AD9253_BIT_SLIP = 6'd16;
    localparam SEND_TEST_DATA = 6'd17;

    localparam GET_AD9253_IDELAY_NUM = 6'd18;
    localparam IDELAY = 6'd19;

    localparam GET_DAC128S085_NUM = 6'd20;
    localparam RECEIVE_DAC128S085_CONF_DATA = 6'd21;
    localparam CONFIG_DAC128S085 = 6'd22;

    localparam WAIT_AD9253_CONFIG_DONE = 6'd23;

    localparam GET_TDC_NUM = 6'd24;
    localparam TDC_CALI = 6'd25;
    localparam TDC_CALI_SEND_DATA = 6'd26;

    // reg  [ 5:0] state;
    // reg  [ 5:0] next_state;

    // 发送节拍：每个发送状态内对发出的字做 1 拍间隔
    reg send_phase;   // 0=本拍发数据，1=间隔后退出

    // 计数器和控制信号
    reg  [ 1:0] si5345_receive_conf_bytes_counter;
    reg  [15:0] si5345_conf_bytes;
    reg  [15:0] si5345_byte_counter;
    reg  [15:0] si5345_data_in_buffer;
    reg         si5345_byte_half;
    reg         si5345_config_done;
    reg         si5345_read_done;

    reg  [ 1:0] ad9253_receive_conf_bytes_counter;
    reg  [15:0] ad9253_conf_bytes;
    reg  [15:0] ad9253_byte_counter;
    reg  [23:0] ad9253_data_in_buffer;
    reg  [ 1:0] ad9253_byte_three;
    reg         ad9253_read_done;
    reg         ad9253_loop_done;
    reg  [ 3:0] ad9253_fco_cnt;
    reg  [ 3:0] ad9253_num;
    reg  [ 7:0] ad9253_bit_slip_num;
    reg  [ 7:0] ad9253_idelay_num;
    reg  [31:0] adc_wait_cnt;
    wire [ 1:0] ad9253_fco_sel;

    assign ad9253_fco_sel =
    ((ad9253_bit_slip_num / 8) == 0 ||
     (ad9253_bit_slip_num / 8) == 2) ? 2'd0 :

    ((ad9253_bit_slip_num / 8) == 1 ||
     (ad9253_bit_slip_num / 8) == 3) ? 2'd1 :

    ((ad9253_bit_slip_num / 8) == 4 ||
     (ad9253_bit_slip_num / 8) == 6) ? 2'd2 :

                                                 2'd3;

    reg        dac128s085_byte_half;
    reg [15:0] dac128s085_data_in_buffer;
    reg [ 7:0] dac128s085_config_done;
    reg [ 3:0] dac128s085_num;

    reg [ 7:0] cs_n_delay_counter;
    reg        cs_n_wait_flag;

    reg [ 3:0] idelay_time_cnt;
    reg        idelay_done;
    reg        idelay_flag;

    reg        tdc_cali_done;
    reg [ 9:0] tdc_bin;
    reg [ 4:0] tdc_num;

     // 状态寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    assign slow_control_active = (state != IDLE);

    // 状态转移逻辑
    always @(*) begin
        case (state)
            IDLE: begin
                if (rx_use && rx_data == 8'hF0) next_state = GET_SI5345_CONF_BYTES;
                else if (rx_use && rx_data == 8'hF1)
                    next_state = RECEIVE_SI5345_READ_DATA;
                else if (rx_use && rx_data == 8'hF2) next_state = GET_AD9253_NUM_WR;
                else if (rx_use && rx_data == 8'hF3) next_state = GET_AD9253_NUM_RD;
                else if (rx_use && rx_data == 8'hF4)
                    next_state = GET_AD9253_BIT_SLIP_NUM;
                else if (rx_use && rx_data == 8'hF5)
                    next_state = GET_AD9253_IDELAY_NUM;
                else if (rx_use && rx_data == 8'hF6) next_state = GET_DAC128S085_NUM;
                else if (rx_use && rx_data == 8'hF7) next_state = GET_TDC_NUM;
                else next_state = IDLE;
            end

            GET_SI5345_CONF_BYTES: begin
                if (si5345_receive_conf_bytes_counter >= 2) next_state = RECEIVE_SI5345_CONF_DATA;
                else next_state = GET_SI5345_CONF_BYTES;
            end

            RECEIVE_SI5345_CONF_DATA: begin
                if (si5345_byte_half == 1 && rx_use) next_state = CONFIG_SI5345;
                else next_state = RECEIVE_SI5345_CONF_DATA;
            end

            CONFIG_SI5345: begin
                if (si5345_spi_done) begin
                    if (si5345_byte_counter >= si5345_conf_bytes) next_state = IDLE;
                    else next_state = RECEIVE_SI5345_CONF_DATA;
                end else next_state = CONFIG_SI5345;
            end

            RECEIVE_SI5345_READ_DATA: begin
                if (si5345_byte_half == 1 && rx_use) next_state = READ_SI5345_REG;
                else next_state = RECEIVE_SI5345_READ_DATA;
            end

            READ_SI5345_REG: begin
                if (si5345_spi_done) begin
                    if (si5345_read_done) next_state = SEND_SI5345_DATA;
                    else next_state = RECEIVE_SI5345_READ_DATA;
                end else next_state = READ_SI5345_REG;
            end

            SEND_SI5345_DATA: begin
                if (send_phase == 1'b1) next_state = IDLE;
                else next_state = SEND_SI5345_DATA;
            end

            GET_AD9253_NUM_WR: begin
                if (rx_use) next_state = GET_AD9253_CONF_BYTES;
                else next_state = GET_AD9253_NUM_WR;
            end

            GET_AD9253_CONF_BYTES: begin
                if (ad9253_receive_conf_bytes_counter >= 2) next_state = RECEIVE_AD9253_CONF_DATA;
                else next_state = GET_AD9253_CONF_BYTES;
            end

            RECEIVE_AD9253_CONF_DATA: begin
                if (ad9253_byte_three == 2 && rx_use)
                    next_state = CONFIG_AD9253;
                else next_state = RECEIVE_AD9253_CONF_DATA;
            end

            CONFIG_AD9253: begin
                if (ad9253_loop_done) begin
                    if (ad9253_byte_counter >= ad9253_conf_bytes)
                        next_state = WAIT_AD9253_CONFIG_DONE;
                    else next_state = RECEIVE_AD9253_CONF_DATA;
                end else next_state = CONFIG_AD9253;
            end

            WAIT_AD9253_CONFIG_DONE: begin
                if (ad9253_config_done[ad9253_num]) next_state = IDLE;
                else next_state = WAIT_AD9253_CONFIG_DONE;
            end

            GET_AD9253_NUM_RD: begin
                if (rx_use) next_state = RECEIVE_AD9253_READ_DATA;
                else next_state = GET_AD9253_NUM_RD;
            end

            RECEIVE_AD9253_READ_DATA: begin
                if (ad9253_byte_three == 1 && rx_use) next_state = READ_AD9253_REG;
                else next_state = RECEIVE_AD9253_READ_DATA;
            end

            READ_AD9253_REG: begin
                if (ad9253_read_done) next_state = SEND_AD9253_DATA;
                else next_state = READ_AD9253_REG;
            end

            SEND_AD9253_DATA: begin
                if (send_phase == 1'b1) next_state = IDLE;
                else next_state = SEND_AD9253_DATA;
            end

            GET_AD9253_BIT_SLIP_NUM: begin
                if (rx_use) next_state = AD9253_BIT_SLIP;
                else next_state = GET_AD9253_BIT_SLIP_NUM;
            end

            AD9253_BIT_SLIP: begin
                if (ad9253_fco_cnt == 4'd15) next_state = SEND_TEST_DATA;
                else next_state = AD9253_BIT_SLIP;
            end

            SEND_TEST_DATA: begin
                if (send_phase == 1'b1) next_state = IDLE;
                else next_state = SEND_TEST_DATA;
            end

            GET_DAC128S085_NUM: begin
                if (rx_use) next_state = RECEIVE_DAC128S085_CONF_DATA;
                else next_state = GET_DAC128S085_NUM;
            end

            RECEIVE_DAC128S085_CONF_DATA: begin
                if (dac128s085_byte_half == 1 && rx_use) next_state = CONFIG_DAC128S085;
                else next_state = RECEIVE_DAC128S085_CONF_DATA;
            end

            CONFIG_DAC128S085: begin
                if (dac128s085_spi_done) next_state = IDLE;
                else next_state = CONFIG_DAC128S085;
            end

            GET_AD9253_IDELAY_NUM: begin
                if (rx_use) next_state = IDELAY;
                else next_state = GET_AD9253_IDELAY_NUM;
            end

            IDELAY: begin
                if (idelay_done) next_state = IDLE;
                else next_state = IDELAY;
            end

            GET_TDC_NUM: begin
                if (rx_use) next_state = TDC_CALI;
                else next_state = GET_TDC_NUM;
            end

            TDC_CALI: begin
                if (tdc_cali_en[tdc_num]) next_state = TDC_CALI_SEND_DATA;
                else next_state = TDC_CALI;
            end

            TDC_CALI_SEND_DATA: begin
                if (tdc_cali_done) next_state = IDLE;
                else next_state = TDC_CALI_SEND_DATA;
            end

            default: next_state = IDLE;
        endcase
    end

    //--------------------------------
    // 发送 FIFO 数据和有效信号 (rx_use 优先级最高：每次 rx_use 都推送 0xFFFF ack)
    //--------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slow_control_data       <= 16'd0;
            slow_control_data_valid <= 1'b0;
        end else begin
            case (state)
                SEND_SI5345_DATA: begin
                    if (send_phase == 1'b0) begin
                        slow_control_data       <= {8'b0, si5345_data_out[7:0]};
                        slow_control_data_valid <= 1'b1;
                    end else begin
                        slow_control_data_valid <= 1'b0;
                    end
                end
                SEND_AD9253_DATA: begin
                    if (send_phase == 1'b0) begin
                        slow_control_data       <= {8'b0, ad9253_data_out[7:0]};
                        slow_control_data_valid <= 1'b1;
                    end else begin
                        slow_control_data_valid <= 1'b0;
                    end
                end
                SEND_TEST_DATA: begin
                    if (send_phase == 1'b0) begin
                        slow_control_data       <= {8'b0, ad9253_data_chx[ad9253_bit_slip_num*8+:8]};
                        slow_control_data_valid <= 1'b1;
                    end else begin
                        slow_control_data_valid <= 1'b0;
                    end
                end
                TDC_CALI_SEND_DATA: begin
                    if (send_phase == 1'b0) begin
                        slow_control_data       <= {6'b0, tdc_bin};
                        slow_control_data_valid <= 1'b1;
                    end else begin
                        slow_control_data_valid <= 1'b0;
                    end
                end
                default: begin
                    slow_control_data_valid <= 1'b0;
                end
            endcase
        end
    end

    // 主要控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            si5345_conf_bytes <= 0;
            si5345_byte_counter <= 0;
            si5345_receive_conf_bytes_counter <= 0;
            si5345_data_in_buffer <= 0;
            si5345_spi_start <= 0;
            si5345_cs_n <= 1;
            si5345_rw <= 0;
            si5345_byte_half <= 0;
            si5345_config_done <= 0;
            si5345_read_done <= 0;

            ad9253_conf_bytes <= 0;
            ad9253_byte_counter <= 0;
            ad9253_receive_conf_bytes_counter <= 0;
            ad9253_data_in_buffer <= 0;
            ad9253_cs_n <= 8'b11111111;
            ad9253_rw <= 0;
            ad9253_byte_three <= 0;
            ad9253_spi_start <= 0;
            ad9253_read_done <= 0;
            ad9253_loop_done <= 0;
            ad9253_fco_cnt <= 0;
            ad9253_num <= 0;
            ad9253_bit_slip_num <= 0;
            ad9253_idelay_num <= 0;

            dac128s085_data_in_buffer <= 0;
            dac128s085_cs_n <= 1;
            dac128s085_byte_half <= 0;
            dac128s085_spi_start <= 0;
            dac128s085_config_done <= 0;
            dac128s085_num <= 0;
            dac128s085_data_in <= 0;

            cs_n_wait_flag <= 0;
            cs_n_delay_counter <= 0;
            bitslip_chx <= 0;
            adc_wait_cnt <= 0;

            ad9253_config_done <= 0;

            idelay_tap <= 0;
            idelay_ld <= 0;
            idelay_time_cnt <= 0;
            idelay_done <= 0;
            idelay_flag <= 0;

            tdc_cali_done <= 0;
            cali_flag <= 0;
            tdc_bin <= 0;
            tdc_num <= 0;

            // 发送
            send_phase <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    si5345_conf_bytes <= 0;
                    si5345_byte_counter <= 0;
                    si5345_receive_conf_bytes_counter <= 0;
                    si5345_data_in_buffer <= 0;
                    si5345_cs_n <= 1;
                    si5345_rw <= 0;
                    si5345_byte_half <= 0;
                    si5345_config_done <= 0;
                    si5345_spi_start <= 0;
                    si5345_read_done <= 0;

                    ad9253_conf_bytes <= 0;
                    ad9253_byte_counter <= 0;
                    ad9253_receive_conf_bytes_counter <= 0;
                    ad9253_data_in_buffer <= 0;
                    ad9253_cs_n <= 8'b11111111;
                    ad9253_rw <= 0;
                    ad9253_byte_three <= 0;
                    ad9253_spi_start <= 0;
                    ad9253_read_done <= 0;
                    ad9253_loop_done <= 0;
                    ad9253_fco_cnt <= 0;
                    ad9253_num <= 0;
                    ad9253_bit_slip_num <= 0;
                    ad9253_idelay_num <= 0;

                    dac128s085_data_in_buffer <= 0;
                    dac128s085_cs_n <= 1;
                    dac128s085_byte_half <= 0;
                    dac128s085_spi_start <= 0;
                    dac128s085_config_done <= 0;
                    dac128s085_num <= 0;
                    dac128s085_data_in <= 0;

                    cs_n_wait_flag <= 0;
                    cs_n_delay_counter <= 0;

                    bitslip_chx <= 0;
                    adc_wait_cnt <= 0;

                    idelay_ld <= 0;
                    idelay_time_cnt <= 0;
                    idelay_done <= 0;
                    idelay_flag <= 0;

                    tdc_cali_done <= 0;
                    cali_flag <= 0;
                    tdc_bin <= 0;
                    tdc_num <= 0;

                    // 发送
                    send_phase <= 1'b0;
                end

                GET_SI5345_CONF_BYTES: begin
                    if (si5345_receive_conf_bytes_counter == 0 && rx_use) begin
                        si5345_conf_bytes[15:8] <= rx_data;
                        si5345_receive_conf_bytes_counter <= si5345_receive_conf_bytes_counter + 1;
                    end else if (si5345_receive_conf_bytes_counter == 1 && rx_use) begin
                        si5345_conf_bytes[7:0] <= rx_data;
                        si5345_receive_conf_bytes_counter <= si5345_receive_conf_bytes_counter + 1;
                    end
                end

                RECEIVE_SI5345_CONF_DATA: begin
                    if (si5345_byte_counter < si5345_conf_bytes && rx_use) begin
                        if (si5345_byte_half == 0) begin
                            si5345_data_in_buffer[15:8] <= rx_data;
                            si5345_byte_half <= 1;
                        end else begin
                            si5345_data_in_buffer[7:0] <= rx_data;
                            si5345_byte_half <= 0;
                        end
                        si5345_byte_counter <= si5345_byte_counter + 1;
                    end
                end

                CONFIG_SI5345: begin
                    si5345_data_in <= si5345_data_in_buffer;
                    si5345_rw <= 0;
                    si5345_cs_n <= 0;

                    if (!si5345_spi_busy && next_state == CONFIG_SI5345) begin
                        si5345_spi_start <= 1;
                    end else begin
                        si5345_spi_start <= 0;
                    end

                    if (si5345_spi_done) begin
                        si5345_cs_n <= 1;
                    end

                    if (si5345_byte_counter >= si5345_conf_bytes && si5345_spi_done) begin
                        si5345_config_done <= 1;
                    end
                end

                RECEIVE_SI5345_READ_DATA: begin
                    if (si5345_byte_counter < 4'd8 && rx_use) begin
                        if (si5345_byte_half == 0) begin
                            si5345_data_in_buffer[15:8] <= rx_data;
                            si5345_byte_half <= 1;
                        end else begin
                            si5345_data_in_buffer[7:0] <= rx_data;
                            si5345_byte_half <= 0;
                        end
                        si5345_byte_counter <= si5345_byte_counter + 1;
                    end
                end

                READ_SI5345_REG: begin
                    si5345_data_in <= si5345_data_in_buffer;

                    if (si5345_bit_cnt <= 7 && si5345_byte_counter == 8) si5345_rw <= 1;
                    else si5345_rw <= 0;

                    si5345_cs_n <= 0;

                    if (!si5345_spi_busy && next_state == READ_SI5345_REG) begin
                        si5345_spi_start <= 1;
                    end else begin
                        si5345_spi_start <= 0;
                    end

                    if (si5345_spi_done) begin
                        si5345_cs_n <= 1;
                    end

                    if (si5345_byte_counter >= 4'd8 && si5345_spi_done) begin
                        si5345_read_done <= 1;
                    end
                end

                SEND_SI5345_DATA: begin
                    if (send_phase == 1'b0) begin
                        send_phase              <= 1'b1;
                    end else begin
                        send_phase              <= 1'b0;
                    end
                end

                GET_AD9253_NUM_WR: begin
                    if (rx_use) begin
                        ad9253_num <= rx_data;
                    end
                end

                GET_AD9253_CONF_BYTES: begin
                    if (ad9253_receive_conf_bytes_counter == 0 && rx_use) begin
                        ad9253_conf_bytes[15:8] <= rx_data;
                        ad9253_receive_conf_bytes_counter <= ad9253_receive_conf_bytes_counter + 1;
                    end else if (ad9253_receive_conf_bytes_counter == 1 && rx_use) begin
                        ad9253_conf_bytes[7:0] <= rx_data;
                        ad9253_receive_conf_bytes_counter <= ad9253_receive_conf_bytes_counter + 1;
                    end
                end

                RECEIVE_AD9253_CONF_DATA: begin
                    if (ad9253_byte_counter < ad9253_conf_bytes && rx_use) begin
                        if (ad9253_byte_three == 0) begin
                            ad9253_data_in_buffer[7:0] <= rx_data;
                            ad9253_byte_three <= 1;
                        end else if (ad9253_byte_three == 1) begin
                            ad9253_data_in_buffer[15:8] <= rx_data;
                            ad9253_byte_three <= 2;
                        end else begin
                            ad9253_data_in_buffer[23:16] <= rx_data;
                            ad9253_byte_three <= 0;
                        end
                        ad9253_byte_counter <= ad9253_byte_counter + 1;
                    end
                end

                CONFIG_AD9253: begin
                    if (next_state == CONFIG_AD9253) ad9253_cs_n[ad9253_num] <= 0;
                    else ad9253_cs_n[ad9253_num] <= 1;

                    ad9253_rw <= 0;
                    ad9253_loop_done <= 0;

                    if (ad9253_byte_three == 0) begin
                        if (!ad9253_spi_busy && next_state == CONFIG_AD9253) begin
                            ad9253_spi_start <= 1;
                            ad9253_data_in   <= ad9253_data_in_buffer[7:0];
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            ad9253_byte_three <= 1;
                        end
                    end else if (ad9253_byte_three == 1) begin
                        if (!ad9253_spi_busy) begin
                            ad9253_spi_start <= 1;
                            ad9253_data_in   <= ad9253_data_in_buffer[15:8];
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            ad9253_byte_three <= 2;
                        end
                    end else begin
                        if (!ad9253_spi_busy && !cs_n_wait_flag) begin
                            ad9253_spi_start <= 1;
                            ad9253_data_in   <= ad9253_data_in_buffer[23:16];
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            cs_n_wait_flag <= 1;
                            cs_n_delay_counter <= 0;
                        end
                        if (cs_n_wait_flag) begin
                            if (cs_n_delay_counter < 199) begin
                                cs_n_delay_counter <= cs_n_delay_counter + 1;
                            end else begin
                                ad9253_cs_n[ad9253_num] <= 1;
                                ad9253_byte_three <= 0;
                                cs_n_wait_flag <= 0;
                                cs_n_delay_counter <= 0;
                                ad9253_loop_done <= 1;
                            end
                        end
                    end
                end

                WAIT_AD9253_CONFIG_DONE: begin
                    if (adc_wait_cnt < 32'd2_000_000) begin
                        adc_wait_cnt <= adc_wait_cnt + 1;
                    end else begin
                        ad9253_config_done[ad9253_num] <= 1;
                    end
                end

                GET_AD9253_NUM_RD: begin
                    if (rx_use) begin
                        ad9253_num <= rx_data;
                    end
                end

                RECEIVE_AD9253_READ_DATA: begin
                    if (rx_use) begin
                        if (ad9253_byte_three == 0) begin
                            ad9253_data_in_buffer[7:0] <= rx_data;
                            ad9253_byte_three <= 1;
                        end else if (ad9253_byte_three == 1) begin
                            ad9253_data_in_buffer[15:8] <= rx_data;
                            ad9253_byte_three <= 0;
                        end
                    end
                end

                READ_AD9253_REG: begin
                    if (next_state == READ_AD9253_REG) ad9253_cs_n[ad9253_num] <= 0;
                    else ad9253_cs_n[ad9253_num] <= 1;

                    ad9253_rw <= 0;
                    ad9253_loop_done <= 0;

                    if (ad9253_byte_three == 0) begin
                        if (!ad9253_spi_busy && next_state == READ_AD9253_REG) begin
                            ad9253_spi_start <= 1;
                            ad9253_data_in   <= ad9253_data_in_buffer[7:0];
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            ad9253_byte_three <= 1;
                        end
                    end else if (ad9253_byte_three == 1) begin
                        if (!ad9253_spi_busy) begin
                            ad9253_spi_start <= 1;
                            ad9253_data_in   <= ad9253_data_in_buffer[15:8];
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            ad9253_byte_three <= 2;
                        end
                    end else begin
                        ad9253_rw <= 1;
                        if (!ad9253_spi_busy && !cs_n_wait_flag) begin
                            ad9253_spi_start <= 1;
                        end else begin
                            ad9253_spi_start <= 0;
                        end

                        if (ad9253_spi_done) begin
                            cs_n_wait_flag <= 1;
                            cs_n_delay_counter <= 0;
                        end
                        if (cs_n_wait_flag) begin
                            if (cs_n_delay_counter < 199) begin
                                cs_n_delay_counter <= cs_n_delay_counter + 1;
                            end else begin
                                ad9253_cs_n[ad9253_num] <= 1;
                                ad9253_byte_three <= 0;
                                cs_n_wait_flag <= 0;
                                cs_n_delay_counter <= 0;
                                ad9253_read_done <= 1;
                            end
                        end
                    end
                end

                SEND_AD9253_DATA: begin
                    if (send_phase == 1'b0) begin
                        send_phase <= 1'b1;
                    end else begin
                        send_phase <= 1'b0;
                    end
                end

                GET_AD9253_BIT_SLIP_NUM: begin
                    if (rx_use) begin
                        ad9253_bit_slip_num <= rx_data;
                    end
                end

                AD9253_BIT_SLIP: begin
                    bitslip_chx[ad9253_bit_slip_num] <= 1;
                    if (ad9253_fco_rise) begin
                        ad9253_fco_cnt <= ad9253_fco_cnt + 1;
                    end
                end

                SEND_TEST_DATA: begin
                    if (send_phase == 1'b0) begin
                        send_phase <= 1'b1;
                    end else begin
                        send_phase <= 1'b0;
                    end
                end

                GET_AD9253_IDELAY_NUM: begin
                    if (rx_use) begin
                        ad9253_idelay_num <= rx_data;
                    end
                end

                IDELAY: begin
                    if (rx_use) begin
                        idelay_tap[ad9253_idelay_num*5+:5] <= rx_data;
                        idelay_ld <= 1;
                        idelay_flag <= 1;
                    end
                    if (idelay_flag) begin
                        if (idelay_time_cnt < 8) begin
                            idelay_time_cnt <= idelay_time_cnt + 1;
                        end else begin
                            idelay_done <= 1;
                        end
                    end
                end

                GET_DAC128S085_NUM: begin
                    if (rx_use) begin
                        dac128s085_num <= rx_data;
                    end
                end

                RECEIVE_DAC128S085_CONF_DATA: begin
                    if (rx_use) begin
                        if (dac128s085_byte_half == 0) begin
                            dac128s085_data_in_buffer[15:8] <= rx_data;
                            dac128s085_byte_half <= 1;
                        end else begin
                            dac128s085_data_in_buffer[7:0] <= rx_data;
                            dac128s085_byte_half <= 0;
                        end
                    end
                end

                CONFIG_DAC128S085: begin
                    dac128s085_data_in[dac128s085_num*16+:16] <= dac128s085_data_in_buffer;
                    dac128s085_cs_n[dac128s085_num] <= 0;

                    if (!dac128s085_spi_busy[dac128s085_num] && next_state == CONFIG_DAC128S085) begin
                        dac128s085_spi_start[dac128s085_num] <= 1;
                    end else begin
                        dac128s085_spi_start[dac128s085_num] <= 0;
                    end

                    if (dac128s085_spi_done[dac128s085_num]) begin
                        dac128s085_cs_n[dac128s085_num] <= 1;
                    end

                    if (dac128s085_spi_done[dac128s085_num]) begin
                        dac128s085_config_done[dac128s085_num] <= 1;
                    end
                end

                GET_TDC_NUM: begin
                    if (rx_use) begin
                        tdc_num <= rx_data;
                    end
                end

                TDC_CALI: begin
                    cali_flag[tdc_num] <= 1;
                    if (tdc_cali_en[tdc_num]) begin
                        tdc_bin <= tdc_cali_in[10*tdc_num+:10];
                    end
                end

                TDC_CALI_SEND_DATA: begin
                    if (send_phase == 1'b0) begin
                        send_phase <= 1'b1;
                    end else begin
                        tdc_cali_done <= 1'b1;
                        send_phase <= 1'b0;
                    end
                end

            endcase
        end
    end

    wire [4:0] current_idelay_tap;

    assign current_idelay_tap = idelay_tap[ad9253_idelay_num*5+:5];

    //--------------------------------
    // 发送 FIFO：rxoutclk 写，txoutclk 读
    //--------------------------------
    reg [15:0] slow_control_data;
    reg        slow_control_data_valid;
    wire       sc_fifo_full;

    fifo_slow_control u_fifo_slow_control (
        .rst        (~rst_n),
        .wr_clk     (clk),          // rxoutclk
        .rd_clk     (clk_tx),       // txoutclk
        .din        (slow_control_data),
        .wr_en      (slow_control_data_valid & ~sc_fifo_full),
        .rd_en      (sc_fifo_rd_en),
        .dout       (sc_fifo_dout),
        .full       (sc_fifo_full),
        .empty      (sc_fifo_empty),
        .wr_rst_busy(),
        .rd_rst_busy()
    );
endmodule