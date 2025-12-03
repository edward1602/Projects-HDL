#include <SPI.h>
#include "RF24.h"

// Motor control pins
int ENA = 3;
int ENB = 9;
int MotorA1 = 4;
int MotorA2 = 5;
int MotorB1 = 6;
int MotorB2 = 7;

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

void setup() {
  // Serial for debugging
  Serial.begin(9600);
  
  // Khởi tạo RF24
  radio.begin();
  radio.openReadingPipe(0, address);
  radio.startListening();
  radio.setPALevel(RF24_PA_LOW);
  radio.setDataRate(RF24_250KBPS);
  radio.setChannel(76);
  
  // Khởi tạo motor pins
  pinMode(ENA, OUTPUT);
  pinMode(ENB, OUTPUT);
  pinMode(MotorA1, OUTPUT);
  pinMode(MotorA2, OUTPUT);
  pinMode(MotorB1, OUTPUT);
  pinMode(MotorB2, OUTPUT);
  
  delay(1000);
}

void loop() {
  // Kiểm tra có dữ liệu RF không
  while(radio.available()) {
    radio.read(&receive_data, sizeof(data));
    
    // Debug: In dữ liệu nhận được
    Serial.print("X: ");
    Serial.print(receive_data.xAxis);
    Serial.print(" | Y: ");
    Serial.print(receive_data.yAxis);
    Serial.print(" | Z: ");
    Serial.print(receive_data.zAxis);
    
    // Hiển thị hướng chuyển động
    if(receive_data.yAxis > 390) {
      Serial.print(" | Action: FORWARD");
    } else if(receive_data.xAxis < 310) {
      Serial.print(" | Action: BACKWARD");
    } else if(receive_data.xAxis < 320) {
      Serial.print(" | Action: LEFT");
    } else if(receive_data.xAxis > 400) {
      Serial.print(" | Action: RIGHT");
    } else {
      Serial.print(" | Action: STOP");
    }
    Serial.println();
    
    // Điều khiển motor dựa trên dữ liệu nhận
    if(receive_data.yAxis > 390) {
      // Tiến lên - tốc độ tăng dần
      int speed = 100; // Tốc độ tối thiểu
      if(receive_data.yAxis >= 420) {
        speed = 255; // Tốc độ tối đa
      } else {
        // Tăng dần từ 100 đến 255 trong khoảng 390-420
        speed = map(receive_data.yAxis, 390, 420, 100, 255);
      }
      digitalWrite(MotorA1, LOW);
      digitalWrite(MotorA2, HIGH);
      digitalWrite(MotorB1, HIGH);
      digitalWrite(MotorB2, LOW);
      analogWrite(ENA, speed);
      analogWrite(ENB, speed);
      
    } else if(receive_data.xAxis < 310) {
      // Lùi xuống - tốc độ tăng dần
      int speed = 100; // Tốc độ tối thiểu
      if(receive_data.xAxis <= 335) {
        speed = 255; // Tốc độ tối đa
      } else {
        // Tăng dần từ 100 đến 255 trong khoảng 310-335 (ngược)
        speed = map(receive_data.xAxis, 310, 335, 255, 100);
      }
      digitalWrite(MotorA1, HIGH);
      digitalWrite(MotorA2, LOW);
      digitalWrite(MotorB1, LOW);
      digitalWrite(MotorB2, HIGH);
      analogWrite(ENA, speed);
      analogWrite(ENB, speed);
      
    } else if(receive_data.xAxis < 320) {
      // Sang trái
      digitalWrite(MotorA1, HIGH);
      digitalWrite(MotorA2, LOW);
      digitalWrite(MotorB1, HIGH);
      digitalWrite(MotorB2, LOW);
      analogWrite(ENA, 150);
      analogWrite(ENB, 150);
      
    } else if(receive_data.xAxis > 400) {
      // Sang phải
      digitalWrite(MotorA1, LOW);
      digitalWrite(MotorA2, HIGH);
      digitalWrite(MotorB1, LOW);
      digitalWrite(MotorB2, HIGH);
      analogWrite(ENA, 150);
      analogWrite(ENB, 150);
      
    } else {
      // Dừng
      digitalWrite(MotorA1, LOW);
      digitalWrite(MotorA2, LOW);
      digitalWrite(MotorB1, LOW);
      digitalWrite(MotorB2, LOW);
      analogWrite(ENA, 0);
      analogWrite(ENB, 0);
    }
    
    lastTime = millis();
  }
  
  // Kiểm tra mất kết nối - Dừng motor khi không có tín hiệu
  currentTime = millis();
  if(currentTime - lastTime > 2000 && lastTime > 0) {
    digitalWrite(MotorA1, LOW);
    digitalWrite(MotorA2, LOW);
    digitalWrite(MotorB1, LOW);
    digitalWrite(MotorB2, LOW);
    analogWrite(ENA, 0);
    analogWrite(ENB, 0);
  }
  
  delay(100);
}




/*
HARDWARE CONNECTION:
===================

Arduino Receiver (với RF24 và L298N Motor Driver):
- RF24: CE→D8, CSN→D10, VCC→3.3V, GND→GND
- L298N Motor Driver:
  - ENA → D3 (PWM)
  - ENB → D9 (PWM)
  - IN1 (MotorA1) → D4
  - IN2 (MotorA2) → D5
  - IN3 (MotorB1) → D6
  - IN4 (MotorB2) → D7
  - VCC → 5V, GND → GND

*/