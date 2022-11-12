import serial.tools.list_ports

port = serial.tools.list_ports.comports()
ser = serial.Serial()

portList = []

for oneport in port:
    portList.append(str(oneport))
    print(str(oneport))

val = input("select Port: COM")

for x in range(0,len(portList)):
    if portList[x].startswith("COM" + str(val)):
        portVar = "COM" + str(val)

ser.baudate = 9600
ser.port = portVar
ser.open()

while True:
    if ser.in_waiting:
        data = ser.read(1)
        print(data)
        if data == b'\x00':
            print(f"FAIL")
        if data == b'\x01':
            print(f"TRUE")
