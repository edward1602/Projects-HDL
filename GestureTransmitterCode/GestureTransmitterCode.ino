#include <SPI.h>
#include "RF24.h"

const int x_out = A0;
const int y_out = A1;
const int z_out = A2;  
RF24 radio(8, 10); 
// const uint8_t address[5] = {0x30, 0x30, 0x30, 0x30, 0x31};
const uint8_t address[5] = {0xE7, 0xE7, 0xE7, 0xE7, 0xE7};

struct data {
  int xAxis;
  int yAxis;
  int zAxis;  
};
data send_data;

void setup() {
  Serial.begin(9600);
  
  Serial.println("=== GESTURE TRANSMITTER ===");
  Serial.println("Kiem tra NRF24L01+...");
  
  // Kiểm tra khởi tạo NRF24L01+
  if (!radio.begin()) {
    Serial.println("ERROR: NRF24L01+ khong phan hoi!");
    Serial.println("Kiem tra ket noi day:");
    // Serial.println("- VCC -> 3.3V");
    // Serial.println("- CE -> D8, CSN -> D10");
    // Serial.println("- SCK -> D13, MOSI -> D11, MISO -> D12");
    while(1); // Dừng chương trình
  }
  
  Serial.println("OK: NRF24L01+ khoi tao thanh cong!");
  
  // 1. Kênh 76 (0x4C)
  radio.setChannel(2);             
  
  // 2. Tốc độ 250KBPS (0x26)
  radio.setDataRate(RF24_250KBPS);  
  
  // 3. Công suất thấp (để test gần)
  radio.setPALevel(RF24_PA_LOW);    
  
  // 4. Tắt AutoAck (Verilog EN_AA = 0x00)
  radio.setAutoAck(false);          
  
  // 5. Payload cố định 6 byte (Verilog RX_PW_P0 = 0x06)
  radio.disableDynamicPayloads();
  radio.setPayloadSize(6);          
  
  // 6. CRC 2 Byte (Verilog CONFIG = 0x0F -> CRCO=1)
  radio.setCRCLength(RF24_CRC_16);  // <--- CỰC KỲ QUAN TRỌNG
  
  radio.openWritingPipe(address);
  radio.stopListening();
  
  Serial.println("Setup OK. Dang gui du lieu...");
  Serial.println(sizeof(data));
  delay(2000);
}
void loop() {
  // Đọc giá trị từ cảm biến ADXL335 (3 trục)
  send_data.xAxis = analogRead(x_out);
  send_data.yAxis = analogRead(y_out);
  send_data.zAxis = analogRead(z_out);
  
  // Gửi qua RF24

  bool result = radio.write(&send_data, sizeof(data));
  
  // Debug thông tin (có thể comment để giảm spam)
  Serial.print("X: ");
  Serial.print(send_data.xAxis);
  Serial.print(" | Y: ");
  Serial.print(send_data.yAxis);
  Serial.print(" | Z: ");
  Serial.print(send_data.zAxis);
  Serial.print(" | Gui: ");
  Serial.println(result ? "OK" : "FAIL");
  
  delay(100); // Tần số 10Hz - đủ nhanh cho điều khiển
}

// Test receive code from arty-z7
// #include <SPI.h>
// #include <RF24.h>

// RF24 radio(8, 10); // CE=8, CSN=10 (Sửa lại nếu bạn nối khác)
// const uint8_t address[5] = {0xE7, 0xE7, 0xE7, 0xE7, 0xE7};

// void setup() {
//   Serial.begin(9600);
//   Serial.println("--- ARDUINO RECEIVER TEST ---");

//   if (!radio.begin()) {
//     Serial.println("Radio Hardware Error");
//     while (1);
//   }

//   radio.setChannel(2);
//   radio.setDataRate(RF24_250KBPS);
//   radio.setPALevel(RF24_PA_LOW);
//   radio.setAutoAck(false); // Tắt AutoAck để khớp FPGA đơn giản
//   radio.disableDynamicPayloads();
//   radio.setPayloadSize(1); // Chỉ nhận 1 byte test
//   radio.setCRCLength(RF24_CRC_16);

//   radio.openReadingPipe(1, address);
//   radio.startListening(); // Chế độ Thu
  
//   Serial.println("Listening...");
// }

// void loop() {
//   if (radio.available()) {
//     uint8_t received_data;
//     radio.read(&received_data, sizeof(received_data));
    
//     Serial.print("Received: ");
//     Serial.println(received_data); // Bạn sẽ thấy số tăng dần: 0, 1, 2...
//   }
// }