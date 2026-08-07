

module
	WRAP_gig_ethernet_pcs_pma_0 (
		input	wire			CLK_200M		,
		input	wire			SGMII_CLK_P		,
		input	wire			SGMII_CLK_N		,
		output	wire			SFP_TXP			,
		output	wire			SFP_TXN			,
		input	wire			SFP_RXP			,
		input	wire			SFP_RXN			,
		output	wire			SGMII_CLK		,

		input	wire	[7:0]	GMII_TXD		,
		input	wire			GMII_TX_EN		,
		input	wire			GMII_TX_ER		,
		output	wire	[7:0]	GMII_RXD		,
		output	wire			GMII_RX_DV		,
		output	wire			GMII_RX_ER		,
		input	wire			SEL_SGMII		,
		input	wire	[1:0]	SGMII_LINK		,
		output	wire	[15:0]	STATUS_VECTOR	,
		input	wire			RESET			
	);
	
endmodule
