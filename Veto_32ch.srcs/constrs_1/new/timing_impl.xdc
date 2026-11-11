# Implementation-only clock-domain groups. ADC FCO/DCO, GT recovered RX/TX,
# and the system/DRP clocks are independent clock trees.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks {clk_sys_200M clk_sys_125M}] \
    -group [get_clocks -include_generated_clocks {FCO DCO}] \
    -group [get_clocks -regexp {.*RXOUTCLK.*}] \
    -group [get_clocks -regexp {.*TXOUTCLK.*}]
