module uart_rx #(
    parameter [7:0] CLK_DIV = 200  // 1 to 255
) (
    input            clk,
    input            rst_n,     
    input            uart_rx,
    output reg [7:0] data,      // 8-bit data, valid when working goes low
    output reg       working    // 1 if working and 0 if free
);

    reg [7:0] counter_divide;
    reg [3:0] counter_rcv;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter_divide <= 0;
            counter_rcv    <= 0;
            data           <= 0;
            working        <= 0;
        end else begin
            if (~working) begin  // IDLE
                counter_divide <= 1;
                counter_rcv    <= 0;
                if (~uart_rx) begin  // start bit
                    working <= 1;
                end
            end else begin  // uart working
                // counter increase
                if (counter_divide == CLK_DIV) begin
                    counter_divide <= 1;
                    if (counter_rcv != 9) begin
                        counter_rcv <= counter_rcv + 1;
                    end
                end else begin
                    counter_divide <= counter_divide + 1;
                end

                // data acquire（在bit中间采样）
                if ((counter_divide == CLK_DIV[7:1]) && (counter_rcv != 0)) begin
                    data[counter_rcv-1] <= uart_rx;
                end

                // finish（stop bit）
                if ((counter_rcv == 9) && (uart_rx == 1)) begin
                    working <= 0;
                end
            end
        end
    end

endmodule