import sys
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QApplication, QCheckBox
from PyQt5.QtWidgets import QLabel, QWidget, QLineEdit, QGridLayout
from PyQt5.QtWidgets import QPushButton, QTextEdit, QComboBox, QMessageBox, QMainWindow
from db_sync import DBSync, ConstraintsLevel, OptionType

class CustomWidget(QWidget):
    def __init__(self, dbSync):
        super(CustomWidget, self).__init__()
        self.dbSync = dbSync
        self.custom_widget_init()

    def custom_widget_init(self):
        # host
        self.hostLb = QLabel("host:")
        self.hostCb = QComboBox()
        self.make_cb_item(self.hostCb, self.dbSync.hostList)

        # port
        self.portLb = QLabel("port")
        self.portLe = QLineEdit("5432")

        # user
        self.userLb = QLabel("user")
        self.userCb = QComboBox()
        self.make_cb_item(self.userCb, self.dbSync.userList)

        # passwd
        self.passwdLb = QLabel("passwd")
        self.passwdLe = QLineEdit()

        # database
        self.dbLb = QLabel("database:")
        self.dbCb = QComboBox()
        self.make_cb_item(self.dbCb, self.dbSync.dbList)

        #table
        self.tableLb = QLabel("table:")
        self.tableLe = QLineEdit()

        # field
        self.fieldLb = QLabel("field:")
        self.fieldLe = QLineEdit()

        # type
        self.typeLb = QLabel("type:")
        self.typeLe = QLineEdit()

        # constraints
        self.constrLb = QLabel("constraints:")
        self.constrLe = QLineEdit()

        #constraints name
        self.constrNameLb = QLabel("constraintsName:")
        self.constrNameLe = QLineEdit()

        # submit
        self.submitBt = QPushButton("submit")
        self.submitBt.clicked.connect(self.submit)

    def make_cb_item(self, cbNode, nodeDatas):
        index = 0
        for data in nodeDatas:
            cbNode.insertItem(index, data)
            index += 1

    def submit(self):
        pass

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class SetDBWindow(CustomWidget):
    def __init__(self, dbSync):
        super(SetDBWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.hostLb, row, 0)
        grid.addWidget(self.hostCb, row, 1)
        row += 1

        grid.addWidget(self.portLb, row, 0)
        grid.addWidget(self.portLe, row, 1)
        row += 1

        grid.addWidget(self.userLb, row, 0)
        grid.addWidget(self.userCb, row, 1)
        row += 1

        grid.addWidget(self.passwdLb, row, 0)
        grid.addWidget(self.passwdLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle('set db info')
        self.move(750, 350)

    def submit(self):
        try:
            #get db info
            host = self.hostCb.currentText()
            port = int(self.portLe.text())
            user = self.userCb.currentText()
            passwd = self.passwdLe.text()

            #check db info
            if port is None or port == 0: raise ValueError("端口不能为空或为0!")
            if passwd == "": raise ValueError("密码不能为空!")

            #set db info
            self.dbSync.set_info(**{
                "host" : host,
                "port" : port,
                "user" : user,
                "passwd" : passwd
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        finally:
            self.close()

class CreateTableWindow(CustomWidget):
    def __init__(self, dbSync):
        super(CreateTableWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle('create table')
        self.move(750, 400)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()

            if table == "": raise ValueError("表名不能为空!")

            self.dbSync.add_create_table(db, table)
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class DropTableWindow(CreateTableWindow):
    def __init__(self, dbSync):
        super(DropTableWindow, self).__init__(dbSync)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()

            if table == "": raise ValueError("表名不能为空!")

            self.dbSync.add_drop_table(db, table)
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class RenameTableWindow(CustomWidget):
    def __init__(self, dbSync):
        super(RenameTableWindow, self).__init__(dbSync)

class AddFieldWindow(CustomWidget):
    def __init__(self, dbSync):
        super(AddFieldWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.fieldLb, row, 0)
        grid.addWidget(self.fieldLe, row, 1)
        row += 1

        grid.addWidget(self.typeLb, row, 0)
        grid.addWidget(self.typeLe, row, 1)
        row += 1

        grid.addWidget(self.constrLb, row, 0)
        grid.addWidget(self.constrLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("add field")
        self.move(750, 400)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            field = self.fieldLe.text()
            type = self.typeLe.text()
            constraints = self.constrLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if field == "": raise ValueError("字段名不能为空!")
            if type == "": raise ValueError("字段类型不能为空!")

            self.dbSync.table_field_options(**{
                "db" : db,
                "table" : table,
                "field" : field,
                "type" : type,
                "constraints" : constraints,
                "option" : OptionType.add,
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class ModifyFieldWindow(CustomWidget):
    pass

class DelFieldWindow(CustomWidget):
    def __init__(self, dbSync):
        super(DelFieldWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.fieldLb, row, 0)
        grid.addWidget(self.fieldLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("add field")
        self.move(750, 400)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            field = self.fieldLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if field == "": raise ValueError("字段名不能为空!")

            self.dbSync.table_field_options(**{
                "db": db,
                "table": table,
                "field": field,
                "option": OptionType.delete,
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class AddRowConstrWindow(CustomWidget):
    def __init__(self, dbSync):
        super(AddRowConstrWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.fieldLb, row, 0)
        grid.addWidget(self.fieldLe, row, 1)
        row += 1

        grid.addWidget(self.constrLb, row, 0)
        grid.addWidget(self.constrLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("add row constraints")
        self.move(750, 400)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            field = self.fieldLe.text()
            constraints = self.constrLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if field == "": raise ValueError("字段不能为空!")
            if constraints == "": raise ValueError("约束不能为空")

            self.dbSync.make_constraints(**{
                "db" : db,
                "table" : table,
                "field" : field,
                "level" : ConstraintsLevel.row,
                "constraints" : constraints,
                "option" : OptionType.add,
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class AddTableConstrWindow(CustomWidget):
    def __init__(self, dbSync):
        super(AddTableConstrWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.constrNameLb, row, 0)
        grid.addWidget(self.constrNameLe, row, 1)
        row += 1

        grid.addWidget(self.constrLb, row, 0)
        grid.addWidget(self.constrLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("add table constraints")
        self.move(750, 350)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            name = self.constrNameLe.text()
            constraints = self.constrLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if name == "": raise ValueError("约束名不能为空!")
            if constraints == "": raise ValueError("约束不能为空!")

            self.dbSync.make_constraints(**{
                "db" : db,
                "table" : table,
                "name" : name,
                "constraints" : constraints,
                "level" : ConstraintsLevel.table,
                "option" : OptionType.add,
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class DelRowConstrWindow(AddRowConstrWindow):
    def __init__(self, dbSync):
        super(DelRowConstrWindow, self).__init__(dbSync)
        self.setWindowTitle("delete row constraints")

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            field = self.fieldLe.text()
            constraints = self.constrLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if field == "": raise ValueError("字段不能为空!")
            if constraints == "": raise ValueError("约束不能为空")

            self.dbSync.make_constraints(**{
                "db": db,
                "table": table,
                "field": field,
                "level": ConstraintsLevel.row,
                "constraints": constraints,
                "option": OptionType.delete,
            })
        except Exception as e:
           QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

class DelTableConstrWindow(CustomWidget):
    def __init__(self, dbSync):
        super(DelTableConstrWindow, self).__init__(dbSync)
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)
        row = 0

        grid.addWidget(self.dbLb, row, 0)
        grid.addWidget(self.dbCb, row, 1)
        row += 1

        grid.addWidget(self.tableLb, row, 0)
        grid.addWidget(self.tableLe, row, 1)
        row += 1

        grid.addWidget(self.constrNameLb, row, 0)
        grid.addWidget(self.constrNameLe, row, 1)
        row += 1

        grid.addWidget(self.submitBt, row, 0)

        self.setLayout(grid)
        self.setWindowTitle("delete table constraints")
        self.move(750, 350)

    def submit(self):
        try:
            db = self.dbCb.currentText()
            table = self.tableLe.text()
            name = self.constrNameLe.text()
            constraints = self.constrLe.text()

            if table == "": raise ValueError("表名不能为空!")
            if name == "": raise ValueError("约束名不能为空!")

            self.dbSync.make_constraints(**{
                "db": db,
                "table": table,
                "name": name,
                "level": ConstraintsLevel.table,
                "option": OptionType.delete,
            })
        except Exception as e:
            QMessageBox.warning(None, "warning", str(e))
        else:
            self.close()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    dbSync = DBSync()
    ex = SetDBWindow(dbSync)
    ex.show()
    sys.exit(app.exec_())
