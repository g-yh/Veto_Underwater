`timescale 1ns / 1ps

// SPI 3线，16bit
module spi_3wire_master_8bit #(
    parameter CLK_DIV = 100  // 分频控制 SCLK 频率，实际输出频率 = clk / (2*CLK_DIV)
) (
    input            clk,      // FPGA 时钟
    input            rst_n,    // 复位
    input            start,    // 启动一次传输
    input            rw,       // 0: 写，1: 读
    input      [7:0] data_in,  // 准备好的用于写出的数据
    output reg       busy,     // 忙标志
    output reg       done,     // 完成标志
    output reg       sclk,     // SPI 时钟
    inout            sdio,     // 双向数据线

    // debug输出
    output reg       sdio_in,   // 读取的数据
    output reg       sdio_out,  // 写出的数据
    output reg [7:0] shift_reg,  // 一次完整的写出数据
    output reg [2:0] bit_cnt,   // 位计数（操作到8bit的哪一位了）
    output reg [1:0] state      // 状态
);

    reg [7:0] clk_cnt;

    assign sdio = ~rw ? sdio_out : 1'bz;

    // ==============================
    // SCLK 生成逻辑
    // ==============================

    // 每次计数到CLK_DIV翻转一次，2 * CLK_DIV个CLK周期完成一个SCLK周期
    // 空闲时SCLK为高电平
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            sclk <= 1;
        end else begin
            if (busy) begin
                if (clk_cnt == (CLK_DIV - 1)) begin
                    clk_cnt <= 0;
                    sclk <= ~sclk;
                end else clk_cnt <= clk_cnt + 1;
            end else begin
                clk_cnt <= 0;
                sclk <= 1;
            end
        end
    end

    // ==============================
    // 状态
    // ==============================
    localparam IDLE = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam WAIT_STATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    // ==============================
    // 二段式状态机
    // ==============================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_cnt <= 0;
            shift_reg <= 0;
            sdio_out <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (~rw) shift_reg <= data_in;
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (start) begin
                        busy <= 1;
                        bit_cnt <= 3'd7;
                        state <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    // === 写数据 ===
                    // 在SCLK下降沿准备数据
                    if (~rw && clk_cnt == (CLK_DIV - 1) && sclk == 1) begin
                        sdio_out <= shift_reg[bit_cnt];
                    end

                    // === 读数据 ===
                    // 在SCLK上升沿采样
                    if (rw && clk_cnt == (CLK_DIV - 1) && sclk == 0) begin
                        shift_reg[bit_cnt] <= sdio;
                        sdio_in <= sdio;
                    end

                    // === 位计数 ===
                    if (clk_cnt == (CLK_DIV - 1) && sclk == 0) begin
                        if (bit_cnt == 0) begin
                            if (start) begin
                                state <= TRANSFER;
                            end else begin
                                // state <= WAIT_STATE;
                                state <= IDLE;
                            end
                            bit_cnt <= 3'd7;
                            done <= 1;
                        end else bit_cnt <= bit_cnt - 1;
                    end
                end

                // WAIT_STATE: begin
                //     // 再等一个SCLK下降沿
                //     if (clk_cnt == (CLK_DIV - 1) && sclk == 1) begin
                //         state <= IDLE;
                //     end
                // end
            endcase
        end
    end
endmodule
