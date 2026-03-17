import RPi.GPIO as GPIO
import time

# L298N pins
IN1 = 17
IN2 = 27
PWMA = 18
BIN1 = 22
BIN2 = 23
PWMB = 24
STBY = 25

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

class MotorController:
    def __init__(self):
        for p in [IN1, IN2, PWMA, BIN1, BIN2, PWMB, STBY]:
            GPIO.setup(p, GPIO.OUT)
            GPIO.output(p, GPIO.LOW)
        GPIO.output(STBY, GPIO.HIGH)
        self.pwm_a = GPIO.PWM(PWMA, 1000)
        self.pwm_b = GPIO.PWM(PWMB, 1000)
        self.pwm_a.start(0)
        self.pwm_b.start(0)
        print("Motors ready")

    def set_motor_a(self, speed):
        speed = max(-100, min(100, speed))
        if speed > 0:
            GPIO.output(IN1, GPIO.HIGH); GPIO.output(IN2, GPIO.LOW)
        elif speed < 0:
            GPIO.output(IN1, GPIO.LOW); GPIO.output(IN2, GPIO.HIGH)
        else:
            GPIO.output(IN1, GPIO.LOW); GPIO.output(IN2, GPIO.LOW)
        self.pwm_a.ChangeDutyCycle(abs(speed))

    def set_motor_b(self, speed):
        speed = max(-100, min(100, speed))
        if speed > 0:
            GPIO.output(BIN1, GPIO.HIGH); GPIO.output(BIN2, GPIO.LOW)
        elif speed < 0:
            GPIO.output(BIN1, GPIO.LOW); GPIO.output(BIN2, GPIO.HIGH)
        else:
            GPIO.output(BIN1, GPIO.LOW); GPIO.output(BIN2, GPIO.LOW)
        self.pwm_b.ChangeDutyCycle(abs(speed))

    def forward(self, speed=70):
        self.set_motor_a(speed); self.set_motor_b(speed)

    def backward(self, speed=70):
        self.set_motor_a(-speed); self.set_motor_b(-speed)

    def turn_left(self, speed=60):
        self.set_motor_a(-speed); self.set_motor_b(speed)

    def turn_right(self, speed=60):
        self.set_motor_a(speed); self.set_motor_b(-speed)

    def stop(self):
        self.set_motor_a(0); self.set_motor_b(0)

    def move(self, left, right):
        self.set_motor_a(left); self.set_motor_b(right)

    def cleanup(self):
        self.stop()
        self.pwm_a.stop(); self.pwm_b.stop()
        GPIO.cleanup()
        print("Motors stopped")
