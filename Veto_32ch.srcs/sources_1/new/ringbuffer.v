module ringbuffer #(
    parameter DATA_WIDTH  = 16,
    parameter DEPTH       = 4096,
    parameter HEAD_LENGTH = 5,
    parameter TRIG_PRE    = 0,
    parameter TRIG_TOTAL  = 30,
    parameter CHANNEL_ID  = 0
) (
    input wire clk,
    input wire rst_n,

    input wire [DATA_WIDTH-1:0] din,
    input wire [           9:0] tdc_data,
    input wire                  trig,
    input wire [          47:0] time_cnt,

    output reg [DATA_WIDTH-1:0] dout,
    output reg                  data_valid
);

    reg                   busy;

    (* ram_style = "block" *)
    reg  [DATA_WIDTH-1:0] mem          [DEPTH-1:0];

    reg  [          11:0] wr_ptr;
    reg  [          11:0] rd_ptr;

    reg  [          11:0] read_count;
    // reg  [          47:0] time_cnt;
    // reg  [          47:0] time_cnt_now;
    reg  [          31:0] trig_cnt;
    reg  [           2:0] rd_phase;

    wire                  read_enable;

    reg  [           9:0] tdc_data_reg;
    reg  [          47:0] time_cnt_reg;

    assign read_enable = rst_n ? trig : 1'b0;

    reg [DATA_WIDTH-1:0] temp_out;
    always @(posedge clk) begin
        mem[wr_ptr] <= din;
        temp_out <= mem[rd_ptr];
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            wr_ptr <= 0;
        end else begin
            rd_ptr <= rd_ptr + 1;
            wr_ptr <= rd_ptr + TRIG_PRE + HEAD_LENGTH;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) data_valid <= 1'b0;
        else data_valid <= busy;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            dout       <= 0;
            read_count <= 0;
            busy       <= 0;
            rd_phase   <= 0;
            trig_cnt   <= 0;
        end else begin
            // ------------------------------
            // Trigger read
            // ------------------------------
            if (read_enable && !busy) begin
                busy         <= 1'b1;
                read_count   <= 0;
                rd_phase     <= 0;
                tdc_data_reg <= tdc_data;
                time_cnt_reg <= time_cnt;
            end

            // ------------------------------
            // Reading out data
            // ------------------------------
            if (busy) begin
                case (rd_phase)
                    0: begin
                        dout         <= trig_cnt[31:16];
                        rd_phase <= 1;
                    end

                    1: begin
                        dout         <= trig_cnt[15:0];
                        trig_cnt <= trig_cnt + 1'b1;
                        rd_phase <= 2;
                    end

                    2: begin
                        dout     <= CHANNEL_ID;
                        rd_phase <= 3;
                    end

                    3: begin
                        dout     <= time_cnt_reg[47:32];
                        rd_phase <= 4;
                    end

                    4: begin
                        dout     <= time_cnt_reg[31:16];
                        rd_phase <= 5;
                    end

                    5: begin
                        dout     <= time_cnt_reg[15:0];
                        rd_phase <= 6;
                    end

                    6: begin
                        dout     <= tdc_data_reg;
                        rd_phase <= 7;
                    end

                    7: begin
                        dout <= temp_out;
                        read_count <= read_count + 1'b1;

                        if (read_count == TRIG_TOTAL - 1) begin
                            busy <= 1'b0;
                        end
                    end
                endcase

            end
        end
    end

    // generate
    //     if(CHANNEL_ID == 4) begin: ila_ringbuffer_gen
    //         ila_ringbuffer_inside ila_ringbuffer_inside_inst (
    //             .clk    (clk),
    //             .probe0 (rst_n),
    //             .probe1 (din),
    //             .probe2 (read_enable),
    //             .probe3 (dout),
    //             .probe4 (busy),
    //             .probe5 (wr_ptr),
    //             .probe6 (rd_ptr),
    //             .probe7 (read_count),
    //             .probe8 (mem[wr_ptr]),
    //             .probe9 (rd_phase),
    //             .probe10(data_valid),
    //             .probe11(time_cnt),
    //             .probe12(trig_cnt)
    //         );
    //     end
    // endgenerate
endmodule
