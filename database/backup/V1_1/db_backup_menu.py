import sys
from PyQt5.QtWidgets import QMainWindow, QAction, QApplication, QMenu, QTextEdit, QMessageBox
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont
from db_backup import DatabaseBackup
from db_backup_ui import BackupWindow, RestoreWindow, StructBkWindow, DataBkWindow,\
    SingleTableBkWindow, RemoteBkWindow, RemoteSvrConfWindow, PgpassConfWindow

class DBBackupMenu(QMainWindow):
    dbbk = DatabaseBackup()
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        menubar = self.menuBar()

        self.textEd = QTextEdit()
        self.textEd.setReadOnly(True)
        font = QFont()
        font.setPointSize(14)
        self.textEd.setFont(font)
        self.setCentralWidget(self.textEd)

        #config menu
        configMenu = menubar.addMenu("config")

        remoteSvrShowAct = QAction("显示远程服务器", self)
        remoteSvrShowAct.triggered.connect(self.remoteSvrShow)
        configMenu.addAction(remoteSvrShowAct)

        remoteSvrConfAct = QAction("配置远程服务器", self)
        remoteSvrConfAct.triggered.connect(self.remoteSvrConf)
        configMenu.addAction(remoteSvrConfAct)
        configMenu.addSeparator()

        localPGShowAct = QAction("浏览本地pgpass文件", self)
        localPGShowAct.triggered.connect(lambda: self.pgpassShow(None))
        configMenu.addAction(localPGShowAct)

        remotePGShowAct = QAction("浏览远程pgpass文件", self)
        remotePGShowAct.triggered.connect(lambda: self.pgpassShow(self.dbbk.remoteServer))
        configMenu.addAction(remotePGShowAct)
        configMenu.addSeparator()

        addLocalPGAct = QAction("添加本地pgpass记录", self)
        addLocalPGAct.triggered.connect(lambda : self.addPgpass(None))
        configMenu.addAction(addLocalPGAct)

        addRemotePGAct = QAction("添加远程pgpass记录", self)
        addRemotePGAct.triggered.connect(lambda : self.addPgpass(self.dbbk.remoteServer))
        configMenu.addAction(addRemotePGAct)

        #run menu
        optMenu = menubar.addMenu("run")

        backupAct = QAction("数据库备份", self)
        backupAct.triggered.connect(self.dbBackup)
        optMenu.addAction(backupAct)

        restoreAct = QAction("数据库恢复", self)
        restoreAct.triggered.connect(self.dbRestore)
        optMenu.addAction(restoreAct)
        optMenu.addSeparator()

        remoteBkAct = QAction("远程备份", self)
        remoteBkAct.triggered.connect(self.remoteBackup)
        optMenu.addAction(remoteBkAct)
        optMenu.addSeparator()

        structAct = QAction("表结构备份", self)
        structAct.triggered.connect(self.structBackup)
        optMenu.addAction(structAct)

        datasAct = QAction("表数据备份", self)
        datasAct.triggered.connect(self.datasBackup)
        optMenu.addAction(datasAct)
        optMenu.addSeparator()

        tableMenu = QMenu("单个表备份", self)
        optMenu.addMenu(tableMenu)

        tableAct = QAction("表备份", self)
        tableAct.triggered.connect(self.tableBackup)
        tableMenu.addAction(tableAct)

        tableStructAct = QAction("结构备份", self)
        tableStructAct.triggered.connect(self.tableStructBackup)
        tableMenu.addAction(tableStructAct)

        tableDataAct = QAction("数据备份", self)
        tableDataAct.triggered.connect(self.tableDataBackup)
        tableMenu.addAction(tableDataAct)

        self.setGeometry(700, 300, 400, 300)
        self.setWindowTitle('数据库备份工具')
        self.show()

    def remoteSvrShow(self):
        text = DBBackupMenu.dbbk.remoteServer.__str__()
        self.textEd.setText(text)

    def remoteSvrConf(self):
        self.remoteSvrConfUI = RemoteSvrConfWindow(self.dbbk.remoteServer)
        self.remoteSvrConfUI.show()

    def pgpassShow(self, remoteServer):
        text, errorText = self.dbbk.get_pass_conetnt(remoteServer)
        if errorText == "":
            self.textEd.setText(text)
        else:
            QMessageBox.warning(None, "get_pass_conetnt()", errorText)

    def addPgpass(self, remoteServer):
        self.addPgpassUI = PgpassConfWindow(remoteServer)
        self.addPgpassUI.show()

    def dbBackup(self):
        self.bkUI = BackupWindow()
        self.bkUI.show()

    def dbRestore(self):
        self.restoreUI = RestoreWindow()
        self.restoreUI.show()

    def remoteBackup(self):
        self.remoteBkUI = RemoteBkWindow(self.dbbk.remoteServer)
        self.remoteBkUI.show()

    def structBackup(self):
        self.structBkUI = StructBkWindow()
        self.structBkUI.show()

    def datasBackup(self):
        self.datasBkUI = DataBkWindow()
        self.datasBkUI.show()

    def tableBackup(self):
        self.tableBkUI = SingleTableBkWindow("all")
        self.tableBkUI.show()

    def tableStructBackup(self):
        self.tableStructBkUI = SingleTableBkWindow("struct")
        self.tableStructBkUI.show()

    def tableDataBackup(self):
        self.tableDataBkUI = SingleTableBkWindow("data")
        self.tableDataBkUI.show()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = DBBackupMenu()
    sys.exit(app.exec_())