#coding:utf-8
import os, sys
import threading
from Tkinter import *
from ttk import Combobox
import getopt

class DatabaseBackup:
    def __init__(self, host = "localhost", port = 5432, db = [], bk_path = r"./pg_backup"):
        self.host = host
        self.port = port
        self.db = db
        self.bkPath = bk_path
        self.opt = {}
        self.lock = threading.Lock()
        self.optInit()

    def __str__(self):
        strInfo = '''
        host: %s
        port: %s
        db: %s
        bk_path: %s
        ''' % (self.host, self.port, str(self.db), self.bkPath)
        return strInfo

    def single_database_backup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -c %s | gzip > %s/%s.gz" % (self.host, self.port, databaseName, self.bkPath, databaseName)
        os.system(sql)
        with self.lock:
            print "db backup %s finish" % databaseName

    def dataBackup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -a %s > %s/%s_data.sql" % (self.host, self.port, databaseName, self.bkPath, databaseName)
        os.system(sql)
        print "backup table data by %s finish" % databaseName

    def createDir(self, operation):
        if not os.path.exists(self.bkPath): os.makedirs(self.bkPath)

    def database_backup(self, *args):
        print "database backup start........."
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.single_database_backup, args=(loop,))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        print "database backup end........."

    def database_restore(self, *args):
        print "restore database start........."
        threads = []
        for loop in self.db:
            sql = "cat %s/%s.gz | gunzip | psql -p %s -h %s -U postgres %s" % (self.bkPath, loop, self.port, self.host, loop)
            os.system(sql)
            print "restore db %s finish" % loop

        print "restore database end........."

    def table_data_backup(self, *args):
        print "backup table data start........."
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.dataBackup, args=(loop,))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        print "backup table data end..........."

    def table_struct_backup(self, *args):
        print "backup table struct start........."

        for loop in self.db:
            sql = "pg_dump -p %s -h %s -U postgres -s %s > %s/%s_struct.sql" % (self.port, self.host, loop, self.bkPath, loop)
            os.system(sql)
            print "backup table struct by %s finish" % loop

        print "backup table struct end........."

    def single_table_backup(self, *args):
        database = args[0]
        table = args[1]
        type = args[2]

        print "backup %s %s start........" % (table, type)

        if type == "data":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -a %s> %s/%s_data.sql" % (self.port, self.host, table, database, self.bkPath, table)
        elif type == "struct":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -s %s> %s/%s_struct.sql" % (self.port, self.host, table, database, self.bkPath, table)
        else:
            sql = "pg_dump -p %s -h %s -U postgres -t %s %s> %s/%s.sql" % (self.port, self.host, table, database, self.bkPath, table)

        os.system(sql)

        print "backup %s %s end........" % (table, type)

    def optInit(self):
        self.opt["backup"] = self.database_backup
        self.opt["restore"] = self.database_restore
        self.opt["table_data_backup"] = self.table_data_backup
        self.opt["table_struct_backup"] = self.table_struct_backup
        self.opt["single_table_backup"] = self.single_table_backup

    def getOperation(self, operation):
        return self.opt.get(operation, None)

def makeform(root, fields):
    entries = []
    hint = "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup{database table [data,struct,all]} )"
    lable = Label(root, text=hint)
    lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
    lable.pack(side=TOP)
    for entry in fields:
        keyStr = entry[0]
        valueStr = entry[1]
        row = Frame(root)
        row.pack(side=TOP, fill=X)
        if keyStr in ("type", "operation"):
            ent = makeCombobox(row, keyStr, valueStr)
        else:
            ent = makeEntry(row, keyStr, valueStr)
        entries.append(ent)
    return entries

def makeEntry(root, keyStr, valueStr):
    lab = Label(root, width=15, text=keyStr)
    ent = Entry(root, width=100)
    ent.insert(0, valueStr)
    lab.pack(side=LEFT)
    ent.pack(side=RIGHT, expand=YES, fill=X)
    return ent

def makeCombobox(root, keyStr, valueStr):
    Label(root, width=15, text=keyStr).pack(side=LEFT)
    chose = Combobox(root)
    chose["values"] = valueStr
    chose.pack(side=LEFT)
    return chose

def deal(entries):
    param = []
    [param.append(entry.get()) for entry in entries]

    host = param[0]
    port = param[1]
    db = list(param[2].split(" "))
    bk_path = param[3] + os.sep + host
    operation = param[4]
    database = param[5]
    table = param[6]
    type = param[7]

    dbBackup = DatabaseBackup(host, port, db, bk_path)
    dbBackup.createDir(operation)
    func = dbBackup.getOperation(operation)
    if func:
        func(*(database, table, type))
    else:
        print "Not Supported operation!"
        print "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup[database table {data,struct,all}] )"

def useGui():
    fields = [
        ["host:", "127.0.0.1"],
        ["port:", 5432],
        ["db", "ajb_shop_monitor push rtp rtsp upgrade"],
        ["bk_path", r"f:/pgsql/pg_backup"],
        ["operation", "backup restore table_data_backup table_struct_backup single_table_backup"],
        ["database", ""],
        ["table", ""],
        ["type", "all data struct"]
    ]

    root = Tk()
    ents = makeform(root, fields)
    root.bind("<Return>", lambda event: deal(ents))
    Button(root, text="commit", command=lambda: deal(ents)).pack(side=LEFT)
    Button(root, text="quit", command=sys.exit).pack(side=RIGHT)
    root.mainloop()

def useConsole():
    # host = "127.0.0.1"
    # port = 5432
    # db = ["ajb_shop_monitor", "push", "rtp", "rtsp", "upgrade"]
    # bk_path = r"/usr/local/pgsql/pg_backup"
    # table_data_dir = r"/usr/local/pgsql/pg_table_data_backup"
    # table_struct_dir = r"/usr/local/pgsql/pg_table_struct_backup"
    # operation = sys.argv[1] if len(sys.argv) > 1 else None
    # database = sys.argv[2] if len(sys.argv) > 2 else None
    # table = sys.argv[3] if len(sys.argv) > 3 else None
    # type = sys.argv[4] if len(sys.argv) > 4 else None

    params = parse_operation(sys.argv[1:])
    host = params.get("host", "127.0.0.1")
    port = params.get("port", 5432)
    db = params.get("db", ["ajb_shop_monitor", "push", "rtp", "rtsp", "upgrade"])
    bk_path = params.get("backup-path", r"/usr/local/pgsql/pg_backup") + os.sep + host
    operation = params.get("operation", None)
    database = params.get("database", None)
    table = params.get("table", None)
    type = params.get("type", None)

    dbBackup = DatabaseBackup(host, port, db, bk_path)
    dbBackup.createDir(operation)
    # print dbBackup
    # print operation, database, table, type
    func = dbBackup.getOperation(operation)
    if func:
        func(*(database, table, type))
    else:
        print "Not Supported operation!"
        print "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup{database table [data,struct,all]} )"

def parse_operation(argv):
    try:
        opts, args = getopt.getopt(argv, "h",
                                   ["help",
                                    "host=",
                                    "port=",
                                    "db=",
                                    "bk_path=",
                                    "operation=",
                                    "database=",
                                    "table=",
                                    "type=",
                                    ])
    except getopt.GetoptError:
        print "param except : db_backup_ex.py --host --port --db --backup-path --operation --database --table --type"
        exit(2)

    dictOpt = {}
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print "-h,--help, 获取参数说明"
            print "--host, 指定远程服务器,默认为:127.0.0.1"
            print "--port, 指定端口,默认为:5432"
            print "--db, 指定所有备份的数据库,以','号隔开, 默认为:ajb_shop_monitor,push,rtp,rtsp,upgrade"
            print "--backup-path, 指定数据库备份路径, 默认为:/usr/local/pgsql/pg_backup"
            print "--operation, 指定操作, 支持:backup(备份数据库), restore(恢复数据库), table_data_backup(表数据备份), table_struct_backup(表结构备份), single_table_backup(单表备份,需指定database,table和type)"
            print "--database, 指定数据库, 单表备份时需指定此参数"
            print "--table, 指定表, 单表备份时需指定此参数"
            print "--type, 指定类型, 单表备份时需指定此参数,支持:data(表数据), struct(表结构), all(表数据和表结构)"
            exit(0)
        elif opt == "--host":
              dictOpt["host"] = arg
        elif opt == "--port":
            dictOpt["port"] = arg
        elif opt == "--db":
            dictOpt["db"] = list(arg.split(","))
        elif opt == "--backup-path":
            dictOpt["backup-path"] = arg
        elif opt == "--operation":
            dictOpt["operation"] = arg
        elif opt == "--database":
            dictOpt["database"] = arg
        elif opt == "--table":
            dictOpt["table"] = arg
        elif opt == "--type":
            dictOpt["type"] = arg
    return dictOpt

if __name__ == "__main__":
   if sys.platform[:3] == "win":
       useGui()
   else:
=======
#coding:utf-8
import os, sys
import threading
from Tkinter import *
from ttk import Combobox

class DatabaseBackup:
    def __init__(self, host = "localhost", port = 5432, db = [], bk_path = r"./pg_backup", table_data_dir = r"./pg_table_data_backup", table_struct_dir = r"./pg_table_struct_backup"):
        self.host = host
        self.port = port
        self.db = db
        self.bkPath = bk_path
        self.tableDataDir = table_data_dir
        self.tableStructDir = table_struct_dir
        self.opt = {}
        self.lock = threading.Lock()
        self.CreateDir()
        self.optInit()

    def single_database_backup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -c %s | gzip > %s/%s.gz" % (self.host, self.port, databaseName, self.bkPath, databaseName)
        os.system(sql)
        with self.lock:
            print "db backup %s finish" % databaseName

    def dataBackup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -a %s > %s/%s.sql" % (self.host, self.port, databaseName, self.tableDataDir, databaseName)
        os.system(sql)
        print "backup table data by %s finish" % databaseName

    def CreateDir(self):
        if not os.path.exists(self.bkPath): os.mkdir(self.bkPath)
        if not os.path.exists(self.tableDataDir): os.mkdir(self.tableDataDir)
        if not os.path.exists(self.tableStructDir): os.mkdir(self.tableStructDir)

    def database_backup(self, *args):
        print "database backup start........."
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.single_database_backup, args=(loop,))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        print "database backup end........."

    def database_restore(self, *args):
        print "restore database start........."
        threads = []
        for loop in self.db:
            sql = "cat %s/%s.gz | gunzip | psql -p %s -h %s -U postgres %s" % (self.bkPath, loop, self.port, self.host, loop)
            os.system(sql)
            print "restore db %s finish" % loop

        print "restore database end........."

    def table_data_backup(self, *args):
        print "backup table data start........."
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.dataBackup, args=(loop,))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        print "backup table data end..........."

    def table_struct_backup(self, *args):
        print "backup table struct start........."

        for loop in self.db:
            sql = "pg_dump -p %s -h %s -U postgres -s %s > %s/%s.sql" % (self.port, self.host, loop, self.tableStructDir, loop)
            os.system(sql)
            print "backup table struct by %s finish" % loop

        print "backup table struct end........."

    def single_table_backup(self, *args):
        database = args[0]
        table = args[1]
        type = args[2]

        print "backup %s start........" % table

        if type == "data":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -a %s> %s/%s.sql" % (self.port, self.host, table, database, self.tableDataDir, table)
        elif type == "struct":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -s %s> %s/%s.sql" % (self.port, self.host, table, database, self.tableStructDir, table)
        else:
            sql = "pg_dump -p %s -h %s -U postgres -t %s %s> %s/%s.sql" % (self.port, self.host, table, database, self.bkPath, table)

        os.system(sql)

        print "backup %s end........" % table

    def optInit(self):
        self.opt["backup"] = self.database_backup
        self.opt["restore"] = self.database_restore
        self.opt["table_data_backup"] = self.table_data_backup
        self.opt["table_struct_backup"] = self.table_struct_backup
        self.opt["single_table_backup"] = self.single_table_backup

    def getOperation(self, operation):
        return self.opt.get(operation, None)

def makeform(root, fields):
    entries = []
    hint = "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup[database table {data,struct,all}] )"
    lable = Label(root, text=hint)
    lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
    lable.pack(side=TOP)
    for entry in fields:
        keyStr = entry[0]
        valueStr = entry[1]
        row = Frame(root)
        row.pack(side=TOP, fill=X)
        if keyStr in ("type", "operation"):
            ent = makeCombobox(row, keyStr, valueStr)
        else:
            ent = makeEntry(row, keyStr, valueStr)
        entries.append(ent)
    return entries

def makeEntry(root, keyStr, valueStr):
    lab = Label(root, width=15, text=keyStr)
    ent = Entry(root, width=100)
    ent.insert(0, valueStr)
    lab.pack(side=LEFT)
    ent.pack(side=RIGHT, expand=YES, fill=X)
    return ent

def makeCombobox(root, keyStr, valueStr):
    Label(root, width=15, text=keyStr).pack(side=LEFT)
    chose = Combobox(root)
    chose["values"] = valueStr
    chose.pack(side=LEFT)
    return chose

def deal(entries):
    param = []
    [param.append(entry.get()) for entry in entries]

    host = param[0]
    port = param[1]
    db = list(param[2].split(" "))
    bk_path = param[3]
    table_data_dir = param[4]
    table_struct_dir = param[5]
    operation = param[6]
    database = param[7]
    table = param[8]
    type = param[9]

    dbBackup = DatabaseBackup(host, port, db, bk_path, table_data_dir, table_struct_dir)
    func = dbBackup.getOperation(operation)
    if func:
        func(*(database, table, type))
    else:
        print "Not Supported operation!"
        print "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup[database table {data,struct,all}] )"

def useGui():
    fields = [
        ["host:", "192.168.232.130"],
        ["port:", 5432],
        ["db", "ajb_shop_monitor push rtp rtsp upgrade"],
        ["bk_path", r"f:/pgsql/pg_backup2"],
        ["table_data_dir", r"f:/pgsql/pg_table_data_backup2"],
        ["table_struct_dir", r"f:/pgsql/pg_table_struct_backup2"],
        ["operation", "backup restore table_data_backup table_struct_backup single_table_backup"],
        ["database", ""],
        ["table", ""],
        ["type", "all data struct"]
    ]

    root = Tk()
    ents = makeform(root, fields)
    root.bind("<Return>", lambda event: deal(ents))
    Button(root, text="commit", command=lambda: deal(ents)).pack(side=LEFT)
    Button(root, text="quit", command=sys.exit).pack(side=RIGHT)
    root.mainloop()

def useConsole():
    host = "127.0.0.1"
    port = 5432
    db = ["ajb_shop_monitor", "push", "rtp", "rtsp", "upgrade"]
    bk_path = r"/usr/local/pgsql/pg_backup"
    table_data_dir = r"/usr/local/pgsql/pg_table_data_backup"
    table_struct_dir = r"/usr/local/pgsql/pg_table_struct_backup"
    operation = sys.argv[1] if len(sys.argv) > 1 else None
    database = sys.argv[2] if len(sys.argv) > 2 else None
    table = sys.argv[3] if len(sys.argv) > 3 else None
    type = sys.argv[4] if len(sys.argv) > 4 else None

    dbBackup = DatabaseBackup(host, port, db, bk_path, table_data_dir, table_struct_dir)
    func = dbBackup.getOperation(operation)
    if func:
        func(*(database, table, type))
    else:
        print "Not Supported operation!"
        print "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup[database table {data,struct,all}] )"


if __name__ == "__main__":
   if sys.platform[:3] == "win":
       useGui()
   else:
>>>>>>> 31b751da9cab8c64478d0c061b88c453fb75d14a:database/db_backup_ex.py
       useConsole()