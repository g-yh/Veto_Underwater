# clk, 200MHz
set_property PACKAGE_PIN AE10 [get_ports clk_200M_p]
set_property PACKAGE_PIN AF10 [get_ports clk_200M_n]
set_property IOSTANDARD LVDS [get_ports clk_200M_p]
create_clock -period 5.000 [get_ports clk_200M_p]


# Si5338 clock, 125MHz
# set_property PACKAGE_PIN C8 [get_ports SGMII_clk_p]
# set_property PACKAGE_PIN C7 [get_ports SGMII_clk_n]
# set_property IOSTANDARD DIFF_SSTL15 [get_ports SGMII_clk_p]
# set_property IOSTANDARD DIFF_SSTL15 [get_ports SGMII_clk_n]

# reset, button
set_property PACKAGE_PIN AG28 [get_ports rst_sys]
set_property IOSTANDARD LVCMOS33 [get_ports rst_sys]

# SFP, port 4
set_property PACKAGE_PIN F6 [get_ports SFP_rx_p]
set_property PACKAGE_PIN F5 [get_ports SFP_rx_n]
set_property PACKAGE_PIN F2 [get_ports SFP_tx_p]
set_property PACKAGE_PIN F1 [get_ports SFP_tx_n]
# set_property IOSTANDARD LVCMOS15 [get_ports SFP*]
set_property PACKAGE_PIN U25 [get_ports SFP_tx_disable]
set_property IOSTANDARD LVCMOS33 [get_ports SFP_tx_disable]


# set_false_path -to [get_pins {IB_SIG_DET*/D}]

set_property IOB false [get_cells -hierarchical -filter {name =~ */GMII_RXCNT/IOB_RD_*}]
set_property IOB false [get_cells -hierarchical -filter {name =~ */GMII_RXCNT/IOB_RDV}]
set_property IOB false [get_cells -hierarchical -filter {name =~ */GMII_RXCNT/IOB_RERR}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 6 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]


# Si5338, clk 125M for SGMII_clk
set_property PACKAGE_PIN G8 [get_ports clk_125M_si5338_p]
set_property PACKAGE_PIN G7 [get_ports clk_125M_si5338_n]
#set_property IOSTANDARD LVDS [get_ports clk_125M_si5338*]
create_clock -period 8.000 [get_ports clk_125M_si5338_p]

set_property PACKAGE_PIN L8 [get_ports clk1p]
set_property PACKAGE_PIN L7 [get_ports clk1n]

set_property PACKAGE_PIN P23 [get_ports si5338_scl]
set_property IOSTANDARD LVCMOS33 [get_ports si5338_scl]

set_property PACKAGE_PIN N25 [get_ports si5338_sda]
set_property IOSTANDARD LVCMOS33 [get_ports si5338_sda]

set_property PACKAGE_PIN T25 [get_ports si5338_i2c_lsb]
set_property IOSTANDARD LVCMOS33 [get_ports si5338_i2c_lsb]
