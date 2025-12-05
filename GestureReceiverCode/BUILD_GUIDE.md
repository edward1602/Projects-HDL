# Quick Build Guide - top_v2 với Motor Controller

## 🚀 Build & Program Workflow

### **1. Mở Project trong Vivado**
```tcl
cd C:/Users/Acer/Documents/Do_an/GestureReceiverCode/arty-z7-gesture-receiver
start vivado arty-z7-gesture-receiver.xpr
```

### **2. Set top_v2 làm Top Module**
```tcl
# Trong Vivado TCL Console
set_property top top_v2 [current_fileset]
update_compile_order -fileset sources_1
```

### **3. Kiểm tra Design Sources**
Đảm bảo các file sau có trong project:
- ✅ `top_v2.v` (top module)
- ✅ `motor_controller.v` (NEW)
- ✅ `payload_assembler.v`
- ✅ `nrf24l01_rx_controller.v`
- ✅ `Arty-Z7-20-Master.xdc` (constraints)

### **4. Run Simulation (Optional)**
```tcl
# Test motor controller riêng
set_property top tb_motor_controller [get_filesets sim_1]
launch_simulation
run 10ms

# Test toàn bộ hệ thống
set_property top tb_top_v2_motor [get_filesets sim_1]
relaunch_sim
run 5ms
```

### **5. Synthesize**
```tcl
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check kết quả
open_run synth_1
report_utilization -file utilization_synth.txt
```

**Expected Utilization:**
```
+-------------------------+--------+--------+
| Resource                | Used   | %      |
+-------------------------+--------+--------+
| Slice LUTs              | ~1500  | ~2.8%  |
| Slice Registers         | ~800   | ~0.75% |
| Block RAM               | 0      | 0%     |
| DSPs                    | 0      | 0%     |
+-------------------------+--------+--------+
```

### **6. Implementation**
```tcl
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check timing
open_run impl_1
report_timing_summary -file timing_summary.txt
```

**Expected Timing:**
- WNS (Worst Negative Slack): > 0 ns ✅
- TNS (Total Negative Slack): 0 ns ✅
- WHS (Worst Hold Slack): > 0 ns ✅

### **7. Generate Bitstream**
```tcl
# Nếu chưa có bitstream
open_run impl_1
write_bitstream -force top_v2.bit
```

### **8. Program FPGA**
```tcl
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# Program
set_property PROGRAM.FILE {./arty-z7-gesture-receiver.runs/impl_1/top_v2.bit} [get_hw_devices xc7z020_1]
set_property PROBES.FILE {} [get_hw_devices xc7z020_1]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7z020_1]
program_hw_devices [get_hw_devices xc7z020_1]
refresh_hw_device [lindex [get_hw_devices xc7z020_1] 0]
```

---

## 🔍 Debug với ILA (Integrated Logic Analyzer)

### **Thêm ILA để bắt tín hiệu motor**
```tcl
# Tạo ILA core
create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]

# Thêm probes
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets {assembler_inst/x_axis_out[*]}]

set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets {assembler_inst/y_axis_out[*]}]

set_property port_width 6 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets {motor_a1 motor_a2 motor_b1 motor_b2 pwm_ena pwm_enb}]

# Implement lại
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
```

---

## 📊 Pin Mapping Check

Verify pin assignments trong Vivado:
```tcl
# Xem tất cả motor pins
get_ports motor_*
get_ports pwm_*

# Check constraints
report_io -file io_report.txt
```

**Expected Output:**
```
Port         | Package Pin | I/O Standard | Direction
-------------|-------------|--------------|----------
pwm_ena      | T14         | LVCMOS33     | OUTPUT
motor_a1     | U12         | LVCMOS33     | OUTPUT
motor_a2     | U13         | LVCMOS33     | OUTPUT
pwm_enb      | V13         | LVCMOS33     | OUTPUT
motor_b1     | V15         | LVCMOS33     | OUTPUT
motor_b2     | T15         | LVCMOS33     | OUTPUT
```

---

## ⚠️ Common Issues & Solutions

### **Issue 1: "Cannot find top_v2.v"**
```tcl
# Solution: Add file to project
add_files -norecurse ./arty-z7-gesture-receiver.srcs/sources_1/new/top_v2.v
add_files -norecurse ./arty-z7-gesture-receiver.srcs/sources_1/new/motor_controller.v
update_compile_order -fileset sources_1
```

### **Issue 2: "Undefined reference to motor_controller"**
```tcl
# Solution: Check file is in design sources
get_files -of_objects [get_filesets sources_1]
# Nếu thiếu, add file như trên
```

### **Issue 3: Timing không đáp ứng (WNS < 0)**
```tcl
# Solution: Thêm timing exceptions trong XDC
set_false_path -from [get_clocks clk] -to [get_ports {motor_* pwm_*}]
```

### **Issue 4: Pin conflicts**
```
ERROR: [Place 30-574] Poor placement for routing between an IO pin and BUFG.
```
```tcl
# Solution: Check clock constraints
report_clock_networks -file clock_networks.txt
# Verify BUFG is used for main clock
```

---

## 🧪 Hardware Test Checklist

### **Trước khi power on:**
- [ ] Kiểm tra kết nối Arty Z7 → L298N (6 pins motor)
- [ ] Kiểm tra kết nối Arty Z7 → NRF24 (6 pins SPI)
- [ ] L298N có nguồn 12V riêng cho motor
- [ ] L298N VCC logic nối 5V
- [ ] GND chung giữa Arty Z7, L298N, NRF24
- [ ] Motor nối đúng OUT1/OUT2 (Motor A), OUT3/OUT4 (Motor B)

### **Sau khi program FPGA:**
- [ ] LED[2] sáng → RX ready
- [ ] Upload code lên Arduino transmitter
- [ ] LED[0] nhấp nháy khi transmitter gửi → Nhận payload OK
- [ ] Motor phản ứng theo gesture trong 500ms
- [ ] Motor dừng sau 2s nếu tắt transmitter

### **Test sequence:**
1. **Neutral** (X≈350, Y≈350) → Motor STOP
2. **Forward** (nghiêng tay lên, Y>390) → Motor tiến
3. **Backward** (nghiêng tay xuống, X<310) → Motor lùi
4. **Left** (nghiêng tay trái, X<320) → Motor trái
5. **Right** (nghiêng tay phải, X>400) → Motor phải

---

## 📈 Performance Monitoring

### **Trong Vivado Hardware Manager:**
```tcl
# Đọc giá trị real-time từ ILA
run_hw_ila hw_ila_1
wait_on_hw_ila hw_ila_1
display_hw_ila_data [upload_hw_ila_data hw_ila_1]
```

### **Trên hardware:**
- Dùng oscilloscope đo PWM_ENA, PWM_ENB
  - Frequency: ≈1 kHz
  - Duty cycle: 0-100% (0V-3.3V)
- Dùng logic analyzer bắt SPI (MOSI, MISO, SCK, CSN)
  - SCK frequency: < 10 MHz
  - Payload: 6 bytes mỗi packet

---

## 📝 Build Log Template

```
================================
Build: top_v2 với Motor Controller
Date: December 5, 2025
================================

1. Synthesis:
   - Duration: ~2 minutes
   - LUTs Used: 1500 / 53200 (2.8%)
   - Status: ✅ PASS

2. Implementation:
   - Duration: ~3 minutes
   - WNS: +2.5ns
   - Status: ✅ PASS

3. Bitstream:
   - File: top_v2.bit
   - Size: ~400KB
   - Status: ✅ Generated

4. Programming:
   - Device: xc7z020clg400-1
   - Status: ✅ SUCCESS

5. Hardware Test:
   - NRF24 RX: ✅ OK
   - Payload Parse: ✅ OK
   - Motor Control: ✅ OK
   - Timeout: ✅ OK

================================
Result: READY FOR DEPLOYMENT
================================
```

---

**Last Updated**: December 5, 2025  
**Module Version**: top_v2 with integrated motor controller
