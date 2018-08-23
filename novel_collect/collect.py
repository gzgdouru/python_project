import os, sys
from parseConfig import ParseConfig
from novelLog import logger
from mysqlV1 import MysqlManager
import threading, time
import requests
from bs4 import BeautifulSoup
import json
from parser import Parser

class Collect:
    def __init__(self, configFile="config.json"):
        self.config = ParseConfig(configFile)
        self.init_database()
        self.init_novel()

    def init_database(self):
        logger.info("init_database() start...")
        try:
            self.mydb = MysqlManager(**self.config.database)
            logger.info("init_database() success.")
        except Exception as e:
            logger.error("init_database() failed, error:{}".format(str(e)))
            sys.exit(-1)

    def init_novel(self):
        logger.info("init_novel() start...")
        try:
            self.check_main_table()
            self.check_chapter_table()

            for novel in self.config.novels[:]:
                url = novel.get("url")
                novelName = novel.get("name")

                # 不能解析的网页不添加到数据库
                if not self.parse_test(novel):
                    logger.info("{}({})不能解析, 请选择另外的网站, 首选顶点小说, 次选笔趣阁!".format(novelName, url))
                    self.config.novels.remove(novel)
                    continue
                else:
                    self.save_novel_info(novel)

            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init_novel() failed, error:{}".format(str(e)))
            sys.exit(-1)

    def check_main_table(self):
        # 检查 tb_novel_category 表是否存在
        sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='tb_novel_category'"
        result = self.mydb.execute(sql)
        if not result: raise RuntimeError("表数据表[tb_novel_category]不存在")

        # 检查 tb_novel 表是否存在
        sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='tb_novel'"
        result = self.mydb.execute(sql)
        if not result: raise RuntimeError("表数据表[tb_novel]不存在")

    def check_chapter_table(self):
        for i in range(10):
            tableName = "tb_chapter_{}".format(i)
            sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='{}'".format(
                tableName)
            result = self.mydb.execute(sql)
            if not result: raise RuntimeError("数据表[{}]不存在!".format(tableName))
        return True

    def save_novel_info(self, novel):
        novelName = novel.get("name")
        siteName = novel.get("site_name")
        url = novel.get("url")

        sql = "select count(*) as nums from tb_novel where novel_name = '{0}'".format(novelName)
        result = self.mydb.execute(sql)
        if result[0].get("nums"): return    #已保存的小说直接返回

        sql = '''
        insert into tb_novel(novel_name, site_name, url, add_time)
        values('{0}', '{1}', '{2}', now())
        '''.format(novelName, siteName, url)
        self.mydb.execute(sql)

    def show_config(self):
        logger.info(json.dumps(self.config.data, indent=2, ensure_ascii=False))

    def reset_config(self, confPath="config.json"):
        logger.info("reload config....")
        self.config = ParseConfig(confPath)
        self.init_database()
        self.init_novel()
        self.parse_novel()

    def parse_novel(self):
        for novel in self.config.novels:
            thread = threading.Thread(target=self.parse_novel_thread, args=(novel,))
            thread.setDaemon(True)
            thread.start()

    def parse_novel_thread(self, novel):
        if not novel.get("status"): return None  # 不启动解析直接返回
        novelName = novel.get("name")
        url = novel.get("url")
        logger.info("collect [{}] start.".format(novelName))
        time_start = time.time()

        try:
            chapters = Parser(url, encoding="gbk").parse_chapter()
            chapterTable = self.get_chapter_table(novelName)
            self.save_chapter(novelName, chapterTable, chapters)
        except Exception as e:
            logger.error("parse_novel_thread() failed, error:{}".format(str(e)))
        finally:
            time_end = time.time()
            logger.info("collect [{}] finish. 耗时:{}".format(novelName, time_end-time_start))

    def get_chapter_table(self, novelName):
        sql = "select id from tb_novel where novel_name = '{}'".format(novelName)
        result = self.mydb.execute(sql)
        novelId = result[0].get("id")

        tableName = "tb_chapter_{}".format(novelId % 10)
        return tableName

    def parse_test(self, novel):
        result = True
        try:
            url = novel.get("url")
            sql = "select count(*) as num from tb_novel where url = '{}'".format(url)
            result = self.mydb.execute(sql)

            if not result[0].get("num"):
                result = True if Parser(url, encoding="gbk").parse_chapter() else False
        except Exception as e:
            logger.error("->parse_test({}) error:{}".format(novel.get("name"), str(e)))
            result = False
        return result

    def save_chapter(self, novelName, table, chapters):
        try:
            sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
            result = self.mydb.execute(sql)
            novelId = result[0].get("id")

            urls = self.get_all_chapter_url(table, novelId)

            for chapter in chapters:
                if chapter[0] in urls: continue

                sql = '''
                insert into {table}(novel_id, chapter_url, chapter_name, add_time)
                values ({id}, '{url}', '{name}', now())
                '''.format(table=table, id=novelId, url=chapter[0], name=chapter[1])
                self.mydb.execute(sql)
                logger.info("save [{}({})] to [{}] success.".format(novelName, chapter[1], table))
        except Exception as e:
            raise RuntimeError("save_chapter() error:{}".format(str(e)))

    def get_all_chapter_url(self, table, novelId):
        sql = "select chapter_url from {0} where novel_id = {1}".format(table, novelId)
        result = self.mydb.execute(sql)
        if not result: return []

        urls = [dbout.get("chapter_url") for dbout in result if dbout.get("chapter_url")]
        return urls

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(30 * 60)

if __name__ == "__main__":
    collect = Collect()
    collect.run()