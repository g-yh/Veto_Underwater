module uart_tx #(
    parameter CLK_DIV = 200
) (
    input  wire       clk,
    input  wire       rst_n,        
    input  wire [7:0] data,
    input  wire       start,        // rising edge start to work
    output reg        working,      // 1 is working, 0 is free
    output reg        uart_tx,
    output wire       uart_clk_buf
);

    reg [7:0] clk_div_counter;
    reg       uart_clk;

    // clk分频
    always @(posedge clk) begin
        if (!rst_n) begin
            clk_div_counter <= 0;
            uart_clk        <= 0;
        end else begin
            if (clk_div_counter == CLK_DIV / 2 - 1) begin
                uart_clk <= ~uart_clk;
                clk_div_counter <= 0;
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end

    BUFG instance_bufg_uartclk (
        .I(uart_clk),
        .O(uart_clk_buf)
    );

    reg [3:0] counter_send;  // bit location
    reg       start_delay;

    always @(posedge uart_clk_buf) begin
        if (!rst_n) begin
            start_delay  <= 0;
            counter_send <= 0;
            working      <= 0;
            uart_tx      <= 1;   // UART 空闲态 = 1
        end else begin
            start_delay <= start;

            if (~working) begin  // IDLE
                if (start & ~start_delay) begin  // rising edge start
                    uart_tx <= 0;
                    counter_send <= 0;
                    working <= 1;
                end else begin  // idle
                    uart_tx <= 1;
                end
            end else begin  // working
                if (counter_send != 8) begin
                    uart_tx <= data[counter_send];
                    counter_send <= counter_send + 1;
                end else begin
                    uart_tx <= 1;
                    working <= 0;
                end
            end
        end
    end

endmodule