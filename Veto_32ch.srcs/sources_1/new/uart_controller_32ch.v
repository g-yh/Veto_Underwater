module uart_controller_32ch #(
    parameter ADC_NUM = 8,
    parameter CHANNEL_NUM = 4
) (
    input wire clk,
    input wire rst_n,

    // UART接口
    input  wire uart_rx,
    output wire uart_tx,

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

    // idealy
    output reg [ADC_NUM*CHANNEL_NUM*2*5-1:0] idelay_tap,
    output reg                               idelay_ld,

    // tdc
    input  wire [10*ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_in,
    input  wire [   ADC_NUM*CHANNEL_NUM - 1:0] tdc_cali_en,
    output reg  [   ADC_NUM*CHANNEL_NUM - 1:0] cali_flag,

    // data transmit相关
    input  wire [7:0] fifo_async_out,
    input  wire       fifo_async_empty,
    output wire       uart_clk_buf,
    output wire       uart_tx_data_transmit_done
);

    // UART接收器
    wire       uart_working_rx;
    wire [7:0] uart_data_rx;
    wire       uart_data_valid;

    uart_rx #(
        .CLK_DIV(200)
    ) u_uart_rx (
        .clk    (clk),
        .rst_n  (rst_n),
        .uart_rx(uart_rx),
        .data   (uart_data_rx),
        .working(uart_working_rx)
    );

    // UART发送器
    wire       uart_working_tx;
    reg        uart_tx_start;
    wire       uart_tx_done;
    reg  [7:0] uart_data_tx;

    uart_tx #(
        .CLK_DIV(200)
    ) u_uart_tx (
        .clk         (clk),
        .rst_n       (rst_n),
        .data        (uart_data_tx),
        .start       (uart_tx_start),
        .working     (uart_working_tx),
        .uart_tx     (uart_tx),
        .uart_clk_buf(uart_clk_buf)
    );

    // 检测UART接收完成
    reg uart_working_rx_dly;
    reg uart_working_tx_dly;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_working_rx_dly <= 0;
            uart_working_tx_dly <= 0;
        end else begin
            uart_working_rx_dly <= uart_working_rx;
            uart_working_tx_dly <= uart_working_tx;
        end
    end

    // 可以使用uart_data_rx 8位并行数据
    assign uart_data_valid = uart_working_rx_dly & ~uart_working_rx;

    // 输入的uart_data_tx 8位数据发送完成
    assign uart_tx_done = uart_working_tx_dly & ~uart_working_tx;

    // 通过uart传输adc数据完成标志，只在DATA_TRANSMIT状态有效
    assign uart_tx_data_transmit_done = (state == DATA_TRANSMIT) ? uart_tx_done : 1'b0;

    //--------------------------------
    // 状态机
    //--------------------------------
    // 状态定义
    localparam IDLE = 6'd0;
    localparam GET_SI5345_CONF_BYTES = 6'd1;
    localparam RECEIVE_SI5345_CONF_DATA = 6'd2;
    localparam CONFIG_SI5345 = 6'd3;

    localparam RECEIVE_SI5345_READ_DATA = 6'd4;
    localparam READ_SI5345_REG = 6'd5;
    localparam UART_SEND_SI5345_DATA = 6'd6;

    localparam GET_AD9253_NUM_WR = 6'd7;
    localparam GET_AD9253_CONF_BYTES = 6'd8;
    localparam RECEIVE_AD9253_CONF_DATA = 6'd9;
    localparam CONFIG_AD9253 = 6'd10;

    localparam GET_AD9253_NUM_RD = 6'd11;
    localparam RECEIVE_AD9253_READ_DATA = 6'd12;
    localparam READ_AD9253_REG = 6'd13;
    localparam UART_SEND_AD9253_DATA = 6'd14;

    localparam GET_AD9253_BIT_SLIP_NUM = 6'd15;
    localparam AD9253_BIT_SLIP = 6'd16;
    localparam UART_SEND_TEST_DATA = 6'd17;

    localparam GET_AD9253_IDELAY_NUM = 6'd18;
    localparam IDELAY = 6'd19;

    localparam GET_DAC128S085_NUM = 6'd20;
    localparam RECEIVE_DAC128S085_CONF_DATA = 6'd21;
    localparam CONFIG_DAC128S085 = 6'd22;

    localparam WAIT_AD9253_CONFIG_DONE = 6'd23;

    localparam GET_TDC_NUM = 6'd24;
    localparam TDC_CALI = 6'd25;
    localparam TDC_CALI_SEND_DATA = 6'd26;

    localparam DATA_TRANSMIT = 6'd31;


    // 状态机信号
    reg  [ 5:0] state;
    reg  [ 5:0] next_state;

    // 计数器和控制信号
    reg  [ 1:0] si5345_receive_conf_bytes_counter;  // 用于计数前两个字节
    reg  [15:0] si5345_conf_bytes;  // 配置数据总字节数
    reg  [15:0] si5345_byte_counter;  // 已接收的配置数据字节数
    reg  [15:0] si5345_data_in_buffer;  // 临时存储待发送的16位数据
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
    // reg         ad9253_config_done;
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

    reg [ 7:0] data_transmit_counter;

    reg [ 3:0] idelay_time_cnt;
    reg        idelay_done;
    reg        idelay_flag;

    reg        tdc_cali_done;
    reg [ 9:0] tdc_bin;
    reg [ 1:0] send_step;
    reg [ 4:0] tdc_num;

    // 状态寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    // 状态转移逻辑
    always @(*) begin
        case (state)
            IDLE: begin
                if (uart_data_valid && uart_data_rx == 8'hF0) next_state = GET_SI5345_CONF_BYTES;
                else if (uart_data_valid && uart_data_rx == 8'hF1)
                    next_state = RECEIVE_SI5345_READ_DATA;
                else if (uart_data_valid && uart_data_rx == 8'hF2) next_state = GET_AD9253_NUM_WR;
                else if (uart_data_valid && uart_data_rx == 8'hF3) next_state = GET_AD9253_NUM_RD;
                else if (uart_data_valid && uart_data_rx == 8'hF4)
                    next_state = GET_AD9253_BIT_SLIP_NUM;
                else if (uart_data_valid && uart_data_rx == 8'hF5)
                    next_state = GET_AD9253_IDELAY_NUM;
                else if (uart_data_valid && uart_data_rx == 8'hF6) next_state = GET_DAC128S085_NUM;
                else if (uart_data_valid && uart_data_rx == 8'hF7) next_state = GET_TDC_NUM;


                else if (uart_data_valid && uart_data_rx == 8'hFD) next_state = DATA_TRANSMIT;
                else next_state = IDLE;
            end

            GET_SI5345_CONF_BYTES: begin
                if (si5345_receive_conf_bytes_counter >= 2) next_state = RECEIVE_SI5345_CONF_DATA;
                else next_state = GET_SI5345_CONF_BYTES;
            end

            RECEIVE_SI5345_CONF_DATA: begin
                if (si5345_byte_half == 1 && uart_data_valid) next_state = CONFIG_SI5345;
                else next_state = RECEIVE_SI5345_CONF_DATA;
            end

            CONFIG_SI5345: begin
                if (si5345_spi_done) begin
                    if (si5345_byte_counter >= si5345_conf_bytes) next_state = IDLE;
                    else next_state = RECEIVE_SI5345_CONF_DATA;
                end else next_state = CONFIG_SI5345;
            end

            RECEIVE_SI5345_READ_DATA: begin
                if (si5345_byte_half == 1 && uart_data_valid) next_state = READ_SI5345_REG;
                else next_state = RECEIVE_SI5345_READ_DATA;
            end

            READ_SI5345_REG: begin
                if (si5345_spi_done) begin
                    if (si5345_byte_counter >= 4'd8) next_state = UART_SEND_SI5345_DATA;
                    else next_state = RECEIVE_SI5345_READ_DATA;
                end else next_state = READ_SI5345_REG;
            end

            UART_SEND_SI5345_DATA: begin
                if (uart_tx_done) next_state = IDLE;
                else next_state = UART_SEND_SI5345_DATA;
            end

            GET_AD9253_NUM_WR: begin
                if (uart_data_valid) next_state = GET_AD9253_CONF_BYTES;
                else next_state = GET_AD9253_NUM_WR;
            end

            GET_AD9253_CONF_BYTES: begin
                if (ad9253_receive_conf_bytes_counter >= 2) next_state = RECEIVE_AD9253_CONF_DATA;
                else next_state = GET_AD9253_CONF_BYTES;
            end

            RECEIVE_AD9253_CONF_DATA: begin
                if (ad9253_byte_three == 2 && uart_data_valid)
                    next_state = CONFIG_AD9253;  // 接收到3个字节，准备发送
                else next_state = RECEIVE_AD9253_CONF_DATA;
            end

            CONFIG_AD9253: begin
                // if (ad9253_spi_done && ad9253_byte_three == 2) begin
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
                if (uart_data_valid) next_state = RECEIVE_AD9253_READ_DATA;
                else next_state = GET_AD9253_NUM_RD;
            end

            RECEIVE_AD9253_READ_DATA: begin
                if (ad9253_byte_three == 1 && uart_data_valid) next_state = READ_AD9253_REG;
                else next_state = RECEIVE_AD9253_READ_DATA;
            end

            READ_AD9253_REG: begin
                if (ad9253_read_done) next_state = UART_SEND_AD9253_DATA;
                else next_state = READ_AD9253_REG;
            end

            UART_SEND_AD9253_DATA: begin
                if (uart_tx_done) next_state = IDLE;
                else next_state = UART_SEND_AD9253_DATA;
            end

            GET_AD9253_BIT_SLIP_NUM: begin
                if (uart_data_valid) next_state = AD9253_BIT_SLIP;
                else next_state = GET_AD9253_BIT_SLIP_NUM;
            end

            AD9253_BIT_SLIP: begin
                if (ad9253_fco_cnt == 4'd15) next_state = UART_SEND_TEST_DATA;
                else next_state = AD9253_BIT_SLIP;
            end

            UART_SEND_TEST_DATA: begin
                if (uart_tx_done) next_state = IDLE;
                else next_state = UART_SEND_TEST_DATA;
            end

            GET_DAC128S085_NUM: begin
                if (uart_data_valid) next_state = RECEIVE_DAC128S085_CONF_DATA;
                else next_state = GET_DAC128S085_NUM;
            end

            RECEIVE_DAC128S085_CONF_DATA: begin
                if (dac128s085_byte_half == 1 && uart_data_valid) next_state = CONFIG_DAC128S085;
                else next_state = RECEIVE_DAC128S085_CONF_DATA;
            end

            CONFIG_DAC128S085: begin
                if (dac128s085_spi_done) next_state = IDLE;
                else next_state = CONFIG_DAC128S085;
            end

            DATA_TRANSMIT: begin
                if (uart_data_valid && uart_data_rx == 8'hFE) next_state = IDLE;
                else next_state = DATA_TRANSMIT;
            end

            GET_AD9253_IDELAY_NUM: begin
                if (uart_data_valid) next_state = IDELAY;
                else next_state = GET_AD9253_IDELAY_NUM;
            end

            IDELAY: begin
                if (idelay_done) next_state = IDLE;
                else next_state = IDELAY;
            end

            GET_TDC_NUM: begin
                if (uart_data_valid) next_state = TDC_CALI;
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

            uart_tx_start <= 0;
            cs_n_wait_flag <= 0;
            cs_n_delay_counter <= 0;
            bitslip_chx <= 0;
            adc_wait_cnt <= 0;

            ad9253_config_done <= 0;

            data_transmit_counter <= 0;

            idelay_tap <= 0;
            idelay_ld <= 0;
            idelay_time_cnt <= 0;
            idelay_done <= 0;
            idelay_flag <= 0;

            tdc_cali_done <= 0;
            cali_flag <= 0;
            tdc_bin <= 0;
            send_step <= 0;
            tdc_num <= 0;
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

                    uart_tx_start <= 0;
                    cs_n_wait_flag <= 0;
                    cs_n_delay_counter <= 0;

                    bitslip_chx <= 0;
                    adc_wait_cnt <= 0;

                    data_transmit_counter <= 0;

                    // idelay_tap <= 0;
                    idelay_ld <= 0;
                    idelay_time_cnt <= 0;
                    idelay_done <= 0;
                    idelay_flag <= 0;

                    tdc_cali_done <= 0;
                    cali_flag <= 0;
                    tdc_bin <= 0;
                    send_step <= 0;
                    tdc_num <= 0;
                end

                GET_SI5345_CONF_BYTES: begin
                    if (si5345_receive_conf_bytes_counter == 0 && uart_data_valid) begin
                        si5345_conf_bytes[15:8] <= uart_data_rx;
                        si5345_receive_conf_bytes_counter <= si5345_receive_conf_bytes_counter + 1;
                    end else if (si5345_receive_conf_bytes_counter == 1 && uart_data_valid) begin
                        si5345_conf_bytes[7:0] <= uart_data_rx;
                        si5345_receive_conf_bytes_counter <= si5345_receive_conf_bytes_counter + 1;
                    end
                end

                RECEIVE_SI5345_CONF_DATA: begin
                    if (si5345_byte_counter < si5345_conf_bytes && uart_data_valid) begin
                        if (si5345_byte_half == 0) begin
                            si5345_data_in_buffer[15:8] <= uart_data_rx;
                            si5345_byte_half <= 1;
                        end else begin
                            si5345_data_in_buffer[7:0] <= uart_data_rx;
                            si5345_byte_half <= 0;
                        end
                        si5345_byte_counter <= si5345_byte_counter + 1;
                    end
                end

                CONFIG_SI5345: begin
                    // 设置SPI参数
                    si5345_data_in <= si5345_data_in_buffer;
                    si5345_rw <= 0;
                    si5345_cs_n <= 0;

                    // 控制start信号
                    if (!si5345_spi_busy && next_state == CONFIG_SI5345) begin
                        si5345_spi_start <= 1;
                    end else begin
                        si5345_spi_start <= 0;
                    end

                    if (si5345_spi_done) begin
                        si5345_cs_n <= 1;
                    end

                    // 检查是否接收完所有数据
                    if (si5345_byte_counter >= si5345_conf_bytes && si5345_spi_done) begin
                        si5345_config_done <= 1;
                    end
                end

                RECEIVE_SI5345_READ_DATA: begin
                    if (si5345_byte_counter < 4'd8 && uart_data_valid) begin
                        if (si5345_byte_half == 0) begin
                            si5345_data_in_buffer[15:8] <= uart_data_rx;
                            si5345_byte_half <= 1;
                        end else begin
                            si5345_data_in_buffer[7:0] <= uart_data_rx;
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
                        uart_data_tx <= si5345_data_out[7:0];
                        si5345_read_done <= 1;
                    end
                end

                UART_SEND_SI5345_DATA: begin
                    if(~uart_working_tx && ~uart_working_tx_dly && next_state == UART_SEND_SI5345_DATA) begin
                        uart_tx_start <= 1;
                    end else begin
                        uart_tx_start <= 0;
                    end
                end

                GET_AD9253_NUM_WR: begin
                    if (uart_data_valid) begin
                        ad9253_num <= uart_data_rx;
                    end
                end

                GET_AD9253_CONF_BYTES: begin
                    if (ad9253_receive_conf_bytes_counter == 0 && uart_data_valid) begin
                        ad9253_conf_bytes[15:8] <= uart_data_rx;
                        ad9253_receive_conf_bytes_counter <= ad9253_receive_conf_bytes_counter + 1;
                    end else if (ad9253_receive_conf_bytes_counter == 1 && uart_data_valid) begin
                        ad9253_conf_bytes[7:0] <= uart_data_rx;
                        ad9253_receive_conf_bytes_counter <= ad9253_receive_conf_bytes_counter + 1;
                    end
                end

                RECEIVE_AD9253_CONF_DATA: begin
                    if (ad9253_byte_counter < ad9253_conf_bytes && uart_data_valid) begin
                        if (ad9253_byte_three == 0) begin
                            // 第一个字节
                            ad9253_data_in_buffer[7:0] <= uart_data_rx;
                            ad9253_byte_three <= 1;
                        end else if (ad9253_byte_three == 1) begin
                            // 第二个字节
                            ad9253_data_in_buffer[15:8] <= uart_data_rx;
                            ad9253_byte_three <= 2;
                        end else begin
                            // 第三个字节
                            ad9253_data_in_buffer[23:16] <= uart_data_rx;
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
                            // 启动延时计数
                            cs_n_wait_flag <= 1;
                            cs_n_delay_counter <= 0;
                        end
                        if (cs_n_wait_flag) begin
                            if (cs_n_delay_counter < 199) begin
                                cs_n_delay_counter <= cs_n_delay_counter + 1;
                            end else begin
                                ad9253_cs_n[ad9253_num] <= 1;  // 延时结束，释放片选
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
                    if (uart_data_valid) begin
                        ad9253_num <= uart_data_rx;
                    end
                end

                RECEIVE_AD9253_READ_DATA: begin
                    if (uart_data_valid) begin
                        if (ad9253_byte_three == 0) begin
                            // 第一个字节
                            ad9253_data_in_buffer[7:0] <= uart_data_rx;
                            ad9253_byte_three <= 1;
                        end else if (ad9253_byte_three == 1) begin
                            // 第二个字节
                            ad9253_data_in_buffer[15:8] <= uart_data_rx;
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
                            uart_data_tx <= ad9253_data_out;
                            // 启动延时计数
                            cs_n_wait_flag <= 1;
                            cs_n_delay_counter <= 0;
                        end
                        if (cs_n_wait_flag) begin
                            if (cs_n_delay_counter < 199) begin
                                cs_n_delay_counter <= cs_n_delay_counter + 1;
                            end else begin
                                ad9253_cs_n[ad9253_num] <= 1;  // 延时结束，释放片选
                                ad9253_byte_three <= 0;
                                cs_n_wait_flag <= 0;
                                cs_n_delay_counter <= 0;
                                ad9253_read_done <= 1;
                            end
                        end
                    end
                end

                UART_SEND_AD9253_DATA: begin
                    if(~uart_working_tx && ~uart_working_tx_dly && next_state == UART_SEND_AD9253_DATA) begin
                        uart_tx_start <= 1;
                    end else begin
                        uart_tx_start <= 0;
                    end
                end

                GET_AD9253_BIT_SLIP_NUM: begin
                    if (uart_data_valid) begin
                        ad9253_bit_slip_num <= uart_data_rx;
                    end
                end

                AD9253_BIT_SLIP: begin
                    bitslip_chx[ad9253_bit_slip_num] <= 1;
                    if (ad9253_fco_rise) begin
                        ad9253_fco_cnt <= ad9253_fco_cnt + 1;
                    end
                end

                UART_SEND_TEST_DATA: begin
                    uart_data_tx <= ad9253_data_chx[ad9253_bit_slip_num*8+:8];
                    if(~uart_working_tx && ~uart_working_tx_dly && next_state == UART_SEND_TEST_DATA) begin
                        uart_tx_start <= 1;
                    end else begin
                        uart_tx_start <= 0;
                    end
                end

                GET_AD9253_IDELAY_NUM: begin
                    if (uart_data_valid) begin
                        ad9253_idelay_num <= uart_data_rx;
                    end
                end

                IDELAY: begin
                    if (uart_data_valid) begin
                        idelay_tap[ad9253_idelay_num*5+:5] <= uart_data_rx;
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
                    if (uart_data_valid) begin
                        dac128s085_num <= uart_data_rx;
                    end
                end

                RECEIVE_DAC128S085_CONF_DATA: begin
                    if (uart_data_valid) begin
                        if (dac128s085_byte_half == 0) begin
                            dac128s085_data_in_buffer[15:8] <= uart_data_rx;
                            dac128s085_byte_half <= 1;
                        end else begin
                            dac128s085_data_in_buffer[7:0] <= uart_data_rx;
                            dac128s085_byte_half <= 0;
                        end
                    end
                end

                CONFIG_DAC128S085: begin
                    // 设置SPI参数
                    dac128s085_data_in[dac128s085_num*16+:16] <= dac128s085_data_in_buffer;
                    dac128s085_cs_n[dac128s085_num] <= 0;

                    // 控制start信号
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
                    if (uart_data_valid) begin
                        tdc_num <= uart_data_rx;
                    end
                end

                TDC_CALI: begin
                    cali_flag[tdc_num] <= 1;
                    if (tdc_cali_en[tdc_num]) begin
                        tdc_bin <= tdc_cali_in[10*tdc_num+:10];
                    end
                end

                TDC_CALI_SEND_DATA: begin
                    uart_tx_start <= 0;

                    case (send_step)
                        2'd0: begin
                            if (!uart_working_tx && !tdc_cali_done) begin
                                uart_data_tx  <= {6'b0, tdc_bin[9:8]};
                                uart_tx_start <= 1'b1;
                            end
                            if (uart_working_tx) begin
                                send_step <= 2'd1;
                            end
                        end

                        2'd1: begin
                            if (!uart_working_tx) begin
                                send_step <= 2'd2;
                            end
                        end

                        2'd2: begin
                            if (!uart_working_tx) begin
                                uart_data_tx  <= tdc_bin[7:0];
                                uart_tx_start <= 1'b1;
                            end
                            if (uart_working_tx) begin
                                send_step <= 2'd3;
                            end
                        end

                        2'd3: begin
                            if (!uart_working_tx) begin
                                tdc_cali_done <= 1'b1;
                                send_step     <= 2'd0;
                            end
                        end
                    endcase
                end

                DATA_TRANSMIT: begin
                    uart_data_tx <= fifo_async_out;
                    if (~uart_working_tx && ~fifo_async_empty) begin
                        uart_tx_start <= 1;
                    end else begin
                        uart_tx_start <= 0;
                    end
                end
            endcase
        end
    end

    wire [4:0] current_idelay_tap;

    assign current_idelay_tap = idelay_tap[ad9253_idelay_num*5+:5];

    // ila_uart u_ila_uart (
    //     .clk    (clk),
    //     .probe0 (state),
    //     .probe1 (cali_flag),
    //     .probe2 (tdc_bin),
    //     .probe3 (uart_tx_start),
    //     .probe4 (uart_data_tx),
    //     .probe5 (send_step),
    //     .probe6 (tdc_cali_done),
    //     .probe7 (tdc_cali_in),
    //     .probe8 (uart_working_tx),
    //     .probe9 (0),
    //     .probe10(0)
    // );
endmodule
