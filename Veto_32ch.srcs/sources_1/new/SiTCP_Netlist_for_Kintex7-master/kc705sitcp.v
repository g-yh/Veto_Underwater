module
	kc705sitcp(
	// System
		input	wire			SYSCLK_200MP_IN	,	// From 200MHz Oscillator module
		input	wire			SYSCLK_200MN_IN	,	// From 200MHz Oscillator module
	// EtherNet
		input	wire			SGMII_CLK_P		,
		input	wire			SGMII_CLK_N		,
		output	wire			GMII_RSTn		,
		output	wire			TX_DISABLE		,
		output	wire			SFP_TXP			,	// out	: Tx signal line
		output	wire			SFP_TXN			,	// out	: 
		input	wire			SFP_RXP			,	// in	: Rx signal line
		input	wire			SFP_RXN			,	// in	: 
	// reset switch
		input	wire			SW_N			,
	// Connect EEPROM
		inout	wire			I2C_SDA			,
		output	wire			I2C_SCL			,
	// DIP switch
		input	wire	[ 3:0]	GPIO_DIP_SW		
	);


//------------------------------------------------------------------------------
//	Buffers

	wire			SGMII_CLK;		// in : Tx clock
	wire			GMII_TX_EN;		// out: Tx enable
	wire	[ 7:0]	GMII_TXD;		// out: Tx data[7:0]
	wire			GMII_TX_ER;		// out: TX error
	wire			GMII_RX_DV;		// in : Rx data valid
	wire	[ 7:0]	GMII_RXD;		// in : Rx data[7:0]
	wire			GMII_RX_ER;		// in : Rx error
	wire	[15:0]	STATUS_VECTOR;	// out: Core status.[15:0]	
	wire			SiTCP_RST;
	wire			TCP_OPEN_ACK;
	wire			TCP_CLOSE_REQ;
	wire			TCP_RX_WR;
	wire	[ 7:0]	TCP_RX_DATA;
	wire			TCP_TX_FULL;
	wire	[15:0]	TCP_RX_WC;
	wire	[31:0]	RBCP_ADDR;
	wire	[ 7:0]	RBCP_WD;
	wire			RBCP_WE;
	wire			RBCP_RE;
	wire	[ 7:0]	TCP_TX_DATA;
	wire			CLK_200M;
	wire			FIFO_RD_VALID;
	reg				SYS_RSTn;
	reg		[29:0]	INICNT;
	wire			RBCP_ACK;
	wire	[ 7:0]	RBCP_RD;

	wire			Duplex_mode;
	wire	[ 1:0]	LINKSpeed;
	wire			Link_Status;
	wire	[ 1:0]	SGMII_LINK;
	reg				IIC_REQ;
	wire			IIC_ACK;
	wire	[ 7:0]	IIC_RDT;
	wire			IIC_RVL;
	reg				SEL_SGMII;
	reg				PHY_RST;
	wire	[11:0]	FIFO_DATA_COUNT;
	wire			EEPROM_CS;
	wire			EEPROM_SK;
	wire			EEPROM_DI;
	wire			EEPROM_DO;
	(* keep = "true" *)	reg				IB_SIG_DET;
	(* keep = "true" *)	reg		[ 2:0]	SYNC_SIG;
	reg		[25:0]	SIG_CNT;
	reg				SET_RST;
	reg		[ 1:0]	SIG_STATE;
	reg		[18:0]	RST_CNT;
	reg				SGMII_ENB;
	wire			RST_EEPROM;
	wire			SIG_DET;
	wire			RUDI_C;
	wire			RUDI_I;
	wire			Link_SGMII;
	wire			Link_BASEX;


	IBUFDS #(.IOSTANDARD ("LVDS"))		LVDS_BUF(.O(CLK_200M), .I(SYSCLK_200MP_IN), .IB(SYSCLK_200MN_IN));

	//SYS_RSTn->off//
	always@(posedge CLK_200M)begin
		if (SW_N) begin
			INICNT[29:0]	<=	30'd0;
			SYS_RSTn		<= 1'b0;
		end else begin
			INICNT[29:0]	<=	INICNT[29]? INICNT[29:0]:	(INICNT[29:0] + 30'd1);
			SYS_RSTn		<=	INICNT[29];
		end
	end


	WRAP_SiTCP_GMII_XC7K_32K	#(
		.TIM_PERIOD			(8'd200)			// = System clock frequency(MHz), integer only
	) SiTCP	(
		.CLK				(CLK_200M),			// in	: System Clock (MII: >15MHz, GMII>129MHz)
		.RST				(RST_EEPROM),		// in	: System reset
	// Configuration parameters
		.FORCE_DEFAULTn		(GPIO_DIP_SW[3]),	// in	: Load default parameters
		.EXT_IP_ADDR		(32'h0000_0000),	// in	: IP address[31:0]
		.EXT_TCP_PORT		(16'h0000),			// in	: TCP port #[15:0]
		.EXT_RBCP_PORT		(16'h0000),			// in	: RBCP port #[15:0]
		.PHY_ADDR			(5'b0_0111),		// in	: PHY-device MIF address[4:0]
	// EEPROM
		.EEPROM_CS			(EEPROM_CS	),		// out	: Chip select
		.EEPROM_SK			(EEPROM_SK	),		// out	: Serial data clock
		.EEPROM_DI			(EEPROM_DI	),		// out	: Serial write data
		.EEPROM_DO			(EEPROM_DO	),		// in	: Serial read data
	// user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
		.USR_REG_X3C		(),					// out	: Stored at 0xFFFF_FF3C
		.USR_REG_X3D		(),					// out	: Stored at 0xFFFF_FF3D
		.USR_REG_X3E		(),					// out	: Stored at 0xFFFF_FF3E
		.USR_REG_X3F		(),					// out	: Stored at 0xFFFF_FF3F
	// MII interface
		.GMII_RSTn			(GMII_RSTn),		// out	: PHY reset
		.GMII_1000M			(1'b1),				// in	: GMII mode (0:MII, 1:GMII)
		// TX
		.GMII_TX_CLK		(SGMII_CLK),		// in	: Tx clock
		.GMII_TX_EN			(GMII_TX_EN),		// out	: Tx enable
		.GMII_TXD			(GMII_TXD[7:0]),	// out	: Tx data[7:0]
		.GMII_TX_ER			(GMII_TX_ER),		// out	: TX error
		// RX
		.GMII_RX_CLK		(SGMII_CLK),		// in	: Rx clock
		.GMII_RX_DV			(GMII_RX_DV),		// in	: Rx data valid
		.GMII_RXD			(GMII_RXD[7:0]),	// in	: Rx data[7:0]
		.GMII_RX_ER			(GMII_RX_ER),		// in	: Rx error
		.GMII_CRS			(1'b0),				// in	: Carrier sense
		.GMII_COL			(1'b0),				// in	: Collision detected
		// Management IF
		.GMII_MDC			(),					// out	: Clock for MDIO
		.GMII_MDIO_IN		(1'b1),				// in	: Data
		.GMII_MDIO_OUT		(),					// out	: Data
		.GMII_MDIO_OE		(),					// out	: MDIO output enable
	// User I/F
		.SiTCP_RST			(SiTCP_RST),		// out	: Reset for SiTCP and related circuits
		// TCP connection control
		.TCP_OPEN_REQ		(1'b0),				// in	: Reserved input, shoud be 0
		.TCP_OPEN_ACK		(TCP_OPEN_ACK),		// out	: Acknowledge for open (=Socket busy)
		.TCP_ERROR			(),					// out	: TCP error, its active period is equal to MSL
		.TCP_CLOSE_REQ		(TCP_CLOSE_REQ),	// out	: Connection close request
		.TCP_CLOSE_ACK		(TCP_CLOSE_REQ),	// in	: Acknowledge for closing
		// FIFO I/F
		.TCP_RX_WC			(TCP_RX_WC[15:0]),	// in	: Rx FIFO write count[15:0] (Unused bits should be set 1)
		.TCP_RX_WR			(TCP_RX_WR),		// out	: Write enable
		.TCP_RX_DATA		(TCP_RX_DATA[7:0]),	// out	: Write data[7:0]
		.TCP_TX_FULL		(TCP_TX_FULL),		// out	: Almost full flag
		.TCP_TX_WR			(FIFO_RD_VALID),	// in	: Write enable
		.TCP_TX_DATA		(TCP_TX_DATA[7:0]),	// in	: Write data[7:0]
	// RBCP
		.RBCP_ACT			(		),			// out	: RBCP active
		.RBCP_ADDR			(RBCP_ADDR[31:0]),	// out	: Address[31:0]
		.RBCP_WD			(RBCP_WD[7:0]),		// out	: Data[7:0]
		.RBCP_WE			(RBCP_WE),			// out	: Write enable
		.RBCP_RE			(RBCP_RE),			// out	: Read enable
		.RBCP_ACK			(RBCP_ACK),			// in	: Access acknowledge
		.RBCP_RD			(RBCP_RD[7:0])		// in	: Read data[7:0]
	);


	WRAP_gig_ethernet_pcs_pma_0 inst_WRAP_gig_ethernet_pcs_pma_0(
		.CLK_200M			(CLK_200M	),
		.SGMII_CLK_P		(SGMII_CLK_P),
		.SGMII_CLK_N		(SGMII_CLK_N),
		.SFP_TXP			(SFP_TXP),
		.SFP_TXN			(SFP_TXN),
		.SFP_RXP			(SFP_RXP),
		.SFP_RXN			(SFP_RXN),
		.SGMII_CLK			(SGMII_CLK),

		.GMII_TXD			(GMII_TXD[7:0]),
		.GMII_TX_EN			(GMII_TX_EN),
		.GMII_TX_ER			(GMII_TX_ER),
		.GMII_RXD			(GMII_RXD[7:0]),
		.GMII_RX_DV			(GMII_RX_DV),
		.GMII_RX_ER			(GMII_RX_ER),
		.SEL_SGMII			(SEL_SGMII),
		.SGMII_LINK			(SGMII_LINK),
		.STATUS_VECTOR		(STATUS_VECTOR[15:0]),
		.RESET				(PHY_RST)
	);
	

	assign	SIG_DET				= STATUS_VECTOR[1];
	assign	RUDI_C				= STATUS_VECTOR[2];
	assign	RUDI_I				= STATUS_VECTOR[3];
	assign	Link_SGMII			= STATUS_VECTOR[7];
	assign	Link_BASEX			= STATUS_VECTOR[0];
	assign	Duplex_mode			= STATUS_VECTOR[12];
	assign	LINKSpeed[1:0]		= SEL_SGMII?	STATUS_VECTOR[11:10]:	2'b10;
	assign	Link_Status			= SEL_SGMII?	Link_SGMII:		Link_BASEX;
	assign	SGMII_LINK[1:0]		= (
		((LINKSpeed[1:0]==2'b10)?		2'b00:		2'b00)|
		((LINKSpeed[1:0]==2'b01)?		2'b11:		2'b00)|
		((LINKSpeed[1:0]==2'b00)?		2'b10:		2'b00)
	);
	assign	TX_DISABLE			= SEL_SGMII?	1'b0:	1'b1;


	//FIFO
	fifo_generator_v11_0 fifo_generator_v11_0(
	  .clk			(CLK_200M				),	//	in	:
	  .rst			(~TCP_OPEN_ACK			),	//	in	:
	  .din			(TCP_RX_DATA[7:0]		),	//	in	:
	  .wr_en		(TCP_RX_WR				),	//	in	:
	  .full			(						),	//	out	:
	  .dout			(TCP_TX_DATA[7:0]		),	//	out	:
	  .valid		(FIFO_RD_VALID			),	//	out	:active H
	  .rd_en		(~TCP_TX_FULL			),	//	in	:
	  .empty		(						),	//	out	:
	  .data_count	(FIFO_DATA_COUNT[11:0]	)	//	out	:[11:0]
	);


	// RBCP	Sample Code
	RBCP	RBCP(
		.CLK		(CLK_200M),			// in
		.DIP		(GPIO_DIP_SW[2:0]),	// in
		.RBCP_WE	(RBCP_WE),			// in
		.RBCP_RE	(RBCP_RE),			// in
		.RBCP_WD	(RBCP_WD[7:0]),		// in
		.RBCP_ADDR	(RBCP_ADDR[31:0]),	// in
		.RBCP_RD	(RBCP_RD[7:0]),		// out
		.RBCP_ACK	(RBCP_ACK)			// out
	);


endmodule
