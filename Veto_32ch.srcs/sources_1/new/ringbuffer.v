module ringbuffer #(
    parameter DATA_WIDTH  = 16,
    parameter DEPTH       = 4096,
    parameter HEAD_LENGTH = 5,
    parameter TRIG_TOTAL  = 30,
    parameter CHANNEL_ID  = 0
) (
    input wire clk,
    input wire rst_n,

    input wire [DATA_WIDTH-1:0] din,
    input wire [           9:0] tdc_data,
    input wire                  trig,
    input wire [          47:0] time_cnt,
    input wire [           7:0] trig_pre,
    input wire [           7:0] trig_post,

    output reg [DATA_WIDTH-1:0] dout,
    output reg                  data_valid
);

    reg                   busy;
    reg                   post_wait;

    (* ram_style = "block" *)
    reg  [DATA_WIDTH-1:0] mem          [DEPTH-1:0];

    reg  [          11:0] wr_ptr;
    reg  [          11:0] rd_ptr;

    reg  [          11:0] read_count;
    // reg  [          47:0] time_cnt;
    // reg  [          47:0] time_cnt_now;
    reg  [          31:0] trig_cnt;
    reg  [           2:0] rd_phase;

    reg  [           9:0] tdc_data_reg;
    reg  [          47:0] time_cnt_reg;
    reg  [           7:0] post_count;

    // The metadata readout path contributes a fixed three-sample
    // pipeline delay before the first ADC sample reaches dout.
    localparam [7:0] POST_START_LATENCY = 8'd3;

    wire trigger_fire =
        rst_n && trig && !busy && !post_wait;
    wire trigger_immediate =
        (trig_pre != 8'd0) ||
        (trig_post <= POST_START_LATENCY);
    wire [7:0] post_wait_cycles =
        (trig_post > POST_START_LATENCY)
            ? (trig_post - POST_START_LATENCY)
            : 8'd0;
    wire [8:0] post_count_next = {1'b0, post_count} + 9'd1;
    wire post_done =
        post_wait && (post_count_next >= {1'b0, post_wait_cycles});

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
            wr_ptr <= rd_ptr + trig_pre + HEAD_LENGTH;
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
            post_wait  <= 0;
            post_count <= 0;
            rd_phase   <= 0;
            trig_cnt   <= 0;
        end else begin
            // ------------------------------
            // Latch trigger metadata.  A non-zero trig_pre keeps the
            // previous immediate-read behaviour.  Otherwise trig_post
            // selects a delayed window relative to the trigger.
            // ------------------------------
            if (trigger_fire) begin
                tdc_data_reg <= tdc_data;
                time_cnt_reg <= time_cnt;

                if (trigger_immediate) begin
                    busy       <= 1'b1;
                    read_count <= 0;
                    rd_phase   <= 0;
                end else begin
                    post_wait  <= 1'b1;
                    post_count <= 8'd0;
                end
            end

            // Delay only the ADC window start; metadata remains from the
            // original trigger edge.
            if (post_wait) begin
                if (post_done) begin
                    post_wait  <= 1'b0;
                    post_count <= 8'd0;
                    busy       <= 1'b1;
                    read_count <= 0;
                    rd_phase   <= 0;
                end else begin
                    post_count <= post_count_next[7:0];
                end
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
