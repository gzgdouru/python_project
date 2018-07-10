import sys, os
from PyQt5.QtWidgets import QMainWindow, QAction, QApplication, QMenu, QTextEdit, QMessageBox
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QFont
from db_sync import DBSync
from db_sync_windows import SetDBWindow
from db_sync_windows import CreateTableWindow, DropTableWindow
from db_sync_windows import AddFieldWindow, DelFieldWindow
from db_sync_windows import AddRowConstrWindow, AddTableConstrWindow, DelRowConstrWindow, DelTableConstrWindow

class DBSyncMenu(QMainWindow):
    msgSignal = pyqtSignal(str)  # timely show
    def __init__(self):
        super(DBSyncMenu, self).__init__()
        self.dbSync = DBSync()
        self.initUI()

    def initUI(self):
        menubar = self.menuBar()

        self.textEd = QTextEdit()
        self.textEd.setReadOnly(True)
        font = QFont()
        font.setPointSize(14)
        self.textEd.setFont(font)
        self.setCentralWidget(self.textEd)

        self.config_menu_init(menubar)
        self.run_menu_init(menubar)

        self.setGeometry(700, 300, 400, 300)
        self.setWindowTitle('数据库同步工具')
        self.show()

    def config_menu_init(self, baseMenu):
        configMenu = baseMenu.addMenu("配置")

        dbSetAct = QAction("配置数据库信息", self)
        dbSetAct.triggered.connect(self.set_db_info)
        configMenu.addAction(dbSetAct)

        dbShowAct = QAction("显示数据库信息", self)
        dbShowAct.triggered.connect(self.show_db_info)
        configMenu.addAction(dbShowAct)

    def run_menu_init(self, baseMenu):
        runMenu = baseMenu.addMenu("运行")

        #clear data file
        clearAct = QAction("清理数据文件", self)
        clearAct.triggered.connect(self.clear_data_file)
        runMenu.addAction(clearAct)

        runMenu.addSeparator()

        #table menu
        tableMenu = runMenu.addMenu("数据表")
        self.table_menu_init(tableMenu)

        #field menu
        fieldMenu = runMenu.addMenu("表字段")
        self.field_menu_init(fieldMenu)

        #constraints menu
        constrMenu = runMenu.addMenu("表约束")
        self.constraints_menu_init(constrMenu)

        runMenu.addSeparator()

        #sync
        syncAct = QAction("同步数据库", self)
        syncAct.triggered.connect(self.sync_database)
        runMenu.addAction(syncAct)

    def table_menu_init(self, baseMenu):
        createTableAct = QAction("创建表", self)
        createTableAct.triggered.connect(self.create_table)
        baseMenu.addAction(createTableAct)

        dropTableAct = QAction("销毁表", self)
        dropTableAct.triggered.connect(self.drop_table)
        baseMenu.addAction(dropTableAct)

    def field_menu_init(self, baseMenu):
        # add table field
        addFieldAct = QAction("添加字段", self)
        addFieldAct.triggered.connect(self.add_field)
        baseMenu.addAction(addFieldAct)

        # modify table field
        # modifyFieldMenu = baseMenu.addMenu("修改字段")
        # self.modify_field_menu_init(modifyFieldMenu)

        # delete table field
        delFieldAct = QAction("删除字段", self)
        delFieldAct.triggered.connect(self.delete_field)
        baseMenu.addAction(delFieldAct)

    def modify_field_menu_init(self, baseMenu):
        modifyNameAct = QAction("修改字段名称", self)
        modifyNameAct.triggered.connect(self.modify_field)
        baseMenu.addAction(modifyNameAct)

        modifyTypeAct = QAction("修改字段属性", self)
        modifyTypeAct.triggered.connect(self.modify_field)
        baseMenu.addAction(modifyTypeAct)

    def constraints_menu_init(self, baseMenu):
        addRowAct = QAction("添加行级约束", self)
        addRowAct.triggered.connect(self.add_row_constraints)
        baseMenu.addAction(addRowAct)

        addTableAct = QAction("添加表级约束", self)
        addTableAct.triggered.connect(self.add_table_constraints)
        baseMenu.addAction(addTableAct)

        baseMenu.addSeparator()

        delRowAct = QAction("删除行级约束", self)
        delRowAct.triggered.connect(self.del_row_constraints)
        baseMenu.addAction(delRowAct)

        delTableAct = QAction("删除表级约束", self)
        delTableAct.triggered.connect(self.del_table_constraints)
        baseMenu.addAction(delTableAct)

    def set_db_info(self):
        self.ui = SetDBWindow(self.dbSync)
        self.ui.show()

    def show_db_info(self):
        text = '''HOST: %s\nPORT: %s\nUSER: %s\nPASSWD: %s\n''' % (self.dbSync.host, str(self.dbSync.port), self.dbSync.user, self.dbSync.passwd)
        self.msgSignal.emit("clear")
        self.msgSignal.emit(text)

    def display_msg(self, msg):
        if msg == "clear":
            self.textEd.clear()
        else:
            if msg.find("[ERROR]") != -1: self.textEd.setTextColor(Qt.red)
            self.textEd.append(msg)
            self.textEd.setTextColor(Qt.black)

    def clear_data_file(self):
        reply = QMessageBox.question(self, "clear hint", "确定清空数据文件?", QMessageBox.Yes|QMessageBox.No)
        if reply == QMessageBox.Yes: self.dbSync.clear_data_file()

    def create_table(self):
        self.ui = CreateTableWindow(self.dbSync)
        self.ui.show()

    def drop_table(self):
        self.ui = DropTableWindow(self.dbSync)
        self.ui.show()

    def add_field(self):
        self.ui = AddFieldWindow(self.dbSync)
        self.ui.show()

    def modify_field(self):
        pass

    def delete_field(self):
        self.ui = DelFieldWindow(self.dbSync)
        self.ui.show()

    def add_row_constraints(self):
        self.ui = AddRowConstrWindow(self.dbSync)
        self.ui.show()

    def add_table_constraints(self):
        self.ui = AddTableConstrWindow(self.dbSync)
        self.ui.show()

    def del_row_constraints(self):
        self.ui = DelRowConstrWindow(self.dbSync)
        self.ui.show()

    def del_table_constraints(self):
        self.ui = DelTableConstrWindow(self.dbSync)
        self.ui.show()

    def sync_database(self):
        reply = QMessageBox.question(self, "sync hint", "同步前请确保配置了数据库信息和检查数据文件, 是否继续执行?", QMessageBox.Yes|QMessageBox.No)
        if reply == QMessageBox.Yes:
            try:
                self.dbSync.sync_database(self.msgSignal)
            except Exception as e:
                QMessageBox.warning(None, "warning", str(e))

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.ui.close()
            self.close()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = DBSyncMenu()
    ex.msgSignal.connect(ex.display_msg)
    sys.exit(app.exec_())