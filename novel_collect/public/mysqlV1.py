import pymysql
from DBUtils.PooledDB import PooledDB

class Singleton(object):
    _instance = None
    def __init__(self):
        pass

    def __new__(cls, *args, **kwargs):
        if Singleton._instance is None:
            Singleton._instance = super(Singleton, cls).__new__(cls)
        return Singleton._instance

class MysqlManager(Singleton):
    pool = None
    def __init__(self, host="localhost", port=3306, user="root", passwd="123456", db="mysql", charset="utf8",
                 cursorclass=pymysql.cursors.DictCursor):
        MysqlManager.pool = PooledDB(creator=pymysql, maxconnections=10, host=host, port=port, user=user, passwd=passwd,
                                db=db, charset=charset, cursorclass=cursorclass)

    @staticmethod
    def execute(sql):
        conn = MysqlManager.pool.connection()
        cur = conn.cursor()

        try:
            cur.execute(sql)
            result =cur.fetchall()
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise RuntimeError("\n sql[{0}]执行出错:{1}".format(sql, str(e)))
        finally:
            conn.close()
            cur.close()
        return result

    @staticmethod
    def insert(table, **kwargs):
        keys = []
        values = []
        for key, value in kwargs.items():
            keys.append(key)
            values.append("'{0}'".format(value) if type(value) not in [int, float] else str(value))
        sql = "insert into {0}({1}) values({2})".format(table, ",".join(keys), ",".join(values))
        MysqlManager.execute(sql)

if __name__ == "__main__":
    mysqldb = MysqlManager(host="localhost")
    from datetime import datetime
    data = {
        "id" : 10004,
        "name" : "xiaoqiang",
        "age" : 30,
        "add_time" : datetime.now(),
    }
    mysqldb.insert("student", **data)

    # sql = "select * from student"
    # result = mysqldb.execute(sql)
    # print([r for r in result])