import serial
import threading
import time

class LidarReader:
    def __init__(self, port='/dev/ttyUSB0', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.running = False
        self.scan_data = {}
        self.lock = threading.Lock()
        self.obstacle_distance = 9999

    def start(self):
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=1)
            self.running = True
            threading.Thread(target=self._read_loop, daemon=True).start()
            print(f"LiDAR started on {self.port}")
            return True
        except Exception as e:
            print(f"LiDAR failed: {e}")
            return False

    def _read_loop(self):
        buf = bytearray()
        while self.running:
            try:
                data = self.ser.read(self.ser.in_waiting or 1)
                if not data:
                    continue
                buf.extend(data)
                while len(buf) >= 10:
                    idx = -1
                    for i in range(len(buf) - 1):
                        if buf[i] == 0xAA and buf[i+1] == 0x55:
                            idx = i; break
                    if idx == -1:
                        buf = buf[-1:]; break
                    if idx > 0:
                        buf = buf[idx:]
                    if len(buf) < 10:
                        break
                    ls = buf[3]
                    packet_size = 10 + ls * 2
                    if len(buf) < packet_size:
                        break
                    fsa = (buf[4] | (buf[5] << 8))
                    lsa = (buf[6] | (buf[7] << 8))
                    start_angle = (fsa >> 1) / 64.0
                    end_angle = (lsa >> 1) / 64.0
                    if end_angle < start_angle:
                        end_angle += 360.0
                    scan = {}
                    for i in range(ls):
                        dist = (buf[10+i*2] | (buf[10+i*2+1] << 8)) / 4.0
                        angle = start_angle + (end_angle - start_angle) * i / max(ls-1, 1)
                        angle = angle % 360
                        if dist > 0:
                            scan[round(angle, 1)] = round(dist)
                    with self.lock:
                        self.scan_data.update(scan)
                        if len(self.scan_data) > 720:
                            self.scan_data = dict(list(self.scan_data.items())[-720:])
                        self._update_obstacle()
                    buf = buf[packet_size:]
            except:
                time.sleep(0.01)

    def _update_obstacle(self):
        front = [(d, a) for a, d in self.scan_data.items()
                 if d > 0 and (a <= 45 or a >= 315)]
        self.obstacle_distance = min(front, key=lambda x: x[0])[0] if front else 9999

    def get_scan_json(self):
        with self.lock:
            return [[a, d] for a, d in self.scan_data.items()]

    def get_obstacle_distance(self):
        with self.lock:
            return self.obstacle_distance

    def stop(self):
        self.running = False
        if self.ser:
            self.ser.close()
