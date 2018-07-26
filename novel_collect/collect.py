import os, sys
from parseConfig import ParseConfig
from novelLog import logger
from mysql_ex import MysqlManager
import threading, time
import requests
from bs4 import BeautifulSoup
import zlib

class Collect:
    def __init__(self, configFile="config.json"):
        self.config = ParseConfig(configFile)
        self.init_database()
        self.init_novel()

    def init_database(self):
        try:
            self.mydb = MysqlManager(**self.config.database)
            logger.info("init_database() success.")
        except Exception as e:
            logger.error("init_database() failed, error:{}".format(str(e)))
            sys.exit(-1)

    def init_novel(self):
        try:
            self.make_main_table()
            self.make_chapter_table()

            for novel in self.config.novels:
                novelName = novel.get("name")
                siteName = novel.get("site_name")
                url = novel.get("url")
                chapterTable = novel.get("chapter_table")

                sql = "select count(*) as num from tb_novel where novel_name = '{}'".format(novelName)
                result = self.mydb.execute(sql)
                if result[1][0].get("num"): continue

                sql = '''
                insert into tb_novel(novel_name, site_name, url, chapter_table)
                values('{}', '{}', '{}', '{}')
                '''.format(novelName, siteName, url, chapterTable)
                self.mydb.execute(sql)

            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init_novel() failed, error:{}".format(str(e)))
            sys.exit(-1)

    def make_main_table(self):
        sql = "select count(*) as table_count from information_schema.TABLES " \
              "WHERE table_schema='novel_collect' and table_name ='tb_novel'"
        res, dbout = self.mydb.execute(sql)
        if dbout[0].get("table_count"): return True

        sql = '''
        create table tb_novel(
        id int auto_increment primary key,
        novel_name varchar(255) unique,
        site_name varchar(255),
        url varchar(255) unique,
        chapter_table varchar(64) unique
        )
        '''
        res, dbout = self.mydb.execute(sql)
        if not res: raise RuntimeError("make_main_table() failed!")

    def make_chapter_table(self):
        for novel in self.config.novels[:]:
            chapterTable = novel.get("chapter_table")
            if not chapterTable: self.config.novels.remove(novel) #不解析没有配置表名的小说

            sql = "select count(*) as table_count from information_schema.TABLES " \
                  "WHERE table_schema='novel_collect' and table_name ='{}'".format(chapterTable)
            res, dbout = self.mydb.execute(sql)
            if dbout[0].get("table_count"): continue

            sql = '''
            create table {0}(
            id int auto_increment primary key,
            novel_id int,
            chapter_url varchar(255) unique,
            chapter_name varchar(255),
            foreign key (novel_id) references tb_novel(id) on delete cascade on update cascade
            )
            '''.format(chapterTable)
            res, dbout = self.mydb.execute(sql)
            if not res: raise RuntimeError("create {} failed!".format(chapterTable))

    def parse_novel(self):
        for novel in self.config.novels:
            thread = threading.Thread(target=self.parse_novel_thread, args=(novel,))
            thread.setDaemon(True)
            thread.start()

    def parse_novel_thread(self, novel):
        try:
            if not novel.get("status"): return None #不启动解析直接返回
            novelName = novel.get("name")
            url = novel.get("url")
            chapterTable = novel.get("chapter_table")

            chapters = self.default_parse(url)
            self.save_chapter(novelName, chapterTable, chapters)
        except Exception as e:
            logger.error("parse_novel_thread() failed, error:{}".format(str(e)))

    def default_parse(self, url):
        try:
            chapters = []
            tmpList = []
            respon = requests.get(url, headers={
                'user-agent': 'Mozilla/5.0'
            }, timeout=10)
            respon.encoding = "gbk"
            html = respon.text
            soup = BeautifulSoup(html, "html.parser")
            subNode = soup.body.dl
            for child in subNode.children:
                try:
                    pos = child.a["href"].rfind(r"/")
                    chapterUrl = "{0}{1}".format(url, child.a["href"][pos+1:])
                    charpterName = child.a.string

                    # 去掉重复更新的章节
                    if chapterUrl not in tmpList:
                        chapters.append((chapterUrl, charpterName))
                        tmpList.append(chapterUrl)
                except:
                    pass
        except Exception as e:
            logger.error("parse url:{0} failed, error:{1}".format(url, str(e)))
            chapters = None
        return chapters

    def save_novel(self, novel):
        pass

    def save_chapter(self, novelName, table, chapters):
        try:
            sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
            res, dbout = self.mydb.execute(sql)
            novelId = dbout[0].get("id")

            for chapter in chapters[::-1]:
                sql = "select count(*) as num from {0} where chapter_url = '{1}'".format(table, chapter[0])
                res, dbout = self.mydb.execute(sql)
                if dbout[0].get("num"):  # 该章节已存在， 则代表其前面的章节已经保存到数据库中了， 直接退出
                    logger.info("{}-{} is already exist".format(novelName, chapter[1]))
                    break

                # content = self.default_parse_content(chapter[0])
                # if not content: break   #章节内容还在手打中 下次运行再从新解析

                sql = '''
                insert into {table}(novel_id, chapter_url, chapter_name)
                values ({id}, '{url}', '{name}')
                '''.format(table=table, id=str(novelId), url=chapter[0], name=chapter[1])
                self.mydb.execute(sql)
                logger.info("save {}-{} success.".format(novelName, chapter[1]))
        except Exception as e:
            raise RuntimeError("save_chapter() error:{}".format(str(e)))

    def default_parse_content(self, url):
        content = None
        try:
            respon = requests.get(url, headers={
                'user-agent': 'Mozilla/5.0'
            }, timeout=30)
            respon.encoding = "gbk"
            html = respon.text
            soup = BeautifulSoup(html, "html.parser")
            contentNode = soup.find(id="content")
            if contentNode.text: content = str(contentNode)
        except Exception as e:
            raise RuntimeError("default_parse_content():{}".format(str(e)))
        return content

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(30 * 60)

if __name__ == "__main__":
    collect = Collect()
    collect.run()