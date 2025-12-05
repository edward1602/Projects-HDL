# Motor Controller Implementation for Arty Z7

## 📋 Tổng quan

Module này hiện thực logic điều khiển motor L298N trên FPGA Arty Z7, thay thế bộ Arduino receiver ban đầu. Nó nhận dữ liệu gesture từ module NRF24L01+ và điều khiển 2 động cơ DC dựa trên giá trị X, Y, Z axis.

## 🔌 Kết nối phần cứng

### **Arty Z7 → L298N Motor Driver**

| Arty Z7 Pin | Arduino Connector | L298N Pin | Chức năng | Mô tả |
|-------------|-------------------|-----------|-----------|-------|
| T14 (IO0) | CK_IO0 | ENA | PWM Motor A | PWM điều khiển tốc độ Motor A |
| U12 (IO1) | CK_IO1 | IN1 | Direction A1 | Chiều quay Motor A (bit 1) |
| U13 (IO2) | CK_IO2 | IN2 | Direction A2 | Chiều quay Motor A (bit 2) |
| V13 (IO3) | CK_IO3 | ENB | PWM Motor B | PWM điều khiển tốc độ Motor B |
| V15 (IO4) | CK_IO4 | IN3 | Direction B1 | Chiều quay Motor B (bit 1) |
| T15 (IO5) | CK_IO5 | IN4 | Direction B2 | Chiều quay Motor B (bit 2) |

### **Arty Z7 → NRF24L01+**

| Arty Z7 Pin | Arduino Connector | NRF Pin | Chức năng |
|-------------|-------------------|---------|-----------|
| V17 (IO8) | CK_IO8 | IRQ | Interrupt (Active Low) |
| V18 (IO9) | CK_IO9 | CE | Chip Enable |
| T16 (IO10) | CK_IO10 | CSN | Chip Select (Active Low) |
| R17 (IO11) | CK_IO11 | MOSI | SPI Data Out |
| P18 (IO12) | CK_IO12 | MISO | SPI Data In |
| N17 (IO13) | CK_IO13 | SCK | SPI Clock |

### **L298N Power**
- **VCC (Logic)**: 5V từ nguồn ngoài
- **12V (Motor)**: 12V battery hoặc power supply
- **GND**: Chung mass với Arty Z7

## 🎮 Logic điều khiển

Logic điều khiển motor dựa trên file `GestureReceiver_HardwareSerial.ino`:

### **1. FORWARD (Tiến lên)**
```
Điều kiện: Y > 390
Motor A: IN1=LOW, IN2=HIGH
Motor B: IN3=HIGH, IN4=LOW
Tốc độ: 
  - Y = 390 → Speed = 100 (39%)
  - Y = 420+ → Speed = 255 (100%)
  - Giữa 390-420: Linear mapping
```

### **2. BACKWARD (Lùi xuống)**
```
Điều kiện: X < 310
Motor A: IN1=HIGH, IN2=LOW
Motor B: IN3=LOW, IN4=HIGH
Tốc độ:
  - X = 310 → Speed = 100 (39%)
  - X = 335- → Speed = 255 (100%)
  - Giữa 310-335: Inverse linear mapping
```

### **3. LEFT (Sang trái)**
```
Điều kiện: X < 320
Motor A: IN1=HIGH, IN2=LOW
Motor B: IN3=HIGH, IN4=LOW
Tốc độ: 150 (59%) cố định
```

### **4. RIGHT (Sang phải)**
```
Điều kiện: X > 400
Motor A: IN1=LOW, IN2=HIGH
Motor B: IN3=LOW, IN4=HIGH
Tốc độ: 150 (59%) cố định
```

### **5. STOP (Dừng)**
```
Điều kiện: 
  - Vị trí neutral (320 ≤ X ≤ 400, Y ≤ 390)
  - Connection timeout (> 2 seconds no data)
Motor A: IN1=LOW, IN2=LOW
Motor B: IN3=LOW, IN4=LOW
Tốc độ: 0
```

## 📊 PWM Specifications

- **Frequency**: 1 kHz (1ms period)
- **Resolution**: 8-bit (0-255)
- **Clock**: 100 MHz system clock
- **Duty Cycle Formula**: `duty_cycle / 255 * 100%`

### Mapping tốc độ:
```
duty_cycle = 0   → 0% PWM   → Motor OFF
duty_cycle = 100 → 39% PWM  → Slow speed
duty_cycle = 150 → 59% PWM  → Medium speed
duty_cycle = 255 → 100% PWM → Full speed
```

## 🔧 Module Parameters

**Top Module: `top_v2.v`**
```verilog
module top_v2 (
    // NRF24 interface
    input clk, reset_btn, nrf_irq, nrf_miso,
    output nrf_ce, nrf_csn, nrf_sck, nrf_mosi,
    
    // Motor outputs (NEW)
    output motor_a1, motor_a2, motor_b1, motor_b2,
    output pwm_ena, pwm_enb,
    
    // Debug
    output payload_ready, output [3:0] leds
);
```

**Motor Controller Instance:**
```verilog
motor_controller #(
    .CLK_FREQ(100_000_000),  // 100MHz Arty Z7 clock
    .PWM_FREQ(1000),         // 1kHz PWM frequency
    .TIMEOUT_MS(2000)        // 2 second connection timeout
) motor_ctrl_inst (
    // ... ports
);
```

## 🧪 Testing

### **Simulation**
```tcl
# Test motor controller riêng
launch_simulation -simset sim_1 -mode behavioral
run 10ms

# Test toàn bộ hệ thống (NRF → Motor)
# Set tb_top_v2_motor as top
set_property top tb_top_v2_motor [get_filesets sim_1]
launch_simulation
run 5ms
```

### **Hardware Test với Fixed Data**
Dùng `GestureTransmitterCode_FixedData.ino` để gửi giá trị cố định:
```cpp
x_axis = 100;  // Backward
y_axis = 120;  // Neutral
z_axis = 140;  // Not used
```

### **Expected Behavior**
- LED[0] sáng khi nhận được payload
- LED[1] nhấp nháy theo SPI clock
- Motor phản ứng theo gesture trong vòng 500ms
- Motor dừng sau 2s nếu mất tín hiệu

## 📁 File Structure

```
arty-z7-gesture-receiver/
├── sources_1/new/
│   ├── top_v2.v                   # Top module with motor (ACTIVE)
│   ├── motor_controller.v         # Motor control logic (NEW)
│   ├── payload_assembler.v        # X/Y/Z extraction
│   ├── nrf24l01_rx_controller.v   # NRF24 SPI interface
│   └── nrf24l01_rx_defines.v      # NRF24 constants
├── sim_1/new/
│   ├── tb_motor_controller.v      # Motor testbench (NEW)
│   └── tb_top_v2_motor.v          # Full system testbench (NEW)
└── constrs_1/imports/resource/
    └── Arty-Z7-20-Master.xdc      # Pin constraints (updated)
```

## ⚠️ Lưu ý quan trọng

### **1. Voltage Level**
- Arty Z7 output: 3.3V LVCMOS33
- L298N logic input: 5V tolerant (OK với 3.3V)
- Nếu cần level shifter: Dùng 74HC245 hoặc tương tự

### **2. Power Supply**
- Motor 12V **KHÔNG** được nối vào Arty Z7
- L298N VCC (logic) cần 5V riêng
- GND phải chung giữa tất cả các board

### **3. Debugging**
- Dùng ILA (Integrated Logic Analyzer) để bắt tín hiệu:
```tcl
create_debug_core u_ila_0 ila
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets {gesture_x[*]}]
```

### **4. Timing**
- Motor control pins có `set_false_path` → không cần strict timing
- PWM frequency 1kHz đủ smooth cho motor DC
- Connection timeout 2s phù hợp với human reaction time

## 🐛 Troubleshooting

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|-------------|-----------|
| Motor không chạy | PWM duty cycle = 0 | Kiểm tra gesture thresholds |
| Motor chạy một chiều | Direction bits sai | Kiểm tra IN1-IN4 mapping |
| Motor chạy ngược | Wiring sai | Đảo IN1↔IN2 hoặc IN3↔IN4 |
| Motor dừng liên tục | Timeout trigger | Kiểm tra NRF24 connection |
| PWM không đều | Clock jitter | Kiểm tra PLL/MMCM lock |
| Không nhận payload | SPI timing sai | Verify SCK frequency < 10MHz |

## 📝 Changes from Arduino Version

| Feature | Arduino | FPGA (Arty Z7) |
|---------|---------|----------------|
| PWM Generation | `analogWrite()` 490Hz | Hardware PWM 1kHz |
| Timeout Check | `millis()` polling | Counter-based FSM |
| Data Processing | Interrupt-driven | Continuous pipelined |
| Motor Control | Software GPIO | Hardware parallel outputs |
| Debugging | Serial.print() | ILA / Simulation |

## 🚀 Next Steps

1. **Synthesis & Implementation**
   ```tcl
   reset_run synth_1
   launch_runs synth_1 -jobs 8
   wait_on_run synth_1
   launch_runs impl_1 -to_step write_bitstream -jobs 8
   wait_on_run impl_1
   ```

2. **Program FPGA**
   ```tcl
   open_hw_manager
   connect_hw_server
   open_hw_target
   set_property PROGRAM.FILE {path/to/top.bit} [get_hw_devices xc7z020_1]
   program_hw_devices [get_hw_devices xc7z020_1]
   ```

3. **Real-time Test**
   - Upload transmitter code lên Arduino với sensor
   - Power on cả 2 boards
   - Test các gesture: Forward, Backward, Left, Right
   - Verify motor response time và smooth acceleration

## 📚 References

- [Arty Z7 Reference Manual](https://digilent.com/reference/programmable-logic/arty-z7/reference-manual)
- [L298N Datasheet](https://www.st.com/resource/en/datasheet/l298.pdf)
- [nRF24L01+ Datasheet](https://www.sparkfun.com/datasheets/Components/SMD/nRF24L01Pluss_Preliminary_Product_Specification_v1_0.pdf)
- Arduino GestureReceiver: `GestureReceiver/GestureReceiver_HardwareSerial/GestureReceiver_HardwareSerial.ino`

---

**Author**: GitHub Copilot  
**Date**: December 5, 2025  
**Version**: 1.0
