module arbiter_4ch #(
    parameter TRIG_WIDTH = 16
) (
    input wire clk,
    input wire rst_n,

    input wire [15:0] trig_total,

    input wire [3:0] pre_fifo_empty,
    input wire       post_fifo_full,

    input wire [15:0] data0,
    input wire [15:0] data1,
    input wire [15:0] data2,
    input wire [15:0] data3,

    output reg  [ 3:0] pre_fifo_rd_en,
    output wire [15:0] data_out,
    output reg         post_fifo_wr_en
);

    reg  [ 1:0] current_ch;
    reg  [15:0] read_cnt;
    reg         reading;

    wire [15:0] data_mux;

    assign data_mux =
       (current_ch == 2'd0) ? data0 :
       (current_ch == 2'd1) ? data1 :
       (current_ch == 2'd2) ? data2 :
                              data3;

    assign data_out = rst_n ? data_mux : 16'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_ch      <= 0;
            read_cnt        <= 0;
            reading         <= 0;
            pre_fifo_rd_en  <= 0;
            post_fifo_wr_en <= 0;
        end else begin
            pre_fifo_rd_en  <= 4'b0000;
            post_fifo_wr_en <= 1'b0;

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
                            current_ch <= current_ch + 1;
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
