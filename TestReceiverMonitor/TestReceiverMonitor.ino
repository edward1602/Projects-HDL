// File kiểm thử giá trị xAxis, yAxis từ Transmitter
// Hiển thị dữ liệu qua Serial Monitor và Serial Plotter
// Kết nối NRF24L01+ giống như GestureReceiverCode

#include <SPI.h>
#include "RF24.h"

// Khai báo chân NRF24L01+
RF24 radio(8, 10);  // CE, CSN

// Địa chỉ giống với Transmitter
const byte address[6] = "00001";

// Cấu trúc dữ liệu nhận từ Transmitter
struct data {
  int xAxis;
  int yAxis;
  int zAxis;  // Thêm trục Z
};
data receive_data;

// Biến để theo dõi thời gian
unsigned long lastTime = 0;
unsigned long currentTime = 0;

void setup() {
  // Khởi tạo Serial với tốc độ cao để hiển thị real-time
  Serial.begin(115200);
  
  // Khởi tạo RF24
  radio.begin();
  radio.openReadingPipe(0, address);
  radio.startListening();
  
  // Cấu hình RF24 để tối ưu
  radio.setPALevel(RF24_PA_LOW);
  radio.setDataRate(RF24_250KBPS);
  radio.setChannel(76);
  
  Serial.println("=== TEST RECEIVER MONITOR ===");
  Serial.println("Bat dau nhan du lieu tu Transmitter...");
  Serial.println("Mo Serial Plotter de xem do thi real-time!");
  Serial.println("Tools > Serial Plotter");
  Serial.println("=====================================");
  delay(2000);
  
  // Header cho Serial Plotter
  Serial.println("xAxis,yAxis,zAxis,Time");
}

void loop() {
  currentTime = millis();
  
  // Kiểm tra có dữ liệu RF không
  while(radio.available()) {
    // Đọc dữ liệu từ Transmitter
    radio.read(&receive_data, sizeof(data));
    
    // Hiển thị chi tiết trên Serial Monitor
    Serial.print("Time: ");
    Serial.print(currentTime);
    Serial.print(" ms | X: ");
    Serial.print(receive_data.xAxis);
    Serial.print(" | Y: ");
    Serial.print(receive_data.yAxis);
    Serial.print(" | Z: ");
    Serial.print(receive_data.zAxis);
    
    // Phân tích hướng di chuyển
    Serial.print(" | Direction: ");
    if(receive_data.yAxis > 400) {
      Serial.print("FORWARD");
    } else if(receive_data.yAxis < 320) {
      Serial.print("BACKWARD");
    } else if(receive_data.xAxis < 320) {
      Serial.print("LEFT");
    } else if(receive_data.xAxis > 400) {
      Serial.print("RIGHT");
    } else {
      Serial.print("STOP");
    }
    
    // Phân tích trạng thái trục Z
    Serial.print(" | Speed: ");
    if(receive_data.zAxis > 450) {
      Serial.print("TANG TOC");
    } else if(receive_data.zAxis < 350) {
      Serial.print("GIAM TOC");
    } else {
      Serial.print("BINH THUONG");
    }
    
    Serial.println();
    
    // Dữ liệu cho Serial Plotter (định dạng CSV)
    Serial.print(receive_data.xAxis);
    Serial.print(",");
    Serial.print(receive_data.yAxis);
    Serial.print(",");
    Serial.print(receive_data.zAxis);
    Serial.print(",");
    Serial.println(currentTime/1000.0); // Thời gian tính bằng giây
    
    lastTime = currentTime;
  }
  
  // Kiểm tra mất kết nối
  if(currentTime - lastTime > 2000) { // 2 giây không nhận được tín hiệu
    if((currentTime - lastTime) % 5000 == 0) { // Báo mỗi 5 giây
      Serial.println("WARNING: Khong nhan duoc tin hieu tu Transmitter!");
      Serial.println("Kiem tra: ");
      Serial.println("- Transmitter da bat chua?");
      Serial.println("- Ket noi NRF24L01+ dung chua?");
      Serial.println("- Khoang cach qua xa?");
      Serial.println("=====================================");
    }
  }
  
  delay(10); // Delay nhỏ để tránh spam
}

// Hàm hiển thị thống kê (có thể gọi khi cần)
void printStatistics() {
  Serial.println("\n=== THONG KE ===");
  Serial.println("Cac gia tri cam bien ADXL335 (3 truc):");
  Serial.println("- Trung tam (dung yen): X~360, Y~360, Z~400");
  Serial.println("- Nghieng trai: X < 320");
  Serial.println("- Nghieng phai: X > 400");  
  Serial.println("- Nghieng len: Y > 400");
  Serial.println("- Nghieng xuong: Y < 320");
  Serial.println("- Mat phang: Z~400-450");
  Serial.println("- Nghieng doc: Z < 300 hoac Z > 500");
  Serial.println("=================\n");
}