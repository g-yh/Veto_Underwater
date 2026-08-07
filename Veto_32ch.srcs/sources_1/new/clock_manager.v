`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/29 20:00:18
// Design Name: 
// Module Name: clock_manager
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clock_manager(
    input clk_200M_p,
    input clk_200M_n,
    input clk_gtx_125M_p,
    input clk_gtx_125M_n,

    output wire clk_400M,
    output wire clk_200M,
    output wire clk_125M,
    output wire clk_100M,
    output wire clk_20M,
    output wire clk_gtx_125M
    );

    IBUFGDS instance_ibufgds_clk_sys_200M (
        .I (clk_200M_p),
        .IB(clk_200M_n),
        .O (clk_200M)
    );

    wire buffer_mmcm_feedback_125M;
    MMCME2_BASE #(
        .CLKIN1_PERIOD   (5),
        .CLKFBOUT_MULT_F (5),
        .DIVCLK_DIVIDE   (1),
        .CLKOUT0_DIVIDE_F(8)
    ) MMCM_125M (
        .CLKIN1  (clk_200M),
        .CLKFBOUT(buffer_mmcm_feedback_125M),
        .CLKFBIN (buffer_mmcm_feedback_125M),
        .CLKOUT0 (clk_125M),
        .PWRDWN  (0),
        .RST     (0)
    );

    wire buffer_mmcm_feedback_20M;
    MMCME2_BASE #(
        .CLKIN1_PERIOD   (5),
        .CLKFBOUT_MULT_F (5),
        .DIVCLK_DIVIDE   (1),
        .CLKOUT0_DIVIDE_F(50)
    ) MMCM_20M (
        .CLKIN1  (clk_200M),
        .CLKFBOUT(buffer_mmcm_feedback_20M),
        .CLKFBIN (buffer_mmcm_feedback_20M),
        .CLKOUT0 (clk_20M),
        .PWRDWN  (0),
        .RST     (0)
    );

    reg clk_drp_reg;
    always @(posedge clk_200M) begin
        clk_drp_reg <= ~clk_drp_reg;
    end
    BUFG instance_bufg_drpclk (
        .I (clk_drp_reg),
        .O (clk_100M)
    );

    IBUFDS_GTE2 instance_ibufgds_gtx_refclk (
        .I  (clk_gtx_125M_p),
        .IB (clk_gtx_125M_n),
        .O  (clk_gtx_125M),
        .CEB(1'b0),
        .ODIV2()
    );

    wire pll_clk_400M;
    wire pll_feedback_400M;
    PLLE2_BASE #(
        .BANDWIDTH("HIGH"),
        .CLKFBOUT_MULT(8),
        .CLKIN1_PERIOD(5),
        .DIVCLK_DIVIDE(1),
        // output config
        .CLKOUT0_DIVIDE(4)
    ) PLLE2_400M (
        .CLKIN1 (clk_200M),
        .CLKOUT0(pll_clk_400M),
        .CLKOUT1(),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        // control
        .CLKFBOUT(pll_feedback_400M),
        .CLKFBIN(pll_feedback_400M),
        .LOCKED (),
        .PWRDWN (0),
        .RST    (0)
    );

    BUFG instance_bufg_sysclk_400M(
        .I (pll_clk_400M),
        .O (clk_400M)
    );

endmodule
