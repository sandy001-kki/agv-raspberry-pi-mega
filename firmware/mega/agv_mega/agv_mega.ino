// AGV Arduino Mega Firmware
// Controls motors via L298N, reads IR array and MPU6050
// Communicates with Raspberry Pi via UART1 (Pin18/19)

#include <Wire.h>

#define IN1 5
#define IN2 6
#define IN3 7
#define IN4 8

int irPins[] = {22, 23, 24, 25, 26, 27, 28, 29};
#define MPU6050_ADDR 0x68

String inputBuffer = "";
unsigned long lastCommandTime = 0;
float yaw = 0.0, gyroZoffset = 0.0;
unsigned long lastGyroTime = 0;

void stopMotors() {
  digitalWrite(IN1,LOW);digitalWrite(IN2,LOW);
  digitalWrite(IN3,LOW);digitalWrite(IN4,LOW);
}
void forward()   { digitalWrite(IN1,HIGH);digitalWrite(IN2,LOW);digitalWrite(IN3,HIGH);digitalWrite(IN4,LOW); }
void backward()  { digitalWrite(IN1,LOW);digitalWrite(IN2,HIGH);digitalWrite(IN3,LOW);digitalWrite(IN4,HIGH); }
void turnLeft()  { digitalWrite(IN1,LOW);digitalWrite(IN2,HIGH);digitalWrite(IN3,HIGH);digitalWrite(IN4,LOW); }
void turnRight() { digitalWrite(IN1,HIGH);digitalWrite(IN2,LOW);digitalWrite(IN3,LOW);digitalWrite(IN4,HIGH); }

void initMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);Wire.write(0x6B);Wire.write(0x00);Wire.endTransmission(true);delay(100);
}
void calibrateGyro() {
  float sum=0;
  for(int i=0;i<200;i++){
    Wire.beginTransmission(MPU6050_ADDR);Wire.write(0x47);Wire.endTransmission(false);
    Wire.requestFrom(MPU6050_ADDR,2,true);
    int16_t gz=Wire.read()<<8|Wire.read();sum+=gz/131.0;delay(5);
  }
  gyroZoffset=sum/200;
}
void updateGyro() {
  unsigned long now=micros();float dt=(now-lastGyroTime)/1000000.0;lastGyroTime=now;
  if(dt>0.1)return;
  Wire.beginTransmission(MPU6050_ADDR);Wire.write(0x47);Wire.endTransmission(false);
  Wire.requestFrom(MPU6050_ADDR,2,true);
  int16_t gz=Wire.read()<<8|Wire.read();
  float g=gz/131.0-gyroZoffset;if(abs(g)>0.5)yaw+=g*dt;
  if(yaw>180)yaw-=360;if(yaw<-180)yaw+=360;
}
void sendSensorData() {
  String ir="";
  for(int i=0;i<8;i++){ir+=(digitalRead(irPins[i])==LOW)?"1":"0";if(i<7)ir+=",";}
  Serial1.print("{\"ir\":[");Serial1.print(ir);
  Serial1.print("],\"yaw\":");Serial1.print(yaw,1);Serial1.println("}");
}

void setup() {
  Serial.begin(115200);Serial1.begin(115200);
  pinMode(IN1,OUTPUT);digitalWrite(IN1,LOW);
  pinMode(IN2,OUTPUT);digitalWrite(IN2,LOW);
  pinMode(IN3,OUTPUT);digitalWrite(IN3,LOW);
  pinMode(IN4,OUTPUT);digitalWrite(IN4,LOW);
  for(int i=0;i<8;i++)pinMode(irPins[i],INPUT);
  Wire.begin();initMPU6050();calibrateGyro();
  Serial.println("AGV Mega Ready!");
  Serial1.println("{\"status\":\"ready\"}");
  lastCommandTime=millis();lastGyroTime=micros();
}

void loop() {
  while(Serial1.available()){
    char c=Serial1.read();
    if(c=='\n'){
      inputBuffer.trim();
      if(inputBuffer=="FORWARD")       {forward();   Serial1.println("{\"ack\":\"FORWARD\"}");}
      else if(inputBuffer=="BACKWARD") {backward();  Serial1.println("{\"ack\":\"BACKWARD\"}");}
      else if(inputBuffer=="LEFT")     {turnLeft();  Serial1.println("{\"ack\":\"LEFT\"}");}
      else if(inputBuffer=="RIGHT")    {turnRight(); Serial1.println("{\"ack\":\"RIGHT\"}");}
      else if(inputBuffer=="STOP")     {stopMotors();Serial1.println("{\"ack\":\"STOP\"}");}
      else if(inputBuffer=="PING")     {Serial1.println("{\"pong\":1}");}
      lastCommandTime=millis();inputBuffer="";
    } else if(c!='\r') inputBuffer+=c;
  }
  updateGyro();
  static unsigned long lastSend=0;
  if(millis()-lastSend>100){sendSensorData();lastSend=millis();}
  if(millis()-lastCommandTime>1000)stopMotors();
}
