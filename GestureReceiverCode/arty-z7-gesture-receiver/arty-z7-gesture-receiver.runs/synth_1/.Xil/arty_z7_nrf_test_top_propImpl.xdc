set_property SRC_FILE_INFO {cfile:E:/Git_wp/Gesture_Control_Robot/GestureReceiverCode/arty-z7-gesture-receiver/arty-z7-gesture-receiver.srcs/constrs_1/imports/resource/Arty-Z7-20-Master.xdc rfile:../../../arty-z7-gesture-receiver.srcs/constrs_1/imports/resource/Arty-Z7-20-Master.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:29 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN H16    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L13P_T2_MRCC_35 Sch=SYSCLK
set_property src_info {type:XDC file:1 line:47 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN R14    IOSTANDARD LVCMOS33 } [get_ports { leds[0] }]; #IO_L6N_T0_VREF_34 Sch=LED0
set_property src_info {type:XDC file:1 line:48 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN P14    IOSTANDARD LVCMOS33 } [get_ports { leds[1] }]; #IO_L6P_T0_34 Sch=LED1
set_property src_info {type:XDC file:1 line:49 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN N16    IOSTANDARD LVCMOS33 } [get_ports { leds[2] }]; #IO_L21N_T3_DQS_AD14N_35 Sch=LED2
set_property src_info {type:XDC file:1 line:50 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN M14    IOSTANDARD LVCMOS33 } [get_ports { leds[3] }]; #IO_L23P_T3_35 Sch=LED3
set_property src_info {type:XDC file:1 line:53 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN D19    IOSTANDARD LVCMOS33 } [get_ports { reset_btn }]; #IO_L4P_T0_35 Sch=BTN0
set_property src_info {type:XDC file:1 line:89 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN T14    IOSTANDARD LVCMOS33 } [get_ports { pwm_motor_a }]; #IO_L5P_T0_34             Sch=CK_IO0
set_property src_info {type:XDC file:1 line:90 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U12    IOSTANDARD LVCMOS33 } [get_ports { motor_dir[0] }]; #IO_L2N_T0_34             Sch=CK_IO1
set_property src_info {type:XDC file:1 line:91 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U13    IOSTANDARD LVCMOS33 } [get_ports { motor_dir[1] }]; #IO_L3P_T0_DQS_PUDC_B_34 Sch=CK_IO2
set_property src_info {type:XDC file:1 line:92 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V13    IOSTANDARD LVCMOS33 } [get_ports { pwm_motor_b }]; #IO_L3N_T0_DQS_34         Sch=CK_IO3
set_property src_info {type:XDC file:1 line:93 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V15    IOSTANDARD LVCMOS33 } [get_ports { motor_dir[2] }]; #IO_L10P_T1_34            Sch=CK_IO4
set_property src_info {type:XDC file:1 line:94 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN T15    IOSTANDARD LVCMOS33 } [get_ports { motor_dir[3] }]; #IO_L5N_T0_34             Sch=CK_IO5
set_property src_info {type:XDC file:1 line:101 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V17    IOSTANDARD LVCMOS33 } [get_ports { nrf_irq }]; #IO_L21P_T3_DQS_34        Sch=CK_IO8
set_property src_info {type:XDC file:1 line:102 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V18    IOSTANDARD LVCMOS33 } [get_ports { nrf_ce  }]; #IO_L21N_T3_DQS_34        Sch=CK_IO9
set_property src_info {type:XDC file:1 line:103 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN T16    IOSTANDARD LVCMOS33 } [get_ports { nrf_csn }]; #IO_L9P_T1_DQS_34         Sch=CK_IO10
set_property src_info {type:XDC file:1 line:104 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN R17    IOSTANDARD LVCMOS33 } [get_ports { nrf_mosi }]; #IO_L19N_T3_VREF_34       Sch=CK_IO11
set_property src_info {type:XDC file:1 line:105 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN P18    IOSTANDARD LVCMOS33 } [get_ports { nrf_miso }]; #IO_L23N_T3_34            Sch=CK_IO12
set_property src_info {type:XDC file:1 line:106 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN N17    IOSTANDARD LVCMOS33 } [get_ports { nrf_sck }]; #IO_L23P_T3_34            Sch=CK_IO13
set_property src_info {type:XDC file:1 line:109 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U5     IOSTANDARD LVCMOS33 } [get_ports { payload_ready }]; #IO_L19N_T3_VREF_13  Sch=CK_IO26
set_property src_info {type:XDC file:1 line:110 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V5     IOSTANDARD LVCMOS33 } [get_ports { nrf_irq }]; #IO_L6N_T0_VREF_13   Sch=CK_IO27
set_property src_info {type:XDC file:1 line:111 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V6     IOSTANDARD LVCMOS33 } [get_ports { nrf_csn }]; #IO_L22P_T3_13       Sch=CK_IO28
set_property src_info {type:XDC file:1 line:112 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U7     IOSTANDARD LVCMOS33 } [get_ports { nrf_mosi }]; #IO_L11P_T1_SRCC_13  Sch=CK_IO29
set_property src_info {type:XDC file:1 line:113 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V7     IOSTANDARD LVCMOS33 } [get_ports { nrf_miso }]; #IO_L11N_T1_SRCC_13  Sch=CK_IO30
set_property src_info {type:XDC file:1 line:114 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN U8     IOSTANDARD LVCMOS33 } [get_ports { nrf_sck }]; #IO_L17N_T2_13       Sch=CK_IO31
