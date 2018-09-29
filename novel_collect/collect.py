import os, sys, re
import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime, timedelta

from parseConfig import ParseConfig
from novelLog import logger
from public.mysqlV1 import MysqlManager
from public.myEmail import MyEmail
import threading, time
from utils import send_sms


class Collect:
    def __init__(self, configFile="config.json"):
        self.load_config(configFile)
        self.init_database()
        self.init_email()
        self.init_novel()

    def load_config(self, configFile):
        logger.info("load_config() start...")
        try:
            self.config = ParseConfig(configFile)
            logger.info("load_config() success.")
        except Exception as e:
            logger.error("load_config() failed, error:{0}".format(e))
            sys.exit(-1)

    def init_database(self):
        logger.info("init_database() start...")
        try:
            self.mydb = MysqlManager(**self.config.database)
            logger.info("init_database() success.")
        except Exception as e:
            logger.error("init_database() failed, error:{0}".format(e))
            sys.exit(-1)

    def init_email(self):
        logger.info("init_email() start...")
        try:
            smtpServer = self.config.email.get("smtp_server")
            sender = self.config.email.get("sender")
            password = self.config.email.get("sender_passwd")
            charset = self.config.email.get("charset")
            self.myemail = MyEmail(smtpServer=smtpServer, sender=sender, senderPasswd=password, charset=charset)
            logger.info("init_email() success.")
        except Exception as e:
            logger.error("init_email() failed, error:{0}".format(e))
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
            logger.error("init_novel() failed, error:{0}".format(e))
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
        if result[0].get("nums"): return  # 已保存的小说直接返回

        sql = '''
        insert into tb_novel(novel_name, site_name, url, add_time)
        values('{0}', '{1}', '{2}', now())
        '''.format(novelName, siteName, url)
        self.mydb.execute(sql)

    def show_config(self):
        logger.info(self.config.show_config())

    def reset_config(self, confPath="config.json"):
        logger.info("reload config....")
        self.load_config(confPath)
        self.init_database()
        self.init_email()
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
        parserName = self.config.get_parser_name(novel.get("parser"))

        logger.info("collect [{0}] by [{1}] start...".format(novelName, parserName))
        time_start = time.time()

        try:
            chapterTable = self.get_chapter_table(novelName)
            self.save_chapter(novel, chapterTable)
        except Exception as e:
            logger.error("{0}:parse_novel_thread({1}) failed, error:{2}".format(parserName, novelName, e))
        finally:
            time_end = time.time()
            logger.info("collect [{}] finish. 耗时:{}".format(novelName, time_end - time_start))

    def get_chapter_table(self, novelName):
        sql = "select id from tb_novel where novel_name = '{}'".format(novelName)
        result = self.mydb.execute(sql)
        novelId = result[0].get("id")

        tableName = "tb_chapter_{}".format(novelId % 10)
        return tableName

    def parse_test(self, novel):
        result = False
        try:
            url = novel.get("url")
            charset = novel.get("charset", "gbk")
            name = novel.get("name")
            parserName = self.config.get_parser_name(novel.get("parser"))

            sql = "select count(*) as num from tb_novel where url = '{}'".format(url)
            result = self.mydb.execute(sql)

            if not result[0].get("num"):
                err = self.config.parsers[parserName].parse_test(url, encoding=charset)
                if not err:
                    result = True
                else:
                    logger.error(err)
        except Exception as e:
            logger.error("{0}:parse_test({1}) error:{2}".format(parserName, name, e))
        return result

    def update_notice(self, novelId, novelName):
        '''更新通知'''
        try:
            sql = "select user_id from tb_user_fav where novel_id = {0} and notice_enable = 1".format(novelId)
            result = self.mydb.execute(sql)
            for r in result:
                userId = r.get("user_id")
                sql = "select username, email, mobile from tb_user_profile where id = {0}".format(userId)
                r = self.mydb.execute(sql)
                username = r[0].get("username")
                email = r[0].get("email")
                mobile = r[0].get("mobile")

                content = "[天天悦读]你收藏的小说({0}), 已经更新了.".format(novelName)
                if email:
                    self.myemail.set_receiver([email])
                    subject = "小说更新通知"
                    stderr = self.myemail.send_email(subject, content)
                    if stderr:
                        logger.error("send email to [{0}] failed:{1}".format(username, stderr))
                    else:
                        logger.info("send email to [{0}] success.".format(username))
                elif mobile:
                    send_sms(mobile, novelName)
                    logger.info("semd sms to [{0}] success.".format(username))
                else:
                    message = "[天天悦读]你收藏的小说({0}), 已经更新了.".format(novelName)
                    sql = '''
                    insert into tb_user_message(message, user_id, is_read, add_time)
                    values('{0}', {1}, 0, now())
                    '''.format(content, userId)
                    self.mydb.execute(sql)
                    logger.info("write message to [{0}] success.".format(username))

        except Exception as e:
            logger.error("update_notice({0}) error:{1}\n".format(novelName, str(e)))

    def save_chapter(self, novel, table):
        '''保存章节信息'''
        url = novel.get("url")
        novelName = novel.get("name")
        charset = novel.get("charset")
        parserName = self.config.get_parser_name(novel.get("parser"))

        try:
            sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
            result = self.mydb.execute(sql)
            novelId = result[0].get("id")

            urls = self.get_all_chapter_url(table, novelId)

            has_update = False
            parser = self.config.parsers.get(parserName)
            for chapter in parser.parse_chapter(url, encoding=charset):
                if chapter[0] in urls: continue
                has_update = True
                sql = '''
                insert into {table}(novel_id, chapter_url, chapter_index, chapter_name, add_time)
                values ({id}, '{url}', {index}, '{name}', now())
                '''.format(table=table, id=novelId, url=chapter[0], index=self.get_chapter_index(chapter[0]),
                           name=chapter[1])
                self.mydb.execute(sql)
                logger.info("save [{}({})] to [{}] success.".format(novelName, chapter[1], table))

            if has_update:
                self.update_notice(novelId, novelName)
        except Exception as e:
            raise RuntimeError("\n save_chapter({0}) error:{1}".format(novelName, e))

    def get_all_chapter_url(self, table, novelId):
        sql = "select chapter_url from {0} where novel_id = {1}".format(table, novelId)
        result = self.mydb.execute(sql)
        if not result:
            return []

        urls = [dbout.get("chapter_url") for dbout in result if dbout.get("chapter_url")]
        return urls

    def get_chapter_index(self, chapterUrl):
        pos = chapterUrl.rfind("/")
        chapterIndex = re.match(r"\d+", chapterUrl[pos + 1:]).group()
        return int(chapterIndex)

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(10 * 60)


if __name__ == "__main__":
    collect = Collect()
    collect.run()
