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
int spd = 200;
void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);

  // Set speed for motors
  motor1.setSpeed(0);
  motor2.setSpeed(0);
  motor3.setSpeed(0);
  motor4.setSpeed(0);

  Serial.println("Start...");
}

void loop() {
  // Read input
  if (Serial.available()) {
    cmd = Serial.read();
    Serial.println(cmd);
  }

  // Process input
  switch (cmd) {
    case 'W':
      Serial.println("Go forward");
      goForward(255);
      break;
    case 'S':
      Serial.println("Go backward");
      goBackward(255);
      break;
    case 'D':
      Serial.println("Go right");
      goRight(255);
      break;
    case 'A':
      Serial.println("Go left");
      goLeft(255);
      break;
    case 'R':
      Serial.println("Turn right");
      rotateRight(255);
      break;
    case 'L':
      Serial.println("Turn left");
      rotateLeft(255);
      break;
    case 'X':
      Serial.println("Stop");
      stop();
    default: break;
  }
  delay(500);
}

void goForward(int _spd) {
  motor1.run(FORWARD);
  motor2.run(FORWARD);
  motor3.run(FORWARD);
  motor4.run(FORWARD); 
  delay(10);
}

void goBackward(int _spd) {
  motor1.run(BACKWARD);
  motor2.run(BACKWARD); 
  motor3.run(BACKWARD);
  motor4.run(BACKWARD); 
  delay(10);
}

void goRight(int _spd) {
  motor1.run(FORWARD);
  motor2.run(BACKWARD);
  motor3.run(BACKWARD);
  motor4.run(FORWARD);

  if (spd < _spd) {
    motor1.setSpeed(++spd);
    motor2.setSpeed(++spd);
    motor3.setSpeed(++spd);
    motor4.setSpeed(++spd);
  } else {
    motor1.setSpeed(spd);
    motor2.setSpeed(spd);
    motor3.setSpeed(spd);
    motor4.setSpeed(spd);
  }
  delay(10);
}

void goLeft(int _spd) {
  motor1.run(BACKWARD);
  motor2.run(FORWARD);
  motor3.run(FORWARD);
  motor4.run(BACKWARD);

  if (spd < _spd) {
    motor1.setSpeed(++spd);
    motor2.setSpeed(++spd);
    motor3.setSpeed(++spd);
    motor4.setSpeed(++spd);
  } else {
    motor1.setSpeed(spd);
    motor2.setSpeed(spd);
    motor3.setSpeed(spd);
    motor4.setSpeed(spd);
  }
  delay(10);
}

void rotateLeft(int _spd) {
  motor1.run(BACKWARD);
  motor2.run(FORWARD);
  motor3.run(BACKWARD);
  motor4.run(FORWARD);
  
  if (spd < _spd) {
    motor1.setSpeed(++spd);
    motor2.setSpeed(++spd);
    motor3.setSpeed(++spd);
    motor4.setSpeed(++spd);
  } else {
    motor1.setSpeed(spd);
    motor2.setSpeed(spd);
    motor3.setSpeed(spd);
    motor4.setSpeed(spd);
  }
  delay(10);
}

void rotateRight(int _spd) {
  motor1.run(FORWARD);
  motor2.run(BACKWARD);
  motor3.run(FORWARD);
  motor4.run(BACKWARD);

  if (spd < _spd) {
    motor1.setSpeed(++spd);
    motor2.setSpeed(++spd);
    motor3.setSpeed(++spd);
    motor4.setSpeed(++spd);
  } else {
    motor1.setSpeed(spd);
    motor2.setSpeed(spd);
    motor3.setSpeed(spd);
    motor4.setSpeed(spd);
  }
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
