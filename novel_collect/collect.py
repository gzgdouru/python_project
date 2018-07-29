import os, sys
from parseConfig import ParseConfig
from novelLog import logger
from mysql_ex import MysqlManager
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
            self.make_main_table()
            self.make_chapter_table()

            for novel in self.config.novels[:]:
                category = novel.get("category")
                url = novel.get("url")
                novelName = novel.get("name")

                # 不能解析的网页不添加到数据库
                if not self.parse_test(novel):
                    logger.info("{}({})不能解析, 请选择另外的网站, 首选顶点小说, 次选笔趣阁!".format(novelName, url))
                    self.config.novels.remove(novel)
                    continue

                self.save_category(category)
                self.save_novel_info(novel)
            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init_novel() failed, error:{}".format(str(e)))
            sys.exit(-1)

    def make_main_table(self):
        try:
            # 创建 tb_category 表
            sql = '''
                   create table if NOT EXISTS tb_category(
                   id int auto_increment primary key,
                   name varchar(64) UNIQUE 
                   )
                   '''
            result = self.mydb.execute(sql)
            if not result[0]: raise RuntimeError("make_main_table() failed!->")

            # 创建 tb_novel 表
            sql = '''
            create table if NOT EXISTS tb_novel(
            id int auto_increment primary key,
            novel_name varchar(255) unique,
            site_name varchar(255),
            author VARCHAR(64),
            category_id int,
            url varchar(255) unique,
            KEY idx_novel_name (novel_name),
            foreign key (category_id) references tb_category(id) on delete cascade on update cascade
            )
            '''
            result = self.mydb.execute(sql)
            if not result[0]: raise RuntimeError("make_main_table() failed!->")
        except Exception as e:
            raise RuntimeError("make_main_table() error:{}|".format(str(e)))

    def make_chapter_table(self):
        try:
            for i in range(10):
                tableName = "tb_chapter_{}".format(i)

                sql = "select count(*) as table_count from information_schema.TABLES " \
                      "WHERE table_schema='novel_collect' and table_name ='{}'".format(tableName)
                res, dbout = self.mydb.execute(sql)
                if dbout[0].get("table_count"): continue

                sql = '''
                create table {0}(
                id int auto_increment primary key,
                novel_id int,
                chapter_url varchar(255) unique,
                chapter_name varchar(255),
                KEY idx_novel_id (novel_id),
                foreign key (novel_id) references tb_novel(id) on delete cascade on update cascade
                )
                '''.format(tableName)
                res, dbout = self.mydb.execute(sql)
                if not res: raise RuntimeError("create {} failed!".format(tableName))
        except Exception as e:
            raise RuntimeError("make_chapter_table() error:{}|".format(str(e)))

    def save_category(self, category):
        sql = '''
        insert into tb_category(name)
        select '{0}' from dual
        where not EXISTS (select 1 from tb_category where name = '{0}')
        '''.format(category)
        result = self.mydb.execute(sql)
        if not result[0]: raise RuntimeError("save_category() failed!")

    def get_category_id(self, category):
        sql = "select id from tb_category where name = '{}'".format(category)
        result = self.mydb.execute(sql)
        return result[1][0].get("id")

    def save_novel_info(self, novel):
        novelName = novel.get("name")
        siteName = novel.get("site_name")
        url = novel.get("url")
        author = novel.get("author")
        category = novel.get("category")
        categoryId = self.get_category_id(category)

        sql = '''
        insert into tb_novel(novel_name, site_name, author, category_id, url)
        select '{0}', '{1}', '{2}', {3}, '{4}' from dual
        where NOT EXISTS (select 1 from tb_novel where novel_name = '{0}')
        '''.format(novelName, siteName, author, categoryId, url)
        result = self.mydb.execute(sql)
        if not result[0]: raise RuntimeError("save_novel_info() failed!")

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
        novelId = result[1][0].get("id")

        tableName = "tb_chapter_{}".format(novelId % 10)
        return tableName

    def parse_test(self, novel):
        result = True
        try:
            url = novel.get("url")
            sql = "select count(*) as num from tb_novel where url = '{}'".format(url)
            result = self.mydb.execute(sql)

            if not result[1][0].get("num"):
                result = True if Parser(url, encoding="gbk").parse_chapter() else False
        except Exception as e:
            logger.error("->parse_test({}) error:{}".format(novel.get("name"), str(e)))
            result = False
        return result

    def save_chapter(self, novelName, table, chapters):
        try:
            sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
            res, dbout = self.mydb.execute(sql)
            novelId = dbout[0].get("id")

            urls = self.get_all_chapter_url(table, novelId)

            for chapter in chapters:
                if chapter[0] in urls: continue

                sql = '''
                insert into {table}(novel_id, chapter_url, chapter_name)
                values ({id}, '{url}', '{name}')
                '''.format(table=table, id=novelId, url=chapter[0], name=chapter[1])
                self.mydb.execute(sql)
                logger.info("save [{}({})] to [{}] success.".format(novelName, chapter[1], table))
        except Exception as e:
            raise RuntimeError("save_chapter() error:{}".format(str(e)))

    def get_all_chapter_url(self, table, novelId):
        sql = "select chapter_url from {} where novel_id = {}".format(table, novelId)
        result = self.mydb.execute(sql)
        urls = [dbout.get("chapter_url") for dbout in result[1] if dbout.get("chapter_url")]
        return urls

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(30 * 60)

if __name__ == "__main__":
    collect = Collect()
    collect.run()