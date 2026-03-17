# Complete Wiring Diagram — Pi + Mega

## Power Chain

```
12V VRLA Battery (7.2Ah)
        |
    20A Fuse
        |
        ├──> XL4015 VIN+ ──> VOUT+ 5.1V ──> 5V rail
        |                              ──> Pi Pin 2 & 4
        |                              ──> Mega VIN
        |
        └──> L298N 12V terminal

Battery (−) ──> GND rail
XL4015 VOUT− ──> GND rail
Pi Pin 6 ──> GND rail
Mega GND ──> GND rail
L298N GND ──> GND rail
```

## Pi → Arduino Mega UART

```
Pi GPIO14 (TXD) Pin 8  ──> Mega RX1 Pin 19
Pi GPIO15 (RXD) Pin 10 ──> Mega TX1 Pin 18
Pi GND Pin 6           ──> Mega GND
```

## Arduino Mega → L298N

```
Mega Pin 5 ──> IN1    L298N VCC ──> 5V rail
Mega Pin 6 ──> IN2    L298N GND ──> GND rail
Mega Pin 7 ──> IN3    L298N 12V ──> 12V from fuse
Mega Pin 8 ──> IN4    ENA jumper ON
                      ENB jumper ON
L298N OUT1+OUT2 ──> Motor A (Left)
L298N OUT3+OUT4 ──> Motor B (Right)
```

## IR Array → Pi GPIO

```
IR VCC pin 1 & 2 ──> 5V rail
IR GND pin 1 & 2 ──> GND rail
IR D1 ──> Pi GPIO5  (Pin 29)
IR D2 ──> Pi GPIO6  (Pin 31)
IR D3 ──> Pi GPIO12 (Pin 32)
IR D4 ──> Pi GPIO13 (Pin 33)
IR D5 ──> Pi GPIO16 (Pin 36)
IR D6 ──> Pi GPIO19 (Pin 35)
IR D7 ──> Pi GPIO20 (Pin 38)
IR D8 ──> Pi GPIO21 (Pin 40)
```

## MPU6050 → Arduino Mega

```
MPU6050 VCC ──> 5V rail
MPU6050 GND ──> GND rail
MPU6050 SDA ──> Mega Pin 20
MPU6050 SCL ──> Mega Pin 21
```

## LiDAR → Pi USB

```
LiDAR Data USB  ──> Pi USB Port 1 (/dev/ttyUSB0)
LiDAR Power USB ──> Pi USB Port 2
```

## Safety Notes

1. ONLY use 5V 2A charger for Pi — NEVER 9V or fast charger
2. Set XL4015 to exactly 5.1V before connecting Pi
3. Always use 20A fuse
4. All GNDs must be on same common rail
