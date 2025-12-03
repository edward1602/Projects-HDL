#define PIN_IRQ   2
#define PIN_CE    3
#define PIN_CSN   4
#define PIN_MOSI  5
#define PIN_MISO  6
#define PIN_SCK   7

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  pinMode(2, INPUT); // A0
  pinMode(3, INPUT); // A1
  pinMode(4, INPUT); // A2
  pinMode(5, INPUT); // A3
  pinMode(6, INPUT); // A4
  pinMode(7, INPUT); // A5
  Serial.println("PAYLOAD_READY, CE, CSN, MOSI, MISO, SCK");
}

void loop() {
  // put your main code here, to run repeatedly:
  int sig1 = digitalRead(2); // payload_ready
  int sig2 = digitalRead(3); // irq
  int sig3 = digitalRead(4); // csn
  int sig4 = digitalRead(5); // mosi
  int sig5 = digitalRead(6); // miso
  int sig6 = digitalRead(7); // sck

  Serial.print(sig1); Serial.print(", ");
  Serial.print(sig2); Serial.print(", ");
  Serial.print(sig3); Serial.print(", ");
  Serial.print(sig4); Serial.print(", ");
  Serial.print(sig5); Serial.print(", ");
  Serial.print(sig6); Serial.println();

  // delay(10);
}
