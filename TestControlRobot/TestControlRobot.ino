#include <AFMotor_R4.h>

AF_DCMotor motor1(4);
AF_DCMotor motor2(3);
AF_DCMotor motor3(1);
AF_DCMotor motor4(2);

// Map of motor connections
// 1 --- 2
// |     |
// 3 --- 4

char cmd = 0;
void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  delay(1000);

  // Set speed for motors
  motor1.setSpeed(0);
  motor2.setSpeed(0);
  motor3.setSpeed(0);
  motor4.setSpeed(0);

  // Silent startup - ready for UART communication
}

void loop() {
  // Read input
  if (Serial.available()) {
    cmd = Serial.read();
  }

  // Process input
  switch (cmd) {
    case 'W':
      goForward(255);
      break;
    case 'S':
      goBackward(255);
      break;
    case 'D':
      goRight(255);
      break;
    case 'A':
      goLeft(255);
      break;
    case 'R':
      rotateRight(255);
      break;
    case 'L':
      rotateLeft(255);
      break;
    case 'X':
      stop();
      break;
    default: 
      // Silent ignore unknown commands
      break;
  }
  delay(500);
}

void goForward(int _spd) {
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  motor1.run(FORWARD);
  motor2.run(FORWARD);
  motor3.run(FORWARD);
  motor4.run(FORWARD); 
  delay(10);
}

void goBackward(int _spd) {
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  motor1.run(BACKWARD);
  motor2.run(BACKWARD); 
  motor3.run(BACKWARD);
  motor4.run(BACKWARD); 
  delay(10);
}

void goRight(int _spd) {
  // Set speed TRƯỚC
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  // Sau đó set direction
  motor1.run(FORWARD);
  motor2.run(BACKWARD);
  motor3.run(BACKWARD);
  motor4.run(FORWARD);
  delay(10);
}

void goLeft(int _spd) {
  // Set speed TRƯỚC
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  // Sau đó set direction
  motor1.run(BACKWARD);
  motor2.run(FORWARD);
  motor3.run(FORWARD);
  motor4.run(BACKWARD);
  delay(10);
}

void rotateLeft(int _spd) {
  // Set speed TRƯỚC
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  // Sau đó set direction
  motor1.run(BACKWARD);
  motor2.run(FORWARD);
  motor3.run(BACKWARD);
  motor4.run(FORWARD);
  delay(10);
}

void rotateRight(int _spd) {
  // Set speed TRƯỚC
  motor1.setSpeed(_spd);
  motor2.setSpeed(_spd);
  motor3.setSpeed(_spd);
  motor4.setSpeed(_spd);
  
  // Sau đó set direction
  motor1.run(FORWARD);
  motor2.run(BACKWARD);
  motor3.run(FORWARD);
  motor4.run(BACKWARD);
  delay(10);
}

void stop() {
  motor1.run(RELEASE);
  motor2.run(RELEASE);
  motor3.run(RELEASE);
  motor4.run(RELEASE);

  motor1.setSpeed(0);
  motor2.setSpeed(0);
  motor3.setSpeed(0);
  motor4.setSpeed(0);
}
