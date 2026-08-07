# system clock
set_property PACKAGE_PIN AD12 [get_ports clk_200M_p]
set_property PACKAGE_PIN AD11 [get_ports clk_200M_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk_200M_p]
create_clock -name clk_sys_200M -period 5.0 [get_ports clk_200M_p]

set_property DIFF_TERM TRUE [get_ports clk_200M_p]

# GT CLK 156.25M
set_property PACKAGE_PIN N8 [get_ports gt_refclk_15625_p]
set_property PACKAGE_PIN N7 [get_ports gt_refclk_15625_n]

create_clock -name gt_refclk -period 6.4 [get_ports gt_refclk_15625_p]

# GT CLK
set_property PACKAGE_PIN J8 [get_ports clk_gtx_125M_p]
set_property PACKAGE_PIN J7 [get_ports clk_gtx_125M_n]

create_clock -name clk_sys_125M -period 8.0 [get_ports clk_gtx_125M_p]

set_property PACKAGE_PIN U20 [get_ports clk_125M_en]
set_property IOSTANDARD LVCMOS33 [get_ports clk_125M_en]

# uart
set_property PACKAGE_PIN R29 [get_ports uart_tx]
set_property PACKAGE_PIN P29 [get_ports uart_rx]

set_property IOSTANDARD LVCMOS33 [get_ports uart*]

# si5345
set_property PACKAGE_PIN G28 [get_ports si5345_clk_in0_p]
set_property PACKAGE_PIN F28 [get_ports si5345_clk_in0_n]
set_property IOSTANDARD LVDS_25 [get_ports si5345_clk_in0_*]

set_property PACKAGE_PIN AE5 [get_ports si5345_cs_n]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_cs_n]

set_property PACKAGE_PIN AE3 [get_ports si5345_sdio]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_sdio]

set_property PACKAGE_PIN AE4 [get_ports si5345_sclk]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_sclk]

set_property PACKAGE_PIN AF5 [get_ports si5345_i2c_sel]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_i2c_sel]

set_property PACKAGE_PIN AC7 [get_ports si5345_in_sel0]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_in_sel0]

set_property PACKAGE_PIN AD7 [get_ports si5345_in_sel1]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_in_sel1]

set_property PACKAGE_PIN AD3 [get_ports si5345_oeb]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_oeb]

set_property PACKAGE_PIN AG2 [get_ports si5345_lolb]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_lolb]

set_property PACKAGE_PIN AD4 [get_ports si5345_rstb]
set_property IOSTANDARD LVCMOS18 [get_ports si5345_rstb]

# ad9253
set_property PACKAGE_PIN AC1 [get_ports ad9253_sdio]
set_property IOSTANDARD LVCMOS18 [get_ports ad9253_sdio]

set_property PACKAGE_PIN AC2 [get_ports ad9253_sclk]
set_property IOSTANDARD LVCMOS18 [get_ports ad9253_sclk]

set_property PACKAGE_PIN AC4 [get_ports ad9253_sync]
set_property IOSTANDARD LVCMOS18 [get_ports ad9253_sync]

set_property PACKAGE_PIN AC5 [get_ports ad9253_pdwn]
set_property IOSTANDARD LVCMOS18 [get_ports ad9253_pdwn]

## cs
set_property PACKAGE_PIN AD2 [get_ports ad9253_cs_n[0]]
set_property PACKAGE_PIN AF3 [get_ports ad9253_cs_n[1]]
set_property PACKAGE_PIN AD1 [get_ports ad9253_cs_n[2]]
set_property PACKAGE_PIN AF2 [get_ports ad9253_cs_n[3]]
set_property PACKAGE_PIN AD6 [get_ports ad9253_cs_n[4]]
set_property PACKAGE_PIN AG4 [get_ports ad9253_cs_n[5]]
set_property PACKAGE_PIN AE6 [get_ports ad9253_cs_n[6]]
set_property PACKAGE_PIN AG3 [get_ports ad9253_cs_n[7]]

set_property IOSTANDARD LVCMOS18 [get_ports {ad9253_cs_n[*]}]

## data
set_property PACKAGE_PIN D11 [get_ports ad9253_data_p[0]]
set_property PACKAGE_PIN C11 [get_ports ad9253_data_n[0]]

set_property PACKAGE_PIN F11 [get_ports ad9253_data_p[1]]
set_property PACKAGE_PIN E11 [get_ports ad9253_data_n[1]]

set_property PACKAGE_PIN A11 [get_ports ad9253_data_p[2]]
set_property PACKAGE_PIN A12 [get_ports ad9253_data_n[2]]

set_property PACKAGE_PIN H11 [get_ports ad9253_data_p[3]]
set_property PACKAGE_PIN H12 [get_ports ad9253_data_n[3]]

set_property PACKAGE_PIN D14 [get_ports ad9253_data_p[4]]
set_property PACKAGE_PIN C14 [get_ports ad9253_data_n[4]]

set_property PACKAGE_PIN C12 [get_ports ad9253_data_p[5]]
set_property PACKAGE_PIN B12 [get_ports ad9253_data_n[5]]

set_property PACKAGE_PIN B14 [get_ports ad9253_data_p[6]]
set_property PACKAGE_PIN A15 [get_ports ad9253_data_n[6]]

set_property PACKAGE_PIN L11 [get_ports ad9253_data_p[7]]
set_property PACKAGE_PIN K11 [get_ports ad9253_data_n[7]]

set_property PACKAGE_PIN N29 [get_ports ad9253_data_p[8]]
set_property PACKAGE_PIN N30 [get_ports ad9253_data_n[8]]

set_property PACKAGE_PIN K26 [get_ports ad9253_data_p[9]]
set_property PACKAGE_PIN J26 [get_ports ad9253_data_n[9]]

set_property PACKAGE_PIN J29 [get_ports ad9253_data_p[10]]
set_property PACKAGE_PIN H29 [get_ports ad9253_data_n[10]]

set_property PACKAGE_PIN J27 [get_ports ad9253_data_p[11]]
set_property PACKAGE_PIN J28 [get_ports ad9253_data_n[11]]

set_property PACKAGE_PIN N27 [get_ports ad9253_data_p[12]]
set_property PACKAGE_PIN M27 [get_ports ad9253_data_n[12]]

set_property PACKAGE_PIN N25 [get_ports ad9253_data_p[13]]
set_property PACKAGE_PIN N26 [get_ports ad9253_data_n[13]]

set_property PACKAGE_PIN M29 [get_ports ad9253_data_p[14]]
set_property PACKAGE_PIN M30 [get_ports ad9253_data_n[14]]

set_property PACKAGE_PIN P23 [get_ports ad9253_data_p[15]]
set_property PACKAGE_PIN N24 [get_ports ad9253_data_n[15]]

set_property PACKAGE_PIN B13 [get_ports ad9253_data_p[16]]
set_property PACKAGE_PIN A13 [get_ports ad9253_data_n[16]]

set_property PACKAGE_PIN J11 [get_ports ad9253_data_p[17]]
set_property PACKAGE_PIN J12 [get_ports ad9253_data_n[17]]

set_property PACKAGE_PIN C15 [get_ports ad9253_data_p[18]]
set_property PACKAGE_PIN B15 [get_ports ad9253_data_n[18]]

set_property PACKAGE_PIN L12 [get_ports ad9253_data_p[19]]
set_property PACKAGE_PIN L13 [get_ports ad9253_data_n[19]]

set_property PACKAGE_PIN E14 [get_ports ad9253_data_p[20]]
set_property PACKAGE_PIN E15 [get_ports ad9253_data_n[20]]

set_property PACKAGE_PIN L15 [get_ports ad9253_data_p[21]]
set_property PACKAGE_PIN K15 [get_ports ad9253_data_n[21]]

set_property PACKAGE_PIN J16 [get_ports ad9253_data_p[22]]
set_property PACKAGE_PIN H16 [get_ports ad9253_data_n[22]]

set_property PACKAGE_PIN H15 [get_ports ad9253_data_p[23]]
set_property PACKAGE_PIN G15 [get_ports ad9253_data_n[23]]

set_property PACKAGE_PIN L30 [get_ports ad9253_data_p[24]]
set_property PACKAGE_PIN K30 [get_ports ad9253_data_n[24]]

set_property PACKAGE_PIN J23 [get_ports ad9253_data_p[25]]
set_property PACKAGE_PIN J24 [get_ports ad9253_data_n[25]]

set_property PACKAGE_PIN J21 [get_ports ad9253_data_p[26]]
set_property PACKAGE_PIN J22 [get_ports ad9253_data_n[26]]

set_property PACKAGE_PIN L21 [get_ports ad9253_data_p[27]]
set_property PACKAGE_PIN K21 [get_ports ad9253_data_n[27]]

set_property PACKAGE_PIN M22 [get_ports ad9253_data_p[28]]
set_property PACKAGE_PIN M23 [get_ports ad9253_data_n[28]]

set_property PACKAGE_PIN N19 [get_ports ad9253_data_p[29]]
set_property PACKAGE_PIN N20 [get_ports ad9253_data_n[29]]

set_property PACKAGE_PIN N21 [get_ports ad9253_data_p[30]]
set_property PACKAGE_PIN N22 [get_ports ad9253_data_n[30]]

set_property PACKAGE_PIN P21 [get_ports ad9253_data_p[31]]
set_property PACKAGE_PIN P22 [get_ports ad9253_data_n[31]]

set_property PACKAGE_PIN A16 [get_ports ad9253_data_p[32]]
set_property PACKAGE_PIN A17 [get_ports ad9253_data_n[32]]

set_property PACKAGE_PIN D16 [get_ports ad9253_data_p[33]]
set_property PACKAGE_PIN C16 [get_ports ad9253_data_n[33]]

set_property PACKAGE_PIN C17 [get_ports ad9253_data_p[34]]
set_property PACKAGE_PIN B17 [get_ports ad9253_data_n[34]]

set_property PACKAGE_PIN C19 [get_ports ad9253_data_p[35]]
set_property PACKAGE_PIN B19 [get_ports ad9253_data_n[35]]

set_property PACKAGE_PIN B18 [get_ports ad9253_data_p[36]]
set_property PACKAGE_PIN A18 [get_ports ad9253_data_n[36]]

set_property PACKAGE_PIN C20 [get_ports ad9253_data_p[37]]
set_property PACKAGE_PIN B20 [get_ports ad9253_data_n[37]]

set_property PACKAGE_PIN D21 [get_ports ad9253_data_p[38]]
set_property PACKAGE_PIN C21 [get_ports ad9253_data_n[38]]

set_property PACKAGE_PIN A20 [get_ports ad9253_data_p[39]]
set_property PACKAGE_PIN A21 [get_ports ad9253_data_n[39]]

set_property PACKAGE_PIN E23 [get_ports ad9253_data_p[40]]
set_property PACKAGE_PIN D23 [get_ports ad9253_data_n[40]]

set_property PACKAGE_PIN B23 [get_ports ad9253_data_p[41]]
set_property PACKAGE_PIN A23 [get_ports ad9253_data_n[41]]

set_property PACKAGE_PIN A25 [get_ports ad9253_data_p[42]]
set_property PACKAGE_PIN A26 [get_ports ad9253_data_n[42]]

set_property PACKAGE_PIN C24 [get_ports ad9253_data_p[43]]
set_property PACKAGE_PIN B24 [get_ports ad9253_data_n[43]]

set_property PACKAGE_PIN B30 [get_ports ad9253_data_p[44]]
set_property PACKAGE_PIN A30 [get_ports ad9253_data_n[44]]

set_property PACKAGE_PIN B28 [get_ports ad9253_data_p[45]]
set_property PACKAGE_PIN A28 [get_ports ad9253_data_n[45]]

set_property PACKAGE_PIN C29 [get_ports ad9253_data_p[46]]
set_property PACKAGE_PIN B29 [get_ports ad9253_data_n[46]]

set_property PACKAGE_PIN D29 [get_ports ad9253_data_p[47]]
set_property PACKAGE_PIN C30 [get_ports ad9253_data_n[47]]

set_property PACKAGE_PIN G17 [get_ports ad9253_data_p[48]]
set_property PACKAGE_PIN F17 [get_ports ad9253_data_n[48]]

set_property PACKAGE_PIN J17 [get_ports ad9253_data_p[49]]
set_property PACKAGE_PIN H17 [get_ports ad9253_data_n[49]]

set_property PACKAGE_PIN L17 [get_ports ad9253_data_p[50]]
set_property PACKAGE_PIN L18 [get_ports ad9253_data_n[50]]

set_property PACKAGE_PIN G18 [get_ports ad9253_data_p[51]]
set_property PACKAGE_PIN F18 [get_ports ad9253_data_n[51]]

set_property PACKAGE_PIN J19 [get_ports ad9253_data_p[52]]
set_property PACKAGE_PIN H19 [get_ports ad9253_data_n[52]]

set_property PACKAGE_PIN K19 [get_ports ad9253_data_p[53]]
set_property PACKAGE_PIN K20 [get_ports ad9253_data_n[53]]

set_property PACKAGE_PIN H20 [get_ports ad9253_data_p[54]]
set_property PACKAGE_PIN G20 [get_ports ad9253_data_n[54]]

set_property PACKAGE_PIN H21 [get_ports ad9253_data_p[55]]
set_property PACKAGE_PIN H22 [get_ports ad9253_data_n[55]]

set_property PACKAGE_PIN G23 [get_ports ad9253_data_p[56]]
set_property PACKAGE_PIN G24 [get_ports ad9253_data_n[56]]

set_property PACKAGE_PIN E24 [get_ports ad9253_data_p[57]]
set_property PACKAGE_PIN D24 [get_ports ad9253_data_n[57]]

set_property PACKAGE_PIN H24 [get_ports ad9253_data_p[58]]
set_property PACKAGE_PIN H25 [get_ports ad9253_data_n[58]]

set_property PACKAGE_PIN F25 [get_ports ad9253_data_p[59]]
set_property PACKAGE_PIN E25 [get_ports ad9253_data_n[59]]

set_property PACKAGE_PIN G27 [get_ports ad9253_data_p[60]]
set_property PACKAGE_PIN F27 [get_ports ad9253_data_n[60]]

set_property PACKAGE_PIN E29 [get_ports ad9253_data_p[61]]
set_property PACKAGE_PIN E30 [get_ports ad9253_data_n[61]]

set_property PACKAGE_PIN G29 [get_ports ad9253_data_p[62]]
set_property PACKAGE_PIN F30 [get_ports ad9253_data_n[62]]

set_property PACKAGE_PIN F26 [get_ports ad9253_data_p[63]]
set_property PACKAGE_PIN E26 [get_ports ad9253_data_n[63]]

set_property IOSTANDARD LVDS_25 [get_ports {ad9253_data_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {ad9253_data_n[*]}]

set_property DIFF_TERM TRUE [get_ports {ad9253_data_p[*]}]

## FCO
set_property PACKAGE_PIN F12 [get_ports ad9253_fco_p[0]]
set_property PACKAGE_PIN E13 [get_ports ad9253_fco_n[0]]

set_property PACKAGE_PIN L26 [get_ports ad9253_fco_p[1]]
set_property PACKAGE_PIN L27 [get_ports ad9253_fco_n[1]]

set_property PACKAGE_PIN H14 [get_ports ad9253_fco_p[2]]
set_property PACKAGE_PIN G14 [get_ports ad9253_fco_n[2]]

set_property PACKAGE_PIN L25 [get_ports ad9253_fco_p[3]]
set_property PACKAGE_PIN K25 [get_ports ad9253_fco_n[3]]

set_property PACKAGE_PIN D17 [get_ports ad9253_fco_p[4]]
set_property PACKAGE_PIN D18 [get_ports ad9253_fco_n[4]]

set_property PACKAGE_PIN E28 [get_ports ad9253_fco_p[5]]
set_property PACKAGE_PIN D28 [get_ports ad9253_fco_n[5]]

set_property PACKAGE_PIN F20 [get_ports ad9253_fco_p[6]]
set_property PACKAGE_PIN E20 [get_ports ad9253_fco_n[6]]

set_property PACKAGE_PIN D27 [get_ports ad9253_fco_p[7]]
set_property PACKAGE_PIN C27 [get_ports ad9253_fco_n[7]]

set_property IOSTANDARD LVDS_25 [get_ports {ad9253_fco_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {ad9253_fco_n[*]}]

create_clock -name FCO -period 8 [get_ports {ad9253_fco_p[*]}]

set_property DIFF_TERM TRUE [get_ports {ad9253_fco_p[*]}]

## DCO
set_property PACKAGE_PIN G13 [get_ports ad9253_dco_p[0]]
set_property PACKAGE_PIN F13 [get_ports ad9253_dco_n[0]]

set_property PACKAGE_PIN M28 [get_ports ad9253_dco_p[1]]
set_property PACKAGE_PIN L28 [get_ports ad9253_dco_n[1]]

set_property PACKAGE_PIN D12 [get_ports ad9253_dco_p[2]]
set_property PACKAGE_PIN D13 [get_ports ad9253_dco_n[2]]

set_property PACKAGE_PIN K28 [get_ports ad9253_dco_p[3]]
set_property PACKAGE_PIN K29 [get_ports ad9253_dco_n[3]]

set_property PACKAGE_PIN E19 [get_ports ad9253_dco_p[4]]
set_property PACKAGE_PIN D19 [get_ports ad9253_dco_n[4]]

set_property PACKAGE_PIN C25 [get_ports ad9253_dco_p[5]]
set_property PACKAGE_PIN B25 [get_ports ad9253_dco_n[5]]

set_property PACKAGE_PIN F21 [get_ports ad9253_dco_p[6]]
set_property PACKAGE_PIN E21 [get_ports ad9253_dco_n[6]]

set_property PACKAGE_PIN D26 [get_ports ad9253_dco_p[7]]
set_property PACKAGE_PIN C26 [get_ports ad9253_dco_n[7]]

set_property IOSTANDARD LVDS_25 [get_ports {ad9253_dco_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {ad9253_dco_n[*]}]

create_clock -name DCO -period 2 [get_ports {ad9253_dco_p[*]}]

set_property DIFF_TERM TRUE [get_ports {ad9253_dco_p[*]}]


# DAC
set_property PACKAGE_PIN V21 [get_ports dac128s085_cs_n[0]]
set_property PACKAGE_PIN U29 [get_ports dac128s085_cs_n[1]]
set_property PACKAGE_PIN T23 [get_ports dac128s085_cs_n[2]]
set_property PACKAGE_PIN T30 [get_ports dac128s085_cs_n[3]]
set_property PACKAGE_PIN U24 [get_ports dac128s085_cs_n[4]]
set_property PACKAGE_PIN T25 [get_ports dac128s085_cs_n[5]]
set_property PACKAGE_PIN V20 [get_ports dac128s085_cs_n[6]]
set_property PACKAGE_PIN T27 [get_ports dac128s085_cs_n[7]]

set_property IOSTANDARD LVCMOS33 [get_ports {dac128s085_cs_n[*]}]

set_property PACKAGE_PIN U22 [get_ports dac128s085_sdio[0]]
set_property PACKAGE_PIN V25 [get_ports dac128s085_sdio[1]]
set_property PACKAGE_PIN V24 [get_ports dac128s085_sdio[2]]
set_property PACKAGE_PIN V27 [get_ports dac128s085_sdio[3]]
set_property PACKAGE_PIN W21 [get_ports dac128s085_sdio[4]]
set_property PACKAGE_PIN R30 [get_ports dac128s085_sdio[5]]
set_property PACKAGE_PIN T21 [get_ports dac128s085_sdio[6]]
set_property PACKAGE_PIN U28 [get_ports dac128s085_sdio[7]]

set_property IOSTANDARD LVCMOS33 [get_ports {dac128s085_sdio[*]}]

set_property PACKAGE_PIN U23 [get_ports dac128s085_sclk[0]]
set_property PACKAGE_PIN U30 [get_ports dac128s085_sclk[1]]
set_property PACKAGE_PIN T22 [get_ports dac128s085_sclk[2]]
set_property PACKAGE_PIN V26 [get_ports dac128s085_sclk[3]]
set_property PACKAGE_PIN W22 [get_ports dac128s085_sclk[4]]
set_property PACKAGE_PIN U25 [get_ports dac128s085_sclk[5]]
set_property PACKAGE_PIN V19 [get_ports dac128s085_sclk[6]]
set_property PACKAGE_PIN U27 [get_ports dac128s085_sclk[7]]

set_property IOSTANDARD LVCMOS33 [get_ports {dac128s085_sclk[*]}]

# MAX40026
set_property PACKAGE_PIN AG22 [get_ports max40026_p[0]]
set_property PACKAGE_PIN AH22 [get_ports max40026_n[0]]

set_property PACKAGE_PIN AG20 [get_ports max40026_p[1]]
set_property PACKAGE_PIN AH20 [get_ports max40026_n[1]]

set_property PACKAGE_PIN AF22 [get_ports max40026_p[2]]
set_property PACKAGE_PIN AG23 [get_ports max40026_n[2]]

set_property PACKAGE_PIN AK20 [get_ports max40026_p[3]]
set_property PACKAGE_PIN AK21 [get_ports max40026_n[3]]

set_property PACKAGE_PIN AD27 [get_ports max40026_p[4]]
set_property PACKAGE_PIN AD28 [get_ports max40026_n[4]]

set_property PACKAGE_PIN AB27 [get_ports max40026_p[5]]
set_property PACKAGE_PIN AC27 [get_ports max40026_n[5]]

set_property PACKAGE_PIN AG30 [get_ports max40026_p[6]]
set_property PACKAGE_PIN AH30 [get_ports max40026_n[6]]

set_property PACKAGE_PIN AA27 [get_ports max40026_p[7]]
set_property PACKAGE_PIN AB28 [get_ports max40026_n[7]]

set_property PACKAGE_PIN AD23 [get_ports max40026_p[8]]
set_property PACKAGE_PIN AE24 [get_ports max40026_n[8]]

set_property PACKAGE_PIN AH21 [get_ports max40026_p[9]]
set_property PACKAGE_PIN AJ21 [get_ports max40026_n[9]]

set_property PACKAGE_PIN AJ22 [get_ports max40026_p[10]]
set_property PACKAGE_PIN AJ23 [get_ports max40026_n[10]]

set_property PACKAGE_PIN AK23 [get_ports max40026_p[11]]
set_property PACKAGE_PIN AK24 [get_ports max40026_n[11]]

set_property PACKAGE_PIN AE30 [get_ports max40026_p[12]]
set_property PACKAGE_PIN AF30 [get_ports max40026_n[12]]

set_property PACKAGE_PIN AD29 [get_ports max40026_p[13]]
set_property PACKAGE_PIN AE29 [get_ports max40026_n[13]]

set_property PACKAGE_PIN AE28 [get_ports max40026_p[14]]
set_property PACKAGE_PIN AF28 [get_ports max40026_n[14]]

set_property PACKAGE_PIN W27 [get_ports max40026_p[15]]
set_property PACKAGE_PIN W28 [get_ports max40026_n[15]]

set_property PACKAGE_PIN AE23 [get_ports max40026_p[16]]
set_property PACKAGE_PIN AF23 [get_ports max40026_n[16]]

set_property PACKAGE_PIN AG24 [get_ports max40026_p[17]]
set_property PACKAGE_PIN AH24 [get_ports max40026_n[17]]

set_property PACKAGE_PIN AE25 [get_ports max40026_p[18]]
set_property PACKAGE_PIN AF25 [get_ports max40026_n[18]]

set_property PACKAGE_PIN AB22 [get_ports max40026_p[19]]
set_property PACKAGE_PIN AB23 [get_ports max40026_n[19]]

set_property PACKAGE_PIN Y30 [get_ports max40026_p[20]]
set_property PACKAGE_PIN AA30 [get_ports max40026_n[20]]

set_property PACKAGE_PIN AA25 [get_ports max40026_p[21]]
set_property PACKAGE_PIN AB25 [get_ports max40026_n[21]]

set_property PACKAGE_PIN AB29 [get_ports max40026_p[22]]
set_property PACKAGE_PIN AB30 [get_ports max40026_n[22]]

set_property PACKAGE_PIN AC29 [get_ports max40026_p[23]]
set_property PACKAGE_PIN AC30 [get_ports max40026_n[23]]

set_property PACKAGE_PIN AH26 [get_ports max40026_p[24]]
set_property PACKAGE_PIN AH27 [get_ports max40026_n[24]]

set_property PACKAGE_PIN AG27 [get_ports max40026_p[25]]
set_property PACKAGE_PIN AG28 [get_ports max40026_n[25]]

set_property PACKAGE_PIN AJ28 [get_ports max40026_p[26]]
set_property PACKAGE_PIN AJ29 [get_ports max40026_n[26]]

set_property PACKAGE_PIN AK29 [get_ports max40026_p[27]]
set_property PACKAGE_PIN AK30 [get_ports max40026_n[27]]

set_property PACKAGE_PIN F15 [get_ports max40026_p[28]]
set_property PACKAGE_PIN E16 [get_ports max40026_n[28]]

set_property PACKAGE_PIN L16 [get_ports max40026_p[29]]
set_property PACKAGE_PIN K16 [get_ports max40026_n[29]]

set_property PACKAGE_PIN D22 [get_ports max40026_p[30]]
set_property PACKAGE_PIN C22 [get_ports max40026_n[30]]

set_property PACKAGE_PIN B22 [get_ports max40026_p[31]]
set_property PACKAGE_PIN A22 [get_ports max40026_n[31]]

set_property IOSTANDARD LVDS_25 [get_ports {max40026_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {max40026_n[*]}]

# tdc
set_false_path -from [get_clocks gt_refclk] -to [get_clocks clk_sys_200M]
# set_property LOC SLICE_X75Y125 [get_cells instance_tdc/instance_tdl/instance_carry4_init]

# GT
set_property PACKAGE_PIN V29 [get_ports SFP_tx_disable1]
set_property IOSTANDARD LVCMOS33 [get_ports SFP_tx_disable1]

set_property PACKAGE_PIN V30 [get_ports SFP_tx_disable2]
set_property IOSTANDARD LVCMOS33 [get_ports SFP_tx_disable2]

set_property PACKAGE_PIN G4 [get_ports SFP1_rx_p]
set_property PACKAGE_PIN G3 [get_ports SFP1_rx_n]

set_property PACKAGE_PIN H2 [get_ports SFP1_tx_p]
set_property PACKAGE_PIN H1 [get_ports SFP1_tx_n]

# set_property PACKAGE_PIN F6 [get_ports SFP2_rx_p]
# set_property PACKAGE_PIN F5 [get_ports SFP2_rx_n]

# set_property PACKAGE_PIN F2 [get_ports SFP2_tx_p]
# set_property PACKAGE_PIN F1 [get_ports SFP2_tx_n]
