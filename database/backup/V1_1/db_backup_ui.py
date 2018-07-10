import sys
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QApplication, QCheckBox
from PyQt5.QtWidgets import QLabel, QWidget, QLineEdit, QGridLayout
from PyQt5.QtWidgets import QPushButton, QTextEdit, QComboBox, QMessageBox, QMainWindow
from db_backup import DatabaseBackup
from PyQt5.QtGui import QTextCursor
from remote import RemoteOpt
from db_public import RemoteServer, PgpassConf

class BackupWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.dbCkList = []
        self.dbList = []
        self.initUI()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, row, 0)
        self.hostCb = QComboBox()
        self.makeHostItem(self.hostCb)
        grid.addWidget(self.hostCb, row, 1)
        row += 1

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, row, 1)
        row += 1

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, row, 0)
        row = self.makeDBCheck(grid, row, 1)
        row += 1

        homeLb = QLabel("home:")
        grid.addWidget(homeLb, row, 0)
        self.homeLe = QLineEdit("./")
        grid.addWidget(self.homeLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle('backup')
        self.move(700, 250)

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                hostCb.insertItem(index, host)
                index += 1

    def makeDBCheck(self, grid, row, col):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            for db in dbList:
                dbCk = QCheckBox(db)
                dbCk.stateChanged.connect(self.selectDB)
                self.dbCkList.append(dbCk)
                grid.addWidget(dbCk, row, col)
                col += 1
                if col > 3:
                    row += 1
                    col = 1
        return row

    def selectDB(self):
        for dbCk in self.dbCkList:
            db = dbCk.text()
            if dbCk.isChecked():
                if db not in self.dbList: self.dbList.append(db)
            else:
                if db in self.dbList: self.dbList.remove(db)

    def commit(self):
        try:
            host = self.hostCb.currentText()
            port = int(self.portLe.text())
            home = self.homeLe.text()
            bkObj = DatabaseBackup(host, port, self.dbList, home)
            bkObj.database_backup()
        except Exception as e:
            QMessageBox.warning(None, "hint", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class RestoreWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.dbCkList = []
        self.dbList = []
        self.initUI()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, row, 1)
        row += 1

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, row, 0)
        row = self.makeDBCheck(grid, row, 1)
        row += 1

        dataPathLb = QLabel("data path:")
        grid.addWidget(dataPathLb, row, 0)
        self.dataPathLe = QLineEdit("./pgbackup")
        grid.addWidget(self.dataPathLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle('restore')
        self.move(700, 250)

    def makeDBCheck(self, grid, row, col):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            for db in dbList:
                dbCk = QCheckBox(db)
                dbCk.stateChanged.connect(self.selectDB)
                self.dbCkList.append(dbCk)
                grid.addWidget(dbCk, row, col)
                col += 1
                if col > 3:
                    row += 1
                    col = 1
        return row

    def selectDB(self):
        for dbCk in self.dbCkList:
            db = dbCk.text()
            if dbCk.isChecked():
                if db not in self.dbList: self.dbList.append(db)
            else:
                if db in self.dbList: self.dbList.remove(db)

    def commit(self):
        try:
            port = int(self.portLe.text())
            dataPath = self.dataPathLe.text()
            dataPath = dataPath if dataPath[-1] != "/" else dataPath[:-1]
            dbObj = DatabaseBackup("localhost", port, self.dbList)
            errorText = dbObj.restoreCheck(dataPath)
            if errorText == "":
                dbObj.database_restore(dataPath)
            else:
                QMessageBox.warning(None, "hint", errorText)
        except Exception as e:
            QMessageBox.warning(None, "RestoreWindow", str(e))

    def keyPressEvent(self, e):
            if e.key() == Qt.Key_Escape:
                self.close()

class StructBkWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.dbCkList = []
        self.dbList = []
        self.initUI()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, row, 0)
        self.hostCb = QComboBox()
        self.makeHostItem(self.hostCb)
        grid.addWidget(self.hostCb, row, 1)
        row += 1

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, row, 1)
        row += 1

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, row, 0)
        row = self.makeDBCheck(grid, row, 1)
        row += 1

        homeLb = QLabel("home:")
        grid.addWidget(homeLb, row, 0)
        self.homeLe = QLineEdit("./")
        grid.addWidget(self.homeLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("struct backup")
        self.move(700, 250)

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                hostCb.insertItem(index, host)
                index += 1

    def makeDBCheck(self, grid, row, col):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            for db in dbList:
                dbCk = QCheckBox(db)
                dbCk.stateChanged.connect(self.selectDB)
                self.dbCkList.append(dbCk)
                grid.addWidget(dbCk, row, col)
                col += 1
                if col > 3:
                    row += 1
                    col = 1
        return row

    def selectDB(self):
        for dbCk in self.dbCkList:
            db = dbCk.text()
            if dbCk.isChecked():
                if db not in self.dbList: self.dbList.append(db)
            else:
                if db in self.dbList: self.dbList.remove(db)

    def commit(self):
        try:
            host = self.hostCb.currentText()
            port = int(self.portLe.text())
            home = self.homeLe.text()
            dbObj = DatabaseBackup(host, port, self.dbList, home)
            dbObj.table_struct_backup()
        except Exception as e:
            QMessageBox.warning(None, "hint", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class DataBkWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.dbCkList = []
        self.dbList = []
        self.initUI()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, row, 0)
        self.hostCb = QComboBox()
        self.makeHostItem(self.hostCb)
        grid.addWidget(self.hostCb, row, 1)
        row += 1

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, row, 1)
        row += 1

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, row, 0)
        row = self.makeDBCheck(grid, row, 1)
        row += 1

        homeLb = QLabel("home:")
        grid.addWidget(homeLb, row, 0)
        self.homeLe = QLineEdit("./")
        grid.addWidget(self.homeLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("data backup")
        self.move(700, 250)

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                hostCb.insertItem(index, host)
                index += 1

    def makeDBCheck(self, grid, row, col):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            for db in dbList:
                dbCk = QCheckBox(db)
                dbCk.stateChanged.connect(self.selectDB)
                self.dbCkList.append(dbCk)
                grid.addWidget(dbCk, row, col)
                col += 1
                if col > 3:
                    row += 1
                    col = 1
        return row

    def selectDB(self):
        for dbCk in self.dbCkList:
            db = dbCk.text()
            if dbCk.isChecked():
                if db not in self.dbList: self.dbList.append(db)
            else:
                if db in self.dbList: self.dbList.remove(db)

    def commit(self):
        try:
            host = self.hostCb.currentText()
            port = int(self.portLe.text())
            home = self.homeLe.text()
            dbObj = DatabaseBackup(host, port, self.dbList, home)
            dbObj.table_data_backup()
        except Exception as e:
            QMessageBox.warning(None, "hint", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class SingleTableBkWindow(QWidget):
    def __init__(self, opt="all"):
        super().__init__()
        self.opt = opt
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, 0, 0)
        self.hostCb = QComboBox()
        self.makeHostItem(self.hostCb)
        grid.addWidget(self.hostCb, 0, 1)

        portLb = QLabel("port:")
        grid.addWidget(portLb, 1, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, 1, 1)

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, 2, 0)
        self.dbCb = QComboBox()
        self.makeDBItem(self.dbCb)
        grid.addWidget(self.dbCb, 2, 1)

        tableLb = QLabel("table:")
        grid.addWidget(tableLb, 3, 0)
        self.tableLe = QLineEdit()
        grid.addWidget(self.tableLe, 3, 1)

        homeLb = QLabel("home:")
        grid.addWidget(homeLb, 4, 0)
        self.homeLe = QLineEdit("./")
        grid.addWidget(self.homeLe, 4, 1)

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, 5, 0)

        self.setLayout(grid)
        self.setWindowTitle("single table backup")

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                hostCb.insertItem(index, host)
                index += 1

    def makeDBItem(self, dbCb):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for db in dbList:
                dbCb.insertItem(index, db)
                index += 1

    def commit(self):
        try:
            host = self.hostCb.currentText()
            port = int(self.portLe.text())
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            home = self.homeLe.text()
            if table == "":
                QMessageBox. warning(None, "hint", "表不能为空")
            else:
                dbObj = DatabaseBackup(host, port, list(db), home)
                dbObj.single_table_backup(*(db, table, self.opt))
        except Exception as e:
            QMessageBox.warning(None, "hint", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class RemoteBkWindow(QWidget):
    def __init__(self, remoteServer):
        super().__init__()
        self.remoteServer = remoteServer
        self.dbCkList = []
        self.dbList = []
        self.initUI()

    def initUI(self):
        row = 0
        grid = QGridLayout()
        grid.setSpacing(10)

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, row, 0)
        self.hostCb = QComboBox()
        self.makeHostItem(self.hostCb)
        grid.addWidget(self.hostCb, row, 1)
        row += 1

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit("5432")
        grid.addWidget(self.portLe, row, 1)
        row += 1

        dbLb = QLabel("database:")
        grid.addWidget(dbLb, row, 0)
        row = self.makeDBCheck(grid, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("databse remote backup")
        self.move(700, 250)

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                if host == "localhost": continue
                hostCb.insertItem(index, host)
                index += 1

    def makeDBCheck(self, grid, row, col):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "hint", errorText)
            sys.exit()
        else:
            for db in dbList:
                dbCk = QCheckBox(db)
                dbCk.stateChanged.connect(self.selectDB)
                self.dbCkList.append(dbCk)
                grid.addWidget(dbCk, row, col)
                col += 1
                if col > 3:
                    row += 1
                    col = 1
        return row

    def selectDB(self):
        for dbCk in self.dbCkList:
            db = dbCk.text()
            if dbCk.isChecked():
                if db not in self.dbList: self.dbList.append(db)
            else:
                if db in self.dbList: self.dbList.remove(db)

    def commit(self):
        try:
            #bk info
            bkHost = self.hostCb.currentText()
            bkPort = int(self.portLe.text())

            obj = DatabaseBackup(bkHost, bkPort, self.dbList)
            obj.remote_backup(self.remoteServer)
        except Exception as e:
            QMessageBox.warning(None, "commit", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class PgpassConfWindow(QWidget):
    def __init__(self, remoteServer):
        super().__init__()
        self.remoteServer = remoteServer
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        dbHostLb = QLabel("host:")
        grid.addWidget(dbHostLb, row, 0)
        self.dbHostCb = QComboBox()
        self.makeHostItem(self.dbHostCb)
        grid.addWidget(self.dbHostCb, row, 1)
        row += 1

        dbPortLb = QLabel("port:")
        grid.addWidget(dbPortLb, row, 0)
        self.dbPortLe = QLineEdit("5432")
        grid.addWidget(self.dbPortLe, row, 1)
        row += 1

        databaseLb = QLabel("database:")
        grid.addWidget(databaseLb, row, 0)
        self.databaseCb = QComboBox()
        self.makeDBItem(self.databaseCb)
        grid.addWidget(self.databaseCb, row, 1)
        row += 1

        dbUserLb = QLabel("db user:")
        grid.addWidget(dbUserLb, row, 0)
        self.dbUserLe = QLineEdit("postgres")
        grid.addWidget(self.dbUserLe, row, 1)
        row += 1

        dbPasswdLb = QLabel("db passwd:")
        grid.addWidget(dbPasswdLb, row, 0)
        self.dbPasswdLe = QLineEdit("postgres")
        grid.addWidget(self.dbPasswdLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("pgpass configure")
        self.move(800, 350)

    def makeHostItem(self, hostCb):
        hostList, errorText = DatabaseBackup.getHost()
        if errorText != "":
            QMessageBox.warning(None, "makeHostItem()", errorText)
            sys.exit()
        else:
            index = 0
            for host in hostList:
                hostCb.insertItem(index, host)
                index += 1

    def makeDBItem(self, dbCb):
        dbList, errorText = DatabaseBackup.getDB()
        if errorText != "":
            QMessageBox.warning(None, "makeDBItem", errorText)
            sys.exit()
        else:
            index = 0
            for db in dbList:
                dbCb.insertItem(index, db)
                index += 1
            dbCb.insertItem(index, "all")

    def commit(self):
        try:
            #pgpass
            dbHost = self.dbHostCb.currentText()
            dbPort = int(self.dbPortLe.text())
            db = "*" if self.databaseCb.currentText() == "all" else self.databaseCb.currentText()
            dbUser = self.dbUserLe.text()
            dbpasswd = self.dbPasswdLe.text()
            pgpassConf = PgpassConf(dbHost, dbPort, db, dbUser, dbpasswd)

            obj = DatabaseBackup()
            errorText = ""
            if self.remoteServer is None:
                errorText = obj.write_local_pgpass(pgpassConf)
            else:
                errorText = obj.write_remote_pgpass(self.remoteServer, pgpassConf)

            #show result
            if errorText == "":
                QMessageBox.about(None, "result", "cofigure pgpass success.")
            else:
                QMessageBox.warning(None, "error hint", errorText)
        except Exception as e:
            QMessageBox.warning(None, "commit()", str(e))
        finally:
            self.close()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class RemoteSvrConfWindow(QWidget):
    def __init__(self, remoteServer):
        super().__init__()
        self.remoteServer = remoteServer
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        hostLb = QLabel("host:")
        grid.addWidget(hostLb, row, 0)
        self.hostLe = QLineEdit(self.remoteServer.host)
        grid.addWidget(self.hostLe, row, 1)
        row += 1

        portLb = QLabel("port:")
        grid.addWidget(portLb, row, 0)
        self.portLe = QLineEdit(str(self.remoteServer.port))
        grid.addWidget(self.portLe, row, 1)
        row += 1

        userLb = QLabel("username:")
        grid.addWidget(userLb, row, 0)
        self.userLe = QLineEdit(self.remoteServer.username)
        grid.addWidget(self.userLe, row, 1)
        row += 1

        passwdLb = QLabel("passwd:")
        grid.addWidget(passwdLb, row, 0)
        self.passwdLe = QLineEdit(self.remoteServer.passwd)
        grid.addWidget(self.passwdLe, row, 1)
        row += 1

        homeLb = QLabel("home:")
        grid.addWidget(homeLb, row, 0)
        self.homeLe = QLineEdit(self.remoteServer.home)
        grid.addWidget(self.homeLe, row, 1)
        row += 1

        commitBt = QPushButton("commit")
        commitBt.clicked.connect(self.commit)
        grid.addWidget(commitBt, row, 0)

        cancelBt = QPushButton("cancel")
        cancelBt.clicked.connect(self.cancel)
        grid.addWidget(cancelBt, row, 1)

        self.setLayout(grid)
        self.setWindowTitle("remote server configure")
        self.move(800, 350)

    def commit(self):
        try:
            self.remoteServer.host = self.hostLe.text()
            self.remoteServer.port = int(self.portLe.text())
            self.remoteServer.username = self.userLe.text()
            self.remoteServer.passwd = self.passwdLe.text()
            self.remoteServer.home = self.homeLe.text()
            QMessageBox.about(None, "configure result", "configure success.")
        except Exception as e:
            QMessageBox.warning(None, "RemoteSvrWindow::commit()", str(e))
        finally:
            self.close()

    def cancel(self):
        self.close()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

if __name__ == "__main__":
    pass