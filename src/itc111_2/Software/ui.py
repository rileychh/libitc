# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui.ui'
#
# Created by: PyQt5 UI code generator 5.15.4
#
# WARNING: Any manual changes made to this file will be lost when pyuic5 is
# run again.  Do not edit this file unless you know what you are doing.


from PyQt5 import QtCore, QtGui, QtWidgets


class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.resize(669, 367)
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(10)
        MainWindow.setFont(font)
        self.centralwidget = QtWidgets.QWidget(MainWindow)
        self.centralwidget.setObjectName("centralwidget")
        self.pushButton_1 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_1.setGeometry(QtCore.QRect(330, 180, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_1.setFont(font)
        self.pushButton_1.setObjectName("pushButton_1")
        self.pushButton_2 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_2.setGeometry(QtCore.QRect(390, 180, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_2.setFont(font)
        self.pushButton_2.setObjectName("pushButton_2")
        self.pushButton_3 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_3.setGeometry(QtCore.QRect(450, 180, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_3.setFont(font)
        self.pushButton_3.setObjectName("pushButton_3")
        self.pushButton_4 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_4.setGeometry(QtCore.QRect(330, 120, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_4.setFont(font)
        self.pushButton_4.setObjectName("pushButton_4")
        self.pushButton_5 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_5.setGeometry(QtCore.QRect(390, 120, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_5.setFont(font)
        self.pushButton_5.setObjectName("pushButton_5")
        self.pushButton_6 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_6.setGeometry(QtCore.QRect(450, 120, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(14)
        self.pushButton_6.setFont(font)
        self.pushButton_6.setObjectName("pushButton_6")
        self.pushButton_7 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_7.setGeometry(QtCore.QRect(330, 60, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(14)
        font.setBold(False)
        font.setWeight(50)
        self.pushButton_7.setFont(font)
        self.pushButton_7.setObjectName("pushButton_7")
        self.pushButton_8 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_8.setGeometry(QtCore.QRect(390, 60, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(14)
        self.pushButton_8.setFont(font)
        self.pushButton_8.setObjectName("pushButton_8")
        self.pushButton_9 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_9.setGeometry(QtCore.QRect(450, 60, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(14)
        self.pushButton_9.setFont(font)
        self.pushButton_9.setObjectName("pushButton_9")
        self.pushButton_0 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_0.setGeometry(QtCore.QRect(390, 240, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_0.setFont(font)
        self.pushButton_0.setObjectName("pushButton_0")
        self.pushButton_clear = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_clear.setGeometry(QtCore.QRect(520, 60, 101, 51))
        font = QtGui.QFont()
        font.setPointSize(20)
        self.pushButton_clear.setFont(font)
        self.pushButton_clear.setObjectName("pushButton_clear")
        self.pushButton_back = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_back.setGeometry(QtCore.QRect(520, 120, 101, 51))
        font = QtGui.QFont()
        font.setPointSize(20)
        self.pushButton_back.setFont(font)
        self.pushButton_back.setObjectName("pushButton_back")
        self.pushButton_send = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_send.setGeometry(QtCore.QRect(520, 180, 101, 51))
        font = QtGui.QFont()
        font.setPointSize(20)
        self.pushButton_send.setFont(font)
        self.pushButton_send.setObjectName("pushButton_send")
        self.frame = QtWidgets.QFrame(self.centralwidget)
        self.frame.setGeometry(QtCore.QRect(80, 80, 211, 151))
        self.frame.setStyleSheet("background-color: rgb(0, 255, 255);")
        self.frame.setFrameShape(QtWidgets.QFrame.StyledPanel)
        self.frame.setFrameShadow(QtWidgets.QFrame.Raised)
        self.frame.setObjectName("frame")
        self.label_output = QtWidgets.QLabel(self.frame)
        self.label_output.setGeometry(QtCore.QRect(20, 70, 161, 31))
        font = QtGui.QFont()
        font.setPointSize(15)
        font.setBold(True)
        font.setWeight(75)
        self.label_output.setFont(font)
        self.label_output.setStyleSheet("background-color: rgb(170, 255, 255);\n"
"")
        self.label_output.setText("")
        self.label_output.setObjectName("label_output")
        self.label_inputnumber = QtWidgets.QLabel(self.frame)
        self.label_inputnumber.setGeometry(QtCore.QRect(20, 10, 121, 51))
        font = QtGui.QFont()
        font.setPointSize(20)
        font.setBold(True)
        font.setWeight(75)
        self.label_inputnumber.setFont(font)
        self.label_inputnumber.setText("")
        self.label_inputnumber.setObjectName("label_inputnumber")
        self.label_2 = QtWidgets.QLabel(self.frame)
        self.label_2.setGeometry(QtCore.QRect(0, 0, 211, 151))
        self.label_2.setStyleSheet("border: 2px solid black;\n"
"\n"
"\n"
"")
        self.label_2.setText("")
        self.label_2.setObjectName("label_2")
        self.label_2.raise_()
        self.label_output.raise_()
        self.label_inputnumber.raise_()
        self.label_0 = QtWidgets.QLabel(self.centralwidget)
        self.label_0.setGeometry(QtCore.QRect(20, 20, 631, 301))
        font = QtGui.QFont()
        font.setPointSize(20)
        font.setBold(True)
        font.setWeight(75)
        self.label_0.setFont(font)
        self.label_0.setStyleSheet("background-color: rgb(255, 255, 255);")
        self.label_0.setText("")
        self.label_0.setObjectName("label_0")
        self.label_3 = QtWidgets.QLabel(self.centralwidget)
        self.label_3.setGeometry(QtCore.QRect(320, 50, 311, 251))
        self.label_3.setStyleSheet("border: 2px solid black;\n"
"\n"
"\n"
"")
        self.label_3.setText("")
        self.label_3.setObjectName("label_3")
        self.pushButton_null_1 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_null_1.setGeometry(QtCore.QRect(330, 240, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_null_1.setFont(font)
        self.pushButton_null_1.setText("")
        self.pushButton_null_1.setObjectName("pushButton_null_1")
        self.pushButton_null_2 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_null_2.setGeometry(QtCore.QRect(450, 240, 51, 51))
        font = QtGui.QFont()
        font.setPointSize(14)
        self.pushButton_null_2.setFont(font)
        self.pushButton_null_2.setText("")
        self.pushButton_null_2.setObjectName("pushButton_null_2")
        self.pushButton_null_3 = QtWidgets.QPushButton(self.centralwidget)
        self.pushButton_null_3.setGeometry(QtCore.QRect(520, 240, 101, 51))
        font = QtGui.QFont()
        font.setPointSize(20)
        self.pushButton_null_3.setFont(font)
        self.pushButton_null_3.setText("")
        self.pushButton_null_3.setObjectName("pushButton_null_3")
        self.label_0.raise_()
        self.label_3.raise_()
        self.frame.raise_()
        self.pushButton_1.raise_()
        self.pushButton_2.raise_()
        self.pushButton_3.raise_()
        self.pushButton_4.raise_()
        self.pushButton_5.raise_()
        self.pushButton_6.raise_()
        self.pushButton_7.raise_()
        self.pushButton_8.raise_()
        self.pushButton_9.raise_()
        self.pushButton_0.raise_()
        self.pushButton_clear.raise_()
        self.pushButton_back.raise_()
        self.pushButton_send.raise_()
        self.pushButton_null_1.raise_()
        self.pushButton_null_2.raise_()
        self.pushButton_null_3.raise_()
        MainWindow.setCentralWidget(self.centralwidget)
        self.menubar = QtWidgets.QMenuBar(MainWindow)
        self.menubar.setGeometry(QtCore.QRect(0, 0, 669, 21))
        self.menubar.setObjectName("menubar")
        MainWindow.setMenuBar(self.menubar)
        self.statusbar = QtWidgets.QStatusBar(MainWindow)
        self.statusbar.setObjectName("statusbar")
        MainWindow.setStatusBar(self.statusbar)

        self.retranslateUi(MainWindow)
        QtCore.QMetaObject.connectSlotsByName(MainWindow)

    def retranslateUi(self, MainWindow):
        _translate = QtCore.QCoreApplication.translate
        MainWindow.setWindowTitle(_translate("MainWindow", "MainWindow"))
        self.pushButton_1.setText(_translate("MainWindow", "1"))
        self.pushButton_2.setText(_translate("MainWindow", "2"))
        self.pushButton_3.setText(_translate("MainWindow", "3"))
        self.pushButton_4.setText(_translate("MainWindow", "4"))
        self.pushButton_5.setText(_translate("MainWindow", "5"))
        self.pushButton_6.setText(_translate("MainWindow", "6"))
        self.pushButton_7.setText(_translate("MainWindow", "7"))
        self.pushButton_8.setText(_translate("MainWindow", "8"))
        self.pushButton_9.setText(_translate("MainWindow", "9"))
        self.pushButton_0.setText(_translate("MainWindow", "0"))
        self.pushButton_clear.setText(_translate("MainWindow", "清除"))
        self.pushButton_back.setText(_translate("MainWindow", "返回"))
        self.pushButton_send.setText(_translate("MainWindow", "送出"))


if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    MainWindow = QtWidgets.QMainWindow()
    ui = Ui_MainWindow()
    ui.setupUi(MainWindow)
    MainWindow.show()
    sys.exit(app.exec_())
