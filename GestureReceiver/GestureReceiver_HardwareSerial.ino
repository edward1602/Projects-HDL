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
  int zAxis;
};
data receive_data;

// Biến để theo dõi thời gian và trạng thái
unsigned long lastTime = 0;
unsigned long currentTime = 0;
char currentCommand = 'X'; // Lệnh hiện tại
char lastCommand = 'X';    // Lệnh trước đó

// Function declarations
char analyzeGesture(int x, int y, int z);
void sendMotorCommand(char command);

void setup() {
  // Hardware Serial cho giao tiếp với Motor Controller
  Serial.begin(9600);
  delay(500);
  
  // Khởi tạo RF24 (im lặng vì không thể debug qua Serial)
  radio.begin();
  radio.openReadingPipe(0, address);
  radio.startListening();
  radio.setPALevel(RF24_PA_LOW);
  radio.setDataRate(RF24_250KBPS);
  radio.setChannel(76);
  
  // Gửi lệnh dừng ban đầu
  sendMotorCommand('X');
  delay(1000);
}

void loop() {
  currentTime = millis();
  
  // Kiểm tra có dữ liệu RF không
  if(radio.available()) {
    // Đọc dữ liệu từ Transmitter
    radio.read(&receive_data, sizeof(data));
    
    // Phân tích dữ liệu và quyết định lệnh
    char newCommand = analyzeGesture(receive_data.xAxis, receive_data.yAxis, receive_data.zAxis);
    
    // Chỉ gửi lệnh khi có thay đổi để tránh spam
    if(newCommand != lastCommand) {
      currentCommand = newCommand;
      sendMotorCommand(currentCommand);
      lastCommand = currentCommand;
    }
    
    lastTime = currentTime;
  }
  
  // Kiểm tra mất kết nối
  if(currentTime - lastTime > 2000 && lastTime > 0) {
    if(currentCommand != 'X') {
      currentCommand = 'X';
      sendMotorCommand('X'); // Dừng robot khi mất tín hiệu
      lastCommand = 'X';
    }
  }
  
  delay(100); 
}

// Hàm phân tích cử chỉ và trả về lệnh tương ứng
char analyzeGesture(int x, int y, int z) {
  if(y > 390) {
    return 'W'; // Tiến lên (ASCII 87)
  } 
  else if(y < 345) {
    return 'S'; // Lùi xuống (ASCII 83)
  }
  // Sau đó mới đến X (trái/phải)
  else if(x > 385) {
    return 'A'; // Sang trái (ASCII 65)
  }
  else if(x < 335) {
    return 'D'; // Sang phải (ASCII 68)
  }
  // Kiểm tra trục Z để xoay
  else if(z > 340 && x <= 300) {
    return 'R'; // Xoay phải (ASCII 82)
  }
  else if(z > 350 && x >= 415) {
    return 'L'; // Xoay trái (ASCII 76)
  }
  // Kiểm tra vùng dừng chính xác
  else if(x>=335 && x<=385 && y>=345 && y<=390 && z>=273 && z<=285) {
    return 'X'; // Dừng (ASCII 88)
  }
  else {
    return 'X'; 
  }
}

// Hàm gửi lệnh đến Arduino Motor qua Hardware Serial
void sendMotorCommand(char command) {
  // Gửi lệnh điều khiển trước (1 ký tự)
  Serial.write(command); 
  
  // Đợi một chút để đảm bảo lệnh được gửi
  delay(5);
}

/*
HARDWARE CONNECTION:
===================

Arduino Receiver (với RF24):
- RF24: CE→D8, CSN→D10, VCC→3.3V, GND→GND
- Serial: TX(D1) → Motor RX(D0)
- Serial: RX(D0) → Motor TX(D1)  
- GND → Motor GND

Arduino Motor (với AFMotor Shield):
- AFMotor Shield gắn trực tiếp
- Serial: RX(D0) ← Receiver TX(D1)
- Serial: TX(D1) → Receiver RX(D0)
- GND → Receiver GND

*/