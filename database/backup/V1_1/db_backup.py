import os, sys
import threading
import json
import getpass
import subprocess
from datetime import datetime
from remote import RemoteOpt
from db_public import RemoteServer, MsgType

class DatabaseBackup:
    remoteServer = RemoteServer("", 22, "postgres", "")
    def __init__(self, host = "localhost", port = 5432, db = [], home = r"./"):
        self.host = host
        self.port = port
        self.db = db
        self.home = home if home[-1] != "/" else home[:-1]
        self.bkPath = self.home + "/pgbackup/" + host
        self.lock = threading.Lock()

    def __str__(self):
        strInfo = '''
        host: %s
        port: %s
        db: %s
        bk_path: %s
        ''' % (self.host, self.port, str(self.db), self.bkPath)
        return strInfo

    def showMsg(self, msg, msgtype=MsgType.info):
        if msg is None or msg == "": return 0
        msg = msg.strip()
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self.lock: print("[%s][%s] %s" % (now, msgtype.value, msg))

    def setConfig(self, host = "localhost", port = 5432, db = [], home = r"./"):
        self.host = host
        self.port = port
        self.db = db
        self.home = home if home[-1] != "/" else home[:-1]
        self.bkPath = self.home + "/pgbackup/" + host

    def set_remote_server(self, host, port, username, passwd, home="~"):
        DatabaseBackup.remoteServer.host = host
        DatabaseBackup.remoteServer.port = port
        DatabaseBackup.remoteServer.username = username
        DatabaseBackup.remoteServer.passwd = passwd
        DatabaseBackup.remoteServer.home = home

    #检查备份目录, 不存在时则创建
    def check_bkdir(self):
        if not os.path.exists(self.bkPath): os.makedirs(self.bkPath)

    def check_remote_server(self, remoteServer):
        errorText = ""
        if remoteServer.host == "":
            errorText = "host is empty, please configure first!"
        elif remoteServer.port == 0:
            errorText = "port is zero, please configure first!"
        elif remoteServer.username == "":
            errorText = "user is empty, please configure first!"
        elif remoteServer.passwd == "":
            errorText = "passwd is empty, please configure first!"
        elif remoteServer.home == "":
            errorText = "home is empty, please configure first!"
        return errorText

    def check_pgpass(self, content):
        if content is None or content == "": return False

        dbList = []
        for line in content.split("\n"):
            record = line.split(":")
            if self.host == record[0] and self.port == int(record[1]) and "postgres" == record[3]:
                dbList.append(record[2])

        if "*" not in dbList:
            for db in self.db:
                if db not in dbList: return False
        return True

    #单个数据库备份
    def single_database_backup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -c %s | gzip > %s/%s.gz" % (self.host, self.port, databaseName, self.bkPath, databaseName)
        stdout, stderr = self.exec_command(sql)
        self.showMsg(stderr, MsgType.error)

    #单个数据库数据备份
    def dataBackup(self, databaseName):
        sql = "pg_dump -h %s -p %s -U postgres -a %s > %s/%s_data.sql" % (self.host, self.port, databaseName, self.bkPath, databaseName)
        stdout, stderr = self.exec_command(sql)
        self.showMsg(stderr, MsgType.error)

    #数据库备份
    def database_backup(self):
        self.check_bkdir()
        if self.db == []: self.showMsg("database is empty, please select database first!", MsgType.error); return 0

        #check pgpass
        content, errorText = self.get_pass_conetnt(None)
        if errorText != "": self.showMsg(errorText); return 0
        if not self.check_pgpass(content):
            self.showMsg("pgpass file not find record, please configure first!", MsgType.error)
            return 0

        self.showMsg("backup database %s by %s, please wait!" % (str(self.db), self.host))
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.single_database_backup, args=(loop, ))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        self.showMsg("database backup complete...")

    #数据库恢复
    def database_restore(self, dataPath):
        if self.db == []: self.showMsg("database is empty, please select database first!", MsgType.error); return 0
        self.showMsg("restore database %s, please wait!" % str(self.db))
        threads = []
        for loop in self.db:
            sql = "cat %s/%s.gz | gunzip | psql -p %s -h %s -U postgres %s" % (dataPath, loop, self.port, self.host, loop)
            stdout, stderr = self.exec_command(sql)
            self.showMsg(stderr, MsgType.error)
            self.showMsg("restore db %s finish" % loop)

        self.showMsg("restore database complete...")

    #表数据备份
    def table_data_backup(self, *args):
        self.check_bkdir()
        if self.db == []: self.showMsg("database is empty, please select database first!", MsgType.error); return 0

        # check pgpass
        content, errorText = self.get_pass_conetnt(None)
        if errorText != "": self.showMsg(errorText); return 0
        if not self.check_pgpass(content):
            self.showMsg("pgpass file not find record, please configure first!", MsgType.error)
            return 0

        self.showMsg("backup database %s table data, please wait!" % str(self.db))
        threads = []
        for loop in self.db:
            thread = threading.Thread(target=self.dataBackup, args=(loop,))
            thread.start()
            threads.append(thread)

        [thread.join() for thread in threads]
        print("backup database table data complete...")

    #表结构备份
    def table_struct_backup(self, *args):
        self.check_bkdir()
        if self.db == []: self.showMsg("database is empty, please select database first!", MsgType.error); return 0
        self.showMsg("backup database %s table struct, please wait!" % str(self.db))

        # check pgpass
        content, errorText = self.get_pass_conetnt(None)
        if errorText != "": self.showMsg(errorText); return 0
        if not self.check_pgpass(content):
            self.showMsg("pgpass file not find record, please configure first!", MsgType.error)
            return 0

        for loop in self.db:
            sql = "pg_dump -p %s -h %s -U postgres -s %s > %s/%s_struct.sql" % (self.port, self.host, loop, self.bkPath, loop)
            stdout, stderr = self.exec_command(sql)
            self.showMsg(stderr, MsgType.error)
            self.showMsg("backup database table struct by %s finish" % loop)

        self.showMsg("backup table struct complete...")

    #单表备份
    def single_table_backup(self, *args):
        database = args[0]
        table = args[1]
        type = args[2]

        # check pgpass
        content, errorText = self.get_pass_conetnt(None)
        if errorText != "": self.showMsg(errorText); return 0
        if not self.check_pgpass(content):
            self.showMsg("pgpass file not find record, please configure first!", MsgType.error)
            return 0

        self.check_bkdir()
        self.showMsg("backup table %s %s, please wait!" % (table, type))

        if type == "data":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -a %s> %s/%s_data.sql" % (self.port, self.host, table, database, self.bkPath, table)
        elif type == "struct":
            sql = "pg_dump -p %s -h %s -U postgres -t %s -s %s> %s/%s_struct.sql" % (self.port, self.host, table, database, self.bkPath, table)
        else:
            sql = "pg_dump -p %s -h %s -U postgres -t %s %s> %s/%s.sql" % (self.port, self.host, table, database, self.bkPath, table)

        stdout, stderr = self.exec_command(sql)
        self.showMsg(stderr, MsgType.error)

        self.showMsg("backup table %s %s complete..." % (table, type))

    #远程备份数据库
    def remote_backup(self, remoteServer):
        try:
            #check remote server
            errorText = self.check_remote_server(remoteServer)
            if errorText != "": self.showMsg(errorText, MsgType.error); return 0

            #check db
            if self.db == []: self.showMsg("database is empty, please select database first!", MsgType.error); return 0

            # init remote sever
            opt = RemoteOpt(remoteServer.host, remoteServer.port, remoteServer.username, remoteServer.passwd)
            self.showMsg("init remote connect.....")
            opt.init_server_connect()
            self.showMsg("init remote connect success....")

            # dir check
            errorText = opt.checkDir(remoteServer.home)
            if errorText != "":
                stdout, stderror = opt.exec_command("mkdir -p %s" % remoteServer.home)
                if stderror != "": self.showMsg(stderror, MsgType.error); return -1

            # pgpass check
            pgPath = self.get_pgpass_path(remoteServer)
            stdout, stderror = opt.get_file_content(pgPath)
            if stderror != "": self.showMsg(stderror, MsgType.error); return -1
            if not self.check_pgpass(stdout):
                self.showMsg("pgpass file not find record, please configure first!", MsgType.error)
                return 0

            #backup
            threadList = []
            self.showMsg("remote backup database %s, please wait!" % str(self.db))
            for database in self.db:
                thread = threading.Thread(target=self.remote_backup_thread, args=(remoteServer, database))
                thread.start()
                threadList.append(thread)
            [thread.join() for thread in threadList]
            self.showMsg("remote backup databse complete...")
        except Exception as e:
            self.showMsg("remote_backup() error: %s" % str(e), MsgType.error)

    #远程备份线程
    def remote_backup_thread(self, remoteServer, database):
        opt = RemoteOpt(remoteServer.host, remoteServer.port, remoteServer.username, remoteServer.passwd)
        opt.init_server_connect()
        bkDir = remoteServer.home + "/pgbackup/" + self.host
        command = "pg_dump -h %s -p %s -U postgres -c %s | gzip > %s/%s.gz" % (self.host, self.port, database, bkDir, database)
        stdout, stderror = opt.exec_command(command)
        if stderror != "": self.showMsg(stderror, MsgType.error)

    #获取pgpass文件路径
    def get_pgpass_path(self, remoteServer=None):
        if remoteServer is None:
            user = getpass.getuser()
            path = "C:/Users/%s/AppData/Roaming/postgresql/pgpass.conf" % user
        else:
            path = remoteServer.home + "/.pgpass"
        return path

    #获取远程的pgpass文件内容
    def get_pass_conetnt(self, remoteServer):
        errortext = ""
        pgpassContent = ""
        try:
            pgpassPath = self.get_pgpass_path(remoteServer)
            if remoteServer is None:
                pgpassContent = open(pgpassPath).read()
            else:
                errortext = self.check_remote_server(remoteServer)
                if errortext == "":
                    opt = RemoteOpt(remoteServer.host, remoteServer.port, remoteServer.username, remoteServer.passwd)
                    opt.init_server_connect()
                    pgpassContent, errortext = opt.exec_command("cat %s" % pgpassPath)
        except Exception as e:
            errortext = "get_pass_conetnt(): " + str(e)
        return pgpassContent, errortext

    #写本地pgpass文件
    def write_local_pgpass(self, pgpassConf):
        errorText = ""
        try:
            record = "%s:%d:%s:%s:%s\n" % (pgpassConf.host, pgpassConf.port, pgpassConf.db, pgpassConf.username, pgpassConf.passwd)

            pgpassPath = self.get_pgpass_path()
            if not os.path.exists(pgpassPath): open(pgpassPath, "a+")
            content = open(pgpassPath).read()

            #检查记录是否已经存在
            if content != "" and content.find(record[:-1]) != -1: return "record already exist!"

            #写记录到文件
            if content != "" and content[-1] != "\n": record = "\n" + record
            open(pgpassPath, "a+").write(record)
        except Exception as e:
            errorText = "write_local_pgpass(): " + str(e)
        return errorText

    #写远程pgpass文件
    def write_remote_pgpass(self, remoteServer, pgpassConf):
        errorText = ""
        try:
            errorText = self.check_remote_server(remoteServer)
            if errorText != "": return errorText

            # init remote sever
            opt = RemoteOpt(remoteServer.host, remoteServer.port, remoteServer.username, remoteServer.passwd)
            opt.init_server_connect()

            #make record
            record = "%s:%d:%s:%s:%s" % (pgpassConf.host, pgpassConf.port, pgpassConf.db, pgpassConf.username, pgpassConf.passwd)

            #file check
            pgpassPath = self.get_pgpass_path(remoteServer)
            stdout, stderr = opt.exec_command("ls -l %s" % pgpassPath)
            if stdout == "":
                stdout, stderr = opt.exec_command("touch %s" % pgpassPath)
                stdout, stderr = opt.exec_command("chmod 0600 %s" % pgpassPath)
                if stderr != "": return stderr

            #record check
            stdout, stderr = opt.get_file_content(pgpassPath)
            if stderr != "": return stderr
            if stdout.find(record[:-1]) != -1: return "record already exist!"

            #write record
            stdout, stderror = opt.exec_command('echo "%s" >> %s' % (record, pgpassPath))
            errorText = stderror
        except Exception as e:
            errorText = "write_remote_pgpass(): " + str(e)
        return errorText

    #备份文件检查
    def restoreCheck(self, dataPath):
        errorText = ""
        if not os.path.exists(dataPath):
            errorText = ("目录:%s 不存在" % dataPath)
            return errorText

        for db in self.db:
            filePath = (dataPath + "/" + db + ".gz")
            if not os.path.exists(filePath):
                errorText = ("文件:%s 不存在" % filePath)
                return errorText

        return errorText

    #本地执行shell命令
    def exec_command(self, sql):
        result = subprocess.Popen(sql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        stdout = result.stdout.read().decode("gbk")
        stderr = result.stderr.read().decode("gbk")
        return stdout, stderr

    #获取配置中的主机
    @staticmethod
    def getHost():
        errorText = ""
        hostList = []
        try:
            confJson = json.loads(open("config.json").read())
            for hostRcord in confJson["hosts"]:
                host = hostRcord["host"]
                hostList.append(host)
        except Exception as e:
            errorText = ("解析配置出错, error: " + str(e))
        return hostList, errorText

    #获取配置中的数据库
    @staticmethod
    def getDB():
        errorText = ""
        dbList = []
        try:
            confJson = json.loads(open("config.json").read())
            for dbRcord in confJson["databases"]:
                db = dbRcord["db"]
                dbList.append(db)
        except Exception as e:
            errorText = ("解析配置出错, error: " + str(e))
        return dbList, errorText

if __name__ == "__main__":
    dbBackup = DatabaseBackup(host = "172.16.34.16", port = 5432, db = ["rtp"], home = r"./pg_backup/172.16.34.16")
    remoteHost = "192.168.34.203"
    remotePort = 22
    username = "postgres"
    passwd = "postgres"
    content = open(r"C:\Users\ouru\AppData\Roaming\postgresql\pgpass.conf").read()
    dbBackup.check_pgpass(content)