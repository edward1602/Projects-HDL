// Test Transmitter Output - Kiểm tra giá trị cảm biến ADXL335
// Hiển thị giá trị X, Y trước khi gửi qua RF24

const int x_out = A0;  // Chân đọc trục X của ADXL335
const int y_out = A1;  // Chân đọc trục Y của ADXL335
const int z_out = A2;  // Chân đọc trục Z của ADXL335

// Cấu trúc dữ liệu giống như trong GestureTransmitterCode
struct data {
  int xAxis;
  int yAxis;
  int zAxis;  // Thêm trục Z
};
data send_data;

// Biến để theo dõi thời gian
unsigned long lastTime = 0;
unsigned long currentTime = 0;

void setup() {
  // Khởi tạo Serial với tốc độ cao
  Serial.begin(115200);
  
  Serial.println("=== TEST TRANSMITTER OUTPUT ===");
  Serial.println("Kiem tra gia tri cam bien ADXL335");
  Serial.println("Nghieng tay dieu khien de xem gia tri thay doi");
  Serial.println("Mo Serial Plotter de xem do thi: Tools > Serial Plotter");
  Serial.println("====================================");
  delay(2000);
  
  // Header cho Serial Plotter
  Serial.println("xAxis,yAxis,zAxis");
}

void loop() {
  currentTime = millis();
  
  // Đọc giá trị từ cảm biến ADXL335 (giống như transmitter)
  send_data.xAxis = analogRead(x_out);
  send_data.yAxis = analogRead(y_out);
  send_data.zAxis = analogRead(z_out);  // Đọc trục Z
  
  // Hiển thị chi tiết trên Serial Monitor
  Serial.print("Time: ");
  Serial.print(currentTime);
  Serial.print(" ms | X: ");
  Serial.print(send_data.xAxis);
  Serial.print(" | Y: ");
  Serial.print(send_data.yAxis);
  Serial.print(" | Z: ");
  Serial.print(send_data.zAxis);
  
  // Phân tích hướng di chuyển dựa trên logic của receiver
  Serial.print(" | Direction: ");
  if(send_data.yAxis > 400) {
    Serial.print("FORWARD");
  } else if(send_data.yAxis < 320) {
    Serial.print("BACKWARD");
  } else if(send_data.xAxis < 320) {
    Serial.print("LEFT");
  } else if(send_data.xAxis > 400) {
    Serial.print("RIGHT");
  } else {
    Serial.print("STOP");
  }
  
  Serial.println();
  
  // Dữ liệu cho Serial Plotter (định dạng CSV)
  Serial.print(send_data.xAxis);
  Serial.print(",");
  Serial.print(send_data.yAxis);
  Serial.print(",");
  Serial.println(send_data.zAxis);
  
  // Cập nhật với tần số 20Hz
  delay(50);
}