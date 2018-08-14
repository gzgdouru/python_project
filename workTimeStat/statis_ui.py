import sys

from datetime import datetime, time as dtime
from enum import Enum
from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import QWidget, QGridLayout, QApplication, \
    QLineEdit, QPushButton, QMessageBox, QTextEdit, QMainWindow
import threading, time

from timeStatis import TimeStatis

customMsgBox = None

class TimerType(Enum):
    work = 1
    relax = 2

class StatWindow(QWidget):
    def __init__(self, timeStatis):
        try:
            super(StatWindow, self).__init__()
            self.timerType = None
            self.timeStart = datetime.now()
            self.timeStatis = timeStatis

            self.lastPopup = dtime(hour=0, minute=0, second=0) #上次弹窗时间

            self.timer = QTimer(self)
            self.timer.start(500)
            self.timer.timeout.connect(self.timeout_slot)

            self.initUI()
            self.init_popup_thread()
        except Exception as e:
            QMessageBox.critical(None, "critical", "window init failed, error:{}".format(str(e)))

    def init_popup_thread(self):
        if self.timeStatis.isPopup == 0: return
        thread = threading.Thread(target=self.popup_check, args=())
        thread.setDaemon(True)
        thread.start()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        self.workTimeLe = QLineEdit("00:00:00")
        self.workTimeLe.setFocusPolicy(Qt.NoFocus)
        grid.addWidget( self.workTimeLe, row, 0)
        workTimeBt = QPushButton("work")
        workTimeBt.clicked.connect(lambda :self.set_timer_type(TimerType.work))
        grid.addWidget(workTimeBt, row, 1)
        row += 1

        self.relaxTimeLe = QLineEdit("00:00:00")
        self.relaxTimeLe.setFocusPolicy(Qt.NoFocus)
        grid.addWidget( self.relaxTimeLe, row, 0)
        relaxTimeBt = QPushButton("relax")
        relaxTimeBt.clicked.connect(lambda :self.set_timer_type(TimerType.relax))
        grid.addWidget(relaxTimeBt, row, 1)

        self.setLayout(grid)
        self.setWindowTitle('WorkTimeStatis')
        self.move(700, 250)
        self.show()

    def set_timer_type(self, timeType):
        if self.timerType == timeType: return

        if self.timerType == TimerType.work and timeType == TimerType.relax:
            thread = threading.Thread(target=self.save_work_time, args=(self.timeStart,))
            thread.setDaemon(True)
            thread.start()

        self.timerType = timeType
        self.reset_timer()

    def timeout_slot(self):
        timeDiff = self.timeStatis.getDiffTime(self.timeStart)
        timeStr = "{0:02d}:{1:02d}:{2:02d}".format(timeDiff.hour, timeDiff.minute, timeDiff.second)
        if self.timerType == TimerType.work:
            self.workTimeLe.setText(timeStr)
        elif self.timerType == TimerType.relax:
            self.relaxTimeLe.setText(timeStr)

        #检查弹窗
        if self.timeStatis.isPopup > 0 and self.timerType == TimerType.work:
            self.popup_check()

    def save_work_time(self, timeStart):
        timeDiff = self.timeStatis.getDiffTime(timeStart)
        self.timeStatis.save_work_time(timeStart, timeDiff)

    def popup_check(self):
        timeDiff = self.timeStatis.getDiffTime(self.timeStart)
        if timeDiff.hour - self.lastPopup.hour >= self.timeStatis.popupTime:
            timeStr = "{0:02d}:{1:02d}:{2:02d}".format(timeDiff.hour, timeDiff.minute, timeDiff.second)
            self.lastPopup = timeDiff
            text = "大兄弟, 已经连续工作[{}]时间了, 是不是应该歇一会了?".format(timeStr)
            QMessageBox.information(None, "info", text)

    def reset_timer(self):
        self.timeStart = datetime.now()
        self.lastPopup = dtime(hour=0, minute=0, second=0)

    def closeEvent(self, QCloseEvent):
        if self.timerType == TimerType.work:
            self.save_work_time(self.timeStart)
        QCloseEvent.accept()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    timeStatis = TimeStatis()
    ex = StatWindow(timeStatis)
    sys.exit(app.exec_())