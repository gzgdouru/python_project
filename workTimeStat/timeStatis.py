import sys
from PyQt5.QtWidgets import QMessageBox
from datetime import datetime, time as dtime
import yaml

from mysql_ex import MysqlManager


class TimeStatis:
    def __init__(self, configFile="config.yaml"):
        self.configFile = configFile
        self.parseConfig()
        self.init_db()

    def parseConfig(self):
        context = yaml.load(open(self.configFile, mode="r", encoding="utf-8"))

        #database setting
        dbNode = context.get("DATABASE")
        self.host = dbNode.get("host", "193.112.150.18")
        self.port = dbNode.get("port", 3306)
        self.user = dbNode.get("user", "ouru")
        self.password = dbNode.get("password", "!@#test1992...")
        self.dbName = dbNode.get("db_name", "novel")
        self.charset = dbNode.get("charset", "utf-8")

        #server setting
        serverNode = context.get("SERVER")
        self.username = serverNode.get("username", "ouru")
        self.isPopup = serverNode.get("is_popup", 0)
        self.popupTime = serverNode.get("popup_time", 1)

    def init_db(self):
        self.mysqldb = MysqlManager(host=self.host, port=self.port, user=self.user, passwd=self.password, db=self.dbName, charset=self.charset)

        sql = '''
            create table if NOT EXISTS tb_work_time_stat(
             id int auto_increment primary key,
             name varchar(20),
             start_time datetime,
             end_time datetime,
             duration time
            )'''
        self.mysqldb.execute(sql)

    def getDiffTime(self, timeStart):
        timeDiff = (datetime.now() - timeStart).seconds
        seconds = timeDiff % 60
        minutes = timeDiff // 60
        hours = timeDiff // 3600
        return dtime(hour=hours, minute=minutes, second=seconds)
        # return "{0:02d}:{1:02d}:{2:02d}".format(hours, minutes, seconds)

    def save_work_time(self, timeStart, duration):
        sql = '''
        INSERT into tb_work_time_stat(name, start_time, end_time, duration)
        values('{0}', '{1}', now(), '{2}') 
        '''.format(self.user, timeStart, duration)
        self.mysqldb.execute(sql)

    def parse_time(self, timeStr):
        timeList = timeStr.split(":")
        return dtime(hour=int(timeList[0]), minute=int(timeList[1]), second=int(timeList[2]))

if __name__ == "__main__":
    timeStatis = TimeStatis()
    print(timeStatis.getDiffTime(datetime.now()))
