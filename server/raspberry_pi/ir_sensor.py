import RPi.GPIO as GPIO

IR_PINS = [5, 6, 12, 13, 16, 19, 20, 21]

class IRSensor:
    def __init__(self):
        for pin in IR_PINS:
            GPIO.setup(pin, GPIO.IN)
        print("IR sensors ready")

    def read_array(self):
        return [1 if GPIO.input(pin) == GPIO.LOW else 0 for pin in IR_PINS]

    def get_position_error(self):
        sensors = self.read_array()
        weights = [-3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5]
        active = sum(sensors)
        if active == 0:
            return None
        return sum(w * s for w, s in zip(weights, sensors)) / active

    def none_on_line(self):
        return all(v == 0 for v in self.read_array())
