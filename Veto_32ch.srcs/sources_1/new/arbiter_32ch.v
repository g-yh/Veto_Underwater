module arbiter_32ch #(
    parameter TRIG_WIDTH = 16,
    parameter ADC_NUM = 8,
    parameter CHANNEL_NUM = 4
) (
    input wire clk,
    input wire rst_n,

    input wire [15:0] trig_total,

    input wire [ADC_NUM*CHANNEL_NUM-1:0] pre_fifo_empty,
    input wire                           post_fifo_full,

    input wire [ADC_NUM*CHANNEL_NUM*16-1:0] data,

    output reg  [ADC_NUM*CHANNEL_NUM-1:0] pre_fifo_rd_en,
    output wire [                   15:0] data_out,
    output reg                            post_fifo_wr_en,
    output reg  [                    4:0] current_ch
);

    // reg  [ 4:0] current_ch;
    reg  [15:0] read_cnt;
    reg         reading;

    wire [15:0] data_mux;

    assign data_mux = data[current_ch*16+:16];

    assign data_out = rst_n ? data_mux : 16'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_ch      <= 0;
            read_cnt        <= 0;
            reading         <= 0;
            pre_fifo_rd_en  <= 0;
            post_fifo_wr_en <= 0;
        end else begin
            pre_fifo_rd_en  <= 0;
            post_fifo_wr_en <= 0;

            if (reading) begin
                pre_fifo_rd_en[current_ch] <= 1'b1;
                post_fifo_wr_en            <= 1'b1;

                if (read_cnt == trig_total - 1) begin
                    reading <= 0;
                    // read_cnt <= 0;
                    // current_ch <= current_ch + 1;
                end else begin
                    read_cnt <= read_cnt + 1;
                end

            end else begin
                if (read_cnt == trig_total - 1) begin
                    read_cnt   <= 0;
                    current_ch <= current_ch + 1;
                end else begin
                    if (!pre_fifo_empty[current_ch]) begin
                        if (post_fifo_full) begin
                            // current_ch <= current_ch + 1;
                        end else begin
                            reading  <= 1'b1;
                            read_cnt <= 0;
                        end
                    end else begin
                        current_ch <= current_ch + 1;
                    end
                end
            end
        end
    end

endmodule
