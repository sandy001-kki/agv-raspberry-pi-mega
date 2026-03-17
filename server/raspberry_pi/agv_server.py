import asyncio
import websockets
import json
import threading
import time
import RPi.GPIO as GPIO

from motor_control import MotorController
from ir_sensor import IRSensor
from lidar_reader import LidarReader

WEBSOCKET_PORT = 8765
OBSTACLE_STOP_DIST = 400
LINE_BASE_SPEED = 55
KP = 12

class AGVServer:
    def __init__(self):
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        self.motors = MotorController()
        self.ir = IRSensor()
        self.lidar = LidarReader()
        self.mode = 'manual'
        self.running = True
        self.clients = set()
        self.last_cmd = time.time()
        self.loop = None
        self.lidar.start()
        threading.Thread(target=self._stream_loop, daemon=True).start()
        threading.Thread(target=self._safety_loop, daemon=True).start()
        print("AGV Server initialized!")

    def _safety_loop(self):
        while self.running:
            try:
                if self.mode == 'manual':
                    if time.time() - self.last_cmd > 1.0:
                        self.motors.stop()
            except:
                pass
            time.sleep(0.1)

    def _stream_loop(self):
        while self.running:
            if self.clients and self.loop:
                try:
                    msg = json.dumps({
                        'type': 'sensor_data',
                        'lidar': self.lidar.get_scan_json(),
                        'ir': self.ir.read_array(),
                        'obstacle_mm': self.lidar.get_obstacle_distance(),
                        'mode': self.mode
                    })
                    dead = set()
                    for ws in self.clients:
                        try:
                            asyncio.run_coroutine_threadsafe(ws.send(msg), self.loop)
                        except:
                            dead.add(ws)
                    self.clients -= dead
                except:
                    pass
            time.sleep(0.1)

    async def handle(self, ws):
        self.clients.add(ws)
        print(f"App connected: {ws.remote_address}")
        await ws.send(json.dumps({'type': 'connected', 'mode': self.mode}))
        try:
            async for msg in ws:
                await self._process(msg, ws)
        except:
            pass
        finally:
            self.clients.discard(ws)
            self.motors.stop()
            print("App disconnected")

    async def _process(self, message, ws):
        try:
            cmd = json.loads(message)
            action = cmd.get('action')
            self.last_cmd = time.time()
            if action == 'set_mode':
                self.mode = cmd.get('mode', 'manual')
                self.motors.stop()
                if self.mode == 'line_follow':
                    threading.Thread(target=self._line_loop, daemon=True).start()
                elif self.mode == 'obstacle_avoid':
                    threading.Thread(target=self._avoid_loop, daemon=True).start()
                await ws.send(json.dumps({'type': 'mode_changed', 'mode': self.mode}))
            elif action == 'move' and self.mode == 'manual':
                left = cmd.get('left', 0)
                right = cmd.get('right', 0)
                if left > 10 and right > 10:
                    self.motors.forward()
                elif left < -10 and right < -10:
                    self.motors.backward()
                elif left < -10 and right > 10:
                    self.motors.turn_right()
                elif left > 10 and right < -10:
                    self.motors.turn_left()
                else:
                    self.motors.stop()
            elif action == 'stop':
                self.motors.stop()
        except Exception as e:
            print(f"Error: {e}")

    def _line_loop(self):
        print("Line following started")
        while self.running and self.mode == 'line_follow':
            try:
                error = self.ir.get_position_error()
                if error is None:
                    self.motors.stop(); time.sleep(0.05); continue
                if self.lidar.get_obstacle_distance() < OBSTACLE_STOP_DIST:
                    self.motors.stop(); time.sleep(0.1); continue
                correction = KP * error
                self.motors.move(
                    max(-80, min(80, LINE_BASE_SPEED + correction)),
                    max(-80, min(80, LINE_BASE_SPEED - correction)))
            except:
                pass
            time.sleep(0.02)
        self.motors.stop()

    def _avoid_loop(self):
        print("Obstacle avoidance started")
        while self.running and self.mode == 'obstacle_avoid':
            try:
                dist = self.lidar.get_obstacle_distance()
                if dist > 600:
                    self.motors.forward(60)
                elif dist > OBSTACLE_STOP_DIST:
                    self.motors.forward(30)
                else:
                    self.motors.turn_right(50)
                    time.sleep(0.4)
            except:
                pass
            time.sleep(0.05)
        self.motors.stop()

    async def main(self):
        self.loop = asyncio.get_event_loop()
        print(f"Starting WebSocket on port {WEBSOCKET_PORT}...")
        async with websockets.serve(self.handle, '0.0.0.0', WEBSOCKET_PORT):
            print("AGV ready!")
            await asyncio.Future()

    def shutdown(self):
        self.running = False
        self.motors.cleanup()
        self.lidar.stop()

if __name__ == '__main__':
    server = AGVServer()
    try:
        asyncio.run(server.main())
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()
