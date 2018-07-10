#coding:utf-8
import os, sys
import threading

opt = {}
bk_path = r"f:/pgsql/pg_backup"
host = "192.168.232.130"
port = 5432
db = ["ajb_shop_monitor", "push", "rtp", "rtsp", "upgrade"]
table_data_dir = r"f:/pgsql/pg_table_data_backup"
table_struct_dir = r"f:/pgsql/pg_table_struct_backup"
operation = sys.argv[1] if len(sys.argv) > 1 else None
database = sys.argv[2] if len(sys.argv) > 2 else None
table = sys.argv[3] if len(sys.argv) > 3 else None
type = sys.argv[4] if len(sys.argv) > 4 else None
lock = threading.Lock()
threads = []

def single_database_backup(databaseName):
    sql = "pg_dump -h %s -p %s -U postgres -c %s | gzip >%s/%s.gz" % (host, port, databaseName, bk_path, databaseName)
    os.system(sql)
    with lock:
        print "db backup %s finish" % databaseName

#备份数据库
def database_backup(*args):
    print "database backup start........."

    if not os.path.exists(bk_path):
        os.mkdir(bk_path)

    for loop in db:
        #sql = "pg_dump -h %s -p %s -U postgres -c %s | gzip >%s/%s.gz" % (host, port, loop, bk_path, loop)
        #os.system(sql)
        #print "db backup %s finish" % loop
        thread = threading.Thread(target=single_database_backup, args=(loop,))
        thread.start()
        threads.append(thread)

    [thread.join() for thread in threads]
    print "database backup end........."

#数据库恢复
def database_restore(*args):
    print "restore database start........."

    for loop in db:
        sql = "cat %s/%s.gz | gunzip | psql -p %s %s" % (bk_path, loop, port, loop)
        os.system(sql)
        print "restore db %s finish" % loop

    print "restore database end........."

#表数据备份
def table_data_backup(*args):
    print "backup table data start........."

    if not os.path.exists(table_data_dir):
        os.mkdir(table_data_dir)

    for loop in db:
        sql = "pg_dump -h %s -p %s -U postgres -a %s > %s/%s.sql" % (host, port, loop, table_data_dir, loop)
        os.system(sql)
        print "backup table data by %s finish" % loop

    print "backup table data end..........."

#表结构备份
def table_struct_backup(*args):
    print "backup table struct start........."

    if not os.path.exists(table_struct_dir):
        os.mkdir(table_struct_dir)

    for loop in db:
        sql = "pg_dump -p %s -h %s -U postgres -s %s > %s/%s.sql" % (port, host, loop, table_struct_dir, loop)
        os.system(sql)
        print "backup table struct by %s finish" % loop

    print "backup table struct end........."

#单表备份
def single_table_backup(*args):
    if not os.path.exists(table_data_dir):
        os.mkdir(table_data_dir)

    if not os.path.exists(table_struct_dir):
        os.mkdir(table_struct_dir)

    if not os.path.exists(bk_path):
        os.mkdir(bk_path)

    #database = args[0]
    #table = args[1]
    #type = args[2]
    print "backup %s start........" % table

    if type == "data":
        sql = "pg_dump -p %s -h %s -U postgres -d %s -t %s -a > %s/%s.sql" % (port, host, database, table, table_data_dir, table)
    elif type == "struct":
        sql = "pg_dump -p %s -h %s -U postgres -d %s -t %s -s > %s/%s.sql" % (port, host, database, table, table_struct_dir, table)
    else:
        sql = "pg_dump -p %s -h %s -U postgres -d %s -t %s > %s/%s.sql" % (port, host, database, table, bk_path, table)

    os.system(sql)

    print "backup %s end........" % table

def init():
    opt["backup"] = database_backup
    opt["restore"] = database_restore
    opt["table_data_backup"] = table_data_backup
    opt["table_struct_backup"] = table_struct_backup
    opt["single_table_backup"] = single_table_backup

if __name__ == "__main__":
    init()
    func = opt.get(operation, None)

    if func == None:
        print "Not Supported operation!"
        print "Supports operation(backup, restore, table_data_backup, table_struct_backup, single_table_backup[database table {data,struct,all}] )"
    else:
        func(*(database, table, type))



