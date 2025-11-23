#include <SPI.h>
#include "RF24.h"

const int x_out = A0;
const int y_out = A1;
const int z_out = A2;  
RF24 radio(8, 10); 
const byte address[6] = "00001";

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
    Serial.println("- VCC -> 3.3V");
    Serial.println("- CE -> D8, CSN -> D10");
    Serial.println("- SCK -> D13, MOSI -> D11, MISO -> D12");
    while(1); // Dừng chương trình
  }
  
  Serial.println("OK: NRF24L01+ khoi tao thanh cong!");
  
  // Cấu hình RF24 giống với Receiver
  radio.openWritingPipe(address);
  radio.setPALevel(RF24_PA_LOW);
  radio.setDataRate(RF24_250KBPS);
  radio.setChannel(76);
  radio.stopListening();
  
  Serial.println("Bat dau doc cam bien va gui tin hieu...");
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
