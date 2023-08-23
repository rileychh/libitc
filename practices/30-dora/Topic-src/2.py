import serial
import serial.tools.list_ports

ports  = serial.tools.list_ports.comports()
ser = serial.Serial()

ser.baudrate = 9600
ser.port="COM11"
ser.open()

while True: 
    if ser.in_waiting:
        data = ser.read()
        print(data.decode('utf').rstrip('\n'))