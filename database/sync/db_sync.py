import sys, os
import json
import getpass
from datetime import datetime
from enum import Enum
import subprocess

class NodeType(Enum):
    table = 1
    field = 2
    constraints = 3

class ConstraintsLevel(Enum):
    row = 1
    table = 2

class OptionType(Enum):
    add = 1
    modify = 2
    delete = 3

class DBSync:
    def __init__(self):
        self.hostList = []
        self.dbList = []
        self.userList = []

        self.host = None
        self.port = None
        self.user = None
        self.passwd = None
        self.parse_config()

        self.dataFile = "data.json"

    def parse_config(self):
        confJson = json.loads(open("config.json").read())
        try:
            [self.hostList.append(host) for host in confJson["hosts"]]

            [self.dbList.append(db) for db in confJson["databases"]]

            [self.userList.append(user) for user in confJson["users"]]

            errorText = None
        except Exception as e:
            errorText = str(e)
        return errorText

    def set_info(self, **kwargs):
        info = kwargs.get("host")
        if info: self.host = info

        info = kwargs.get("port")
        if info: self.port = info

        info = kwargs.get("user")
        if info: self.user = info

        info = kwargs.get("passwd")
        if info: self.passwd = info

        self.add_pgpass()

    def add_pgpass(self):
        user = getpass.getuser()
        path = "C:/Users/%s/AppData/Roaming/postgresql/pgpass.conf" % user
        record = "%s:%d:*:%s:%s\n" % (self.host, self.port, self.user, self.passwd)
        with open(path, "a+") as fileObj:
            fileObj.seek(0)
            text = fileObj.read()
            fileObj.seek(2)
            if text.find(record) == -1:
                fileObj.write(record)

    def clear_data_file(self):
        if os.path.exists(self.dataFile):
            os.remove(self.dataFile)

    def add_create_table(self, db, table):
        sql = "create table {table}();".format(table=table)
        self.write_data(NodeType.table, {
            "db" : db,
            "sql" : sql,
        })

    def add_drop_table(self, db, table):
        sql = "drop table {table};".format(table=table)
        self.write_data(NodeType.table, {
            "db": db,
            "sql": sql,
        })

    def table_field_options(self, **kwargs):
        db = kwargs.get("db")
        # table = kwargs.get("table")
        # field = kwargs.get("field")
        # type = kwargs.get("type")
        # constraints = kwargs.get("constraints")
        option = kwargs.get("option")

        if option == OptionType.add:
            sql = "ALTER TABLE {table} ADD COLUMN {field} {type} {constraints};".format(**kwargs)
        elif option == OptionType.modify:
            sql = ""
        elif option == OptionType.delete:
            sql = "ALTER TABLE {table} DROP COLUMN {field};".format(**kwargs)
        else:
            sql = ""

        self.write_data(NodeType.field, {
            "db" : db,
            "sql" : sql,
        })

    def make_constraints(self, **kwargs):
        db = kwargs.get("db")
        # table = kwargs.get("table")
        # field = kwargs.get("field")
        # constraintsName = kwargs.get("name")
        # constraints = kwargs.get("constraints")
        level = kwargs.get("level")
        option = kwargs.get("option")

        if option == OptionType.add:
            if level == ConstraintsLevel.row:
                sql = "ALTER TABLE {table} ALTER COLUMN {field} SET {constraints};".format(**kwargs)
            else:
                sql = "ALTER TABLE {table} ADD CONSTRAINT {name} {constraints};".format(**kwargs)
        elif option == OptionType.modify:
            pass
        elif option == OptionType.delete:
            if level == ConstraintsLevel.row:
                sql = "ALTER TABLE {table} ALTER COLUMN {field} DROP {constraints};".format(**kwargs)
            else:
                sql = "ALTER TABLE {table} DROP CONSTRAINT {name};".format(**kwargs)
        else:
            sql = ""

        self.write_data(NodeType.constraints, {
            "db" : db,
            "sql" : sql,
        })

    def write_data(self, nodeType, data):
        if os.path.exists(self.dataFile) and os.path.getsize(self.dataFile):
            with open(self.dataFile, "r") as fileObj:
                context = json.load(fileObj)
        else:
            context = {}

        if nodeType == NodeType.table:
            context["table"] = [data] if "table" not in context else context["table"].append(data)
        elif nodeType == NodeType.field:
            context["field"] = [data] if "field" not in context else context["field"].append(data)
        elif nodeType == NodeType.constraints:
            context["constraints"] = [data] if "constraints" not in context else context["constraints"].append(data)

        with open(self.dataFile, "w") as fileObj:
            json.dump(context, fileObj, indent=4)

    def sync_database(self, msgSignal):
        if not self.host: raise ValueError("主机为空!")
        if not self.port: raise ValueError("端口为空!")
        if not self.user: raise ValueError("用户为空!")
        if not self.passwd: raise ValueError("密码为空!")
        if not os.path.exists(self.dataFile): raise ValueError("数据文件不存在!")

        msgSignal.emit("clear")

        with open(self.dataFile, "r") as fileObj:
            context = json.load(fileObj)

        if "table" in context:
            [self.exec_sql(record["db"], record["sql"], msgSignal) for record in context["table"]]

        if "field" in context:
            [self.exec_sql(record["db"], record["sql"], msgSignal) for record in context["field"]]

        if "constraints" in context:
            [self.exec_sql(record["db"], record["sql"], msgSignal) for record in context["constraints"]]

    def exec_sql(self, db, sql, msgSignal):
        cmd = 'psql -h {host} -p {port} -U {user} -d {db} -c "{sql}"'.format(
            host = self.host,
            port = self.port,
            user = self.user,
            db = db,
            sql= sql
        )
        print(cmd)
        result = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        error = result.stderr.read().decode("gbk")
        if error:
            error = "[ERROR]\nDB:{db}\nSQL:{sql}\n{error}".format(db=db, sql=sql, error=error)
            msgSignal.emit(error)

if __name__ == "__main__":
    dbSync = DBSync()
    dbSync.add_create_table("postgres", "ouru")