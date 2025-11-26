## Clock constraint for Arty Z7 (125MHz)
set_property -dict { PACKAGE_PIN H16    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Reset Button (BTN0)
set_property -dict { PACKAGE_PIN D19    IOSTANDARD LVCMOS33 } [get_ports { reset_btn }];

## LEDs (4 debug LEDs)
set_property -dict { PACKAGE_PIN R14    IOSTANDARD LVCMOS33 } [get_ports { leds[0] }];
set_property -dict { PACKAGE_PIN P14    IOSTANDARD LVCMOS33 } [get_ports { leds[1] }];
set_property -dict { PACKAGE_PIN N16    IOSTANDARD LVCMOS33 } [get_ports { leds[2] }];
set_property -dict { PACKAGE_PIN M14    IOSTANDARD LVCMOS33 } [get_ports { leds[3] }];

## NRF24L01 pins (Arduino header IO8-IO13)
set_property -dict { PACKAGE_PIN V17    IOSTANDARD LVCMOS33 } [get_ports { nrf_irq }];
set_property -dict { PACKAGE_PIN V18    IOSTANDARD LVCMOS33 } [get_ports { nrf_ce }];
set_property -dict { PACKAGE_PIN T16    IOSTANDARD LVCMOS33 } [get_ports { nrf_csn }];
set_property -dict { PACKAGE_PIN R17    IOSTANDARD LVCMOS33 } [get_ports { nrf_mosi }];
set_property -dict { PACKAGE_PIN P18    IOSTANDARD LVCMOS33 } [get_ports { nrf_miso }];
set_property -dict { PACKAGE_PIN N17    IOSTANDARD LVCMOS33 } [get_ports { nrf_sck }];

## Timing constraints (ignore timing for slow interfaces)
set_false_path -from [get_ports { reset_btn }]
set_false_path -from [get_ports { nrf_miso }]
set_false_path -from [get_ports { nrf_irq }]
set_false_path -to [get_ports { leds[*] }]
set_false_path -to [get_ports { nrf_ce }]
set_false_path -to [get_ports { nrf_csn }]
set_false_path -to [get_ports { nrf_sck }]
set_false_path -to [get_ports { nrf_mosi }]