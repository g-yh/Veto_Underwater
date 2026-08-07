module test_top_sitcp (
    input wire clk_200M_p,    // system clock, 200MHz
               clk_200M_n,

    // input wire SGMII_clk_p, // Serial GMII clock, for PCS/PMA. from Si5338, 125MHz
    //            SGMII_clk_n,
    // clock from si5338
    input wire clk_125M_p,
               clk_125M_n,

    output wire clk_125M_en,
            //    clk1p,
            //    clk1n,
    // inout si5338_scl,
    //       si5338_sda,
    // output wire si5338_i2c_lsb, // set low
    
    // input wire rst_sys,     // reset, high when free, low active

    // SFP, inout
    input wire SFP_rx_p,    // SFP receive
               SFP_rx_n,
    output wire SFP_tx_p,   // SFP send
                SFP_tx_n,
    output wire SFP_tx_disable  // set low

    // // TCP and FIFO
    // input wire [15:0] TCP_rx_write_count,    // fifo rx write count
    // input wire TCP_tx_write_enable,     // write enable to fifo
    // input wire [7:0] TCP_tx_data,       // data write to fifo
    // output wire [7:0] TCP_rx_data,      // received data
    // output wire TCP_open_ack,           // TCP open acknowledge
    //             TCP_rx_data_valid,      // received data valid
    //             TCP_tx_almost_full,     // fifo almost full

    // // RBCP, PC write to FPGA, FPGA read circuit
    // output wire [31:0] RBCP_address,    // address where PC writes, from PC
    // output wire [7:0] RBCP_rcv_data,    // receive data from PC
    // output wire RBCP_rcv_valid,         // receive data valid, from PC
    //             RBCP_read_enable,       // send to circuit
    // input wire [7:0] RBCP_read_data,    // read data from circuit
    // input wire RBCP_read_valid          // access acknowledge, read data valid, from circuit
    );

    wire clk_200M;
    IBUFGDS Ibufgds_instance1 (
        .I  (clk_200M_p),
        .IB (clk_200M_n),
        .O  (clk_200M)
    );

    assign clk_125M_en = 1;

    wire rst_sys;
    (* dont_touch="true" *) vio_0 vio_inst (
        .clk       (clk_200M),   // input wire clk
        .probe_out0(rst_sys)
    );

    wire [15:0] TCP_rx_write_count;     // assign TCP_rx_write_count = 16'b1111_1111_1111_1111;    // input, fifo rx write count
    reg TCP_tx_write_enable;           // assign TCP_tx_write_enable = 1'b1;  // write enable to fifo
    reg [7:0] TCP_tx_data;            // assign TCP_tx_data = 8'b10101010;   // data write to fifo
    wire [7:0] TCP_rx_data;      // received data
    wire TCP_open_ack,           // TCP open acknowledge
         TCP_rx_data_valid,      // received data valid
         TCP_tx_almost_full;     // fifo almost full

    // RBCP, PC write to FPGA, FPGA read circuit
    wire [31:0] RBCP_address;    // address where PC writes, from PC
    wire [7:0] RBCP_rcv_data;    // receive data from PC
    wire RBCP_rcv_valid,         // receive data valid, from PC
         RBCP_read_enable;       // send to circuit
    wire [7:0] RBCP_read_data;          // assign RBCP_read_data = 8'b01010101;    // read data from circuit
    wire RBCP_read_valid;               // assign RBCP_read_valid = 1'b1;          // access acknowledge, read data valid, from circuit
    wire RBCP_active;           // output, RBCP active

    // setup
//    wire rst_sys;
//    assign rst_sys = 1;
    assign SFP_tx_disable = 0;
    // assign si5338_i2c_lsb = 0;

    // inner wires
    wire    SGMII_clk,
            GMII_tx_en, GMII_rx_dv,
            GMII_tx_er, GMII_rx_er;
    wire [7:0] GMII_txd, GMII_rxd;
    
    wire TCP_close_req, TCP_error;
    wire [15:0] status_vector, TCP_tx_fill;
    // // case reg
    // reg [1:0] SGMII_link;
    // always @(*) begin
    //     case (status_vector[11:10]) // speed
    //         2'b00 : SGMII_link = 2'b10;
    //         2'b01 : SGMII_link = 2'b11;
    //         2'b10 : SGMII_link = 2'b00;
    //         2'b11 : SGMII_link = 2'b00;
    //     endcase
    // end
    // case wire
    wire [1:0] SGMII_link;
    assign SGMII_link[1] = ~status_vector[11];
    assign SGMII_link[0] = ~status_vector[11] & status_vector[10];


    // SiTCP instance, connect TCP to GMII
    WRAP_SiTCP_GMII_XC7K_32K #(
        .TIM_PERIOD(200)        // System clock frequency (MHz), integer only
    ) SiTCP_instance (
        .CLK        (clk_200M), // GMII > 129MHz
        .RST        (~rst_sys), // system reset, high is reset
        .SiTCP_RST  (),         // output, SiTCP reset

        // GMII TX and RX
        .GMII_TX_CLK    (SGMII_clk),    // input TX clock
        .GMII_RX_CLK    (SGMII_clk),    // in
        .GMII_TX_EN     (GMII_tx_en),   // output tx enable
        .GMII_RX_DV     (GMII_rx_dv),   // in
        .GMII_TXD       (GMII_txd),     // output tx data [7:0]
        .GMII_RXD       (GMII_rxd),     // in
        .GMII_TX_ER     (GMII_tx_er),   // output tx err data
        .GMII_RX_ER     (GMII_rx_er),   // in

        // TCP, TCP output to PC, PC inupt to to TCP
        .TCP_OPEN_REQ   (1'b0),         // input, reserved input, set 0
        .TCP_OPEN_ACK   (TCP_open_ack), // output, acknowledge for open (socket busy)
        .TCP_ERROR      (TCP_error),    // output, TCP error, its active period is equal to MSL
        .TCP_CLOSE_REQ  (TCP_close_req),// output, request close
        .TCP_CLOSE_ACK  (TCP_close_req),// input, acknowledge close

        // FIFO, 
        .TCP_RX_WC      (TCP_rx_write_count),   // input [15:0], rx fifo write count
        .TCP_RX_WR      (TCP_rx_data_valid),    // out, received data valid
        .TCP_RX_DATA    (TCP_rx_data),          // out, received data [7:0]
        .TCP_TX_FULL    (TCP_tx_almost_full),   // out, fifo almost full flag
        .TCP_TX_WR      (TCP_tx_write_enable),  // in, write enable
        .TCP_TX_DATA    (TCP_tx_data),          // input write data [7:0]

        // RBCP
        .RBCP_ACT   (RBCP_active),      // output, RBCP active
        .RBCP_ADDR  (RBCP_address),     // output [31:0], RBCP address
        .RBCP_WD    (RBCP_rcv_data),    // output [7:0], reveive data from PC (write data)
        .RBCP_WE    (RBCP_rcv_valid),   // output, data valid (write enable)
        .RBCP_RE    (RBCP_read_enable), // out, read enable
        .RBCP_RD    (RBCP_read_data),   // input [7:0], read data, from circuit
        .RBCP_ACK   (RBCP_read_valid),  // input, access acknowledge, read data valid

        // configuration parameters
        .FORCE_DEFAULTn ( 1'b0),    // 0 to load default parameters
        .EXT_IP_ADDR    ({8'd192, 8'd168, 8'd10, 8'd16}),    // ip address, {8'd192, 8'd168, 8'd10, 8'd16}
        .EXT_TCP_PORT   (16'd24),    // tcp port
        .EXT_RBCP_PORT  (16'd4660),    // PHY-device MIF address
        // EERPOM, not use
        .EEPROM_CS  (), // chip select
        .EEPROM_SK  (), // serial data clock
        .EEPROM_DI  (), // serial write data
        .EEPROM_DO  (0),// input: serial read data
        // user data output, intial values are stored in the eeprom, 0xffff_fc3c~3f
        .USR_REG_X3C(),
        .USR_REG_X3D(),
        .USR_REG_X3E(),
        .USR_REG_X3F(),
        // MII interface, not use, set to GMII
        .GMII_RSTn  (),
        .GMII_1000M (1'b1), // select GMII
        // management interface
        .GMII_MDC       (),     // clock for MDIO
        .GMII_MDIO_IN   (1'b1), // input data
        .GMII_MDIO_OUT  (),     // output data
        .GMII_MDIO_OE   (),     // output enable
        .GMII_CRS       (1'b0), // input carrier sense
        .GMII_COL       (1'b0)  // input collision detected
    );


    // interface between SFP and GMII, connect GMII to SFP
    WRAP_gig_ethernet_pcs_pma_0 instance_ethernet (
        .CLK_200M   (clk_200M),

        .SGMII_CLK_P(clk_125M_p),
        .SGMII_CLK_N(clk_125M_n),
        .SGMII_CLK  (SGMII_clk),
        .SFP_TXP    (SFP_tx_p),
        .SFP_TXN    (SFP_tx_n),
        .SFP_RXP    (SFP_rx_p),
        .SFP_RXN    (SFP_rx_n),

        .GMII_TXD   (GMII_txd),     // in
        .GMII_TX_EN (GMII_tx_en),   // in
        .GMII_TX_ER (GMII_tx_er),   // in
        .GMII_RXD   (GMII_rxd),     // out
        .GMII_RX_DV (GMII_rx_dv),   // out
        .GMII_RX_ER (GMII_rx_er),   // out
        .SEL_SGMII  (1'b1),         // input
        .SGMII_LINK (SGMII_link),   // input
        .STATUS_VECTOR  (status_vector),    // output
        .RESET      (~rst_sys)      // input, high to reset
    );

    // // clock 125MHz for SGMII
    // wire si_done, si_err;
    // si5338 # (
    //     .kInitFileName  ("si5338.mif"),
    //     .input_clk      (200000000   ),
    //     .i2c_address    (7'b1110000  ), 
    //     .bus_clk        (400000      )
    // ) si5338_inst (
    //     .clk    (clk_200M),
    //     .reset  (1'b0),
    //     .done   (si_done),
    //     .error  (si_err),
    //     .SCL    (si5338_scl),
    //     .SDA    (si5338_sda)
	// );
	
	// RBCP
    // wire [2:0] dip_temp;
    RBCP instance_RBCP(
		.CLK(clk_200M),
		.DIP(3'b000),
		.RBCP_WE(RBCP_rcv_valid),
		.RBCP_RE(RBCP_read_enable),
		.RBCP_WD(RBCP_rcv_data),
		.RBCP_ADDR(RBCP_address),
		.RBCP_RD(RBCP_read_data),
		.RBCP_ACK(RBCP_read_valid)
	);
	

    // ------------------------------------------
    // user program
    reg [8:0] counter_timer;           initial counter_timer = 0;  // count to run
    always @(posedge clk_200M) begin
        counter_timer <= counter_timer + 1;

//        TCP_tx_write_enable <= (counter_timer > 255) ? 1 : 0;
        TCP_tx_write_enable <= ~TCP_tx_almost_full;
        // TCP_tx_write_enable <= 0;
        TCP_tx_data <= counter_timer[7:0];
    end

    // check clock
    // wire clk_check;
    // IBUFDS_GTE2 IBUFDS_GTE2_m1 (
    //     .O            (clk_check),
    //     .ODIV2        (),
    //     .CEB          (1'b0),
    //     .I            (clk1p),
    //     .IB           (clk1n)
    // );


    // oscilliscope
    ila_1 instance_ila (
        .clk(clk_200M), // input wire clk

        .probe0(RBCP_read_valid),
        .probe1(RBCP_read_data),
        .probe2(SGMII_clk),
        .probe3(TCP_rx_data),
        .probe4(TCP_rx_data_valid),
        .probe5(TCP_rx_write_count),
        .probe6(TCP_tx_data),
        .probe7(TCP_tx_write_enable)
    );
endmodule
