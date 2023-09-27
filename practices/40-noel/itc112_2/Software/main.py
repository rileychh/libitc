#!/usr/bin/env python

import sys

import serial
import serial.tools.list_ports
from PyQt5 import QtWidgets
from PyQt5.QtWidgets import QMainWindow
from ui import Ui_MainWindow


class Main(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.value = ""

        for n in range(10):
            getattr(self, f"pushButton_{n}").clicked.connect(
                lambda checked, x=n: self.onNumberClick(x)
            )

        for c in ["send", "clear", "back"]:
            getattr(self, f"pushButton_{c}").clicked.connect(
                lambda checked, x=c: self.onButtonClick(x)
            )

    def onNumberClick(self, num: int):
        print(f"Clicked {num}")
        self.value += str(num)
        self.label_inputnumber.setText("輸入數字")
        self.label_output.setText(self.value)

    def onButtonClick(self, cmd: str):
        if cmd == "clear":
            self.value = ""
            self.label_output.setText(self.value)
            self.label_inputnumber.setText("輸入數字")

        if cmd == "send" and self.value != "":
            self.value += "\r"
            ser.write(self.value.encode(encoding="utf-8"))
            print((self.value.encode(encoding="utf-8")))
            self.value = ""
            self.label_output.setText(self.value)
        if cmd == "back":
            self.value = self.value[:-1]
            self.label_inputnumber.setText("輸入數字")
            self.label_output.setText(self.value)
        print(f"Clicked {cmd}")


port = list(serial.tools.list_ports.comports())


ser = serial.Serial()

ser.baudrate = 9600
ser.port = "COM5"
ser.open()

app = QtWidgets.QApplication(sys.argv)
window = Main()
window.show()
sys.exit(app.exec())
