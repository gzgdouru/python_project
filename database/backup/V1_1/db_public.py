from PyQt5.QtWidgets import QApplication, QWidget, QTextEdit, QGridLayout
from PyQt5.QtCore import Qt, pyqtSignal, QThread, QObject
from PyQt5.QtGui import QTextCursor
import sys
import time
from enum import Enum

class MsgType(Enum):
    info = "INFO"
    waring = "WARING"
    error = "ERROR"

class RemoteServer:
    def __init__(self, host, port, username, passwd, home="~"):
        self.host = host
        self.port = port
        self.username = username
        self.passwd = passwd
        self.home = home

    def __str__(self):
        info = "host:%s\nport:%d\nusername:%s\npasswd:%s\nhome:%s" % (self.host, self.port, self.username, self.passwd, self.home)
        return info

class PgpassConf:
    def __init__(self, host, port, database, username, passwd):
        self.host = host
        self.port = port
        self.db = database
        self.username = username
        self.passwd = passwd

    def __str__(self):
        info = '''
        host:%s
        port:%d
        database:%s
        username:%s
        passwd:%s
        ''' % (self.host, self.port, self.db, self.username, self.passwd)
        return info

class ProcessWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        self.contentEdit = QTextEdit()

        grid = QGridLayout()
        grid.setSpacing(10)
        grid.addWidget(self.contentEdit, 0, 0)

        self.setLayout(grid)
        self.setWindowTitle("process show")
        self.setGeometry(200, 300, 500, 300)
        self.show()

    def appendInfo(self, info):
        info = info.strip()
        self.contentEdit.moveCursor(QTextCursor.End)
        self.contentEdit.append(info)

    def clearInfo(self):
        self.contentEdit.clear()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class RealTimeData(QObject):
    signal = pyqtSignal(str)
    def send_signal(self, data):
        self.signal.emit(str(data))

if __name__ == "__main__":
    app = QApplication(sys.argv)
    ex = ProcessWindow()

    realData = RealTimeData()
    realData.signal.connect(ex.appendInfo)
    realData.send_signal("hello")

    sys.exit(app.exec_())