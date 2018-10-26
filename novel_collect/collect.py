import os, sys, re
import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime, timedelta
import threading, time
from concurrent import futures

from parseConfig import ParseConfig
from novelLog import logger
from utils.mysqlV1 import MysqlManager
from utils.myEmail import MyEmail
from utils.sms import send_sms
from dataStructures import EXCEPTION_PREFIX


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
                err = self.parse_test(novel)
                if err:
                    logger.info("小说[{0}({1})]解析测试失败, 原因:{2}".format(novelName, url, err))
                    self.config.novels.remove(novel)
                    continue
                else:
                    logger.info("小说[{0}]解析测试成功.".format(novelName))
                    self.save_novel_info(novel)

            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init_novel() failed, error:{0}".format(e))
            sys.exit(-1)

    def check_main_table(self):
        # 检查 tb_novel_category 表是否存在
        sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='tb_novel_category'"
        result = self.mydb.execute(sql)
        if not result: raise RuntimeError("{0}数据表[tb_novel_category]不存在".format(EXCEPTION_PREFIX))

        # 检查 tb_novel 表是否存在
        sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='tb_novel'"
        result = self.mydb.execute(sql)
        if not result: raise RuntimeError("{0}数据表[tb_novel]不存在".format(EXCEPTION_PREFIX))

    def check_chapter_table(self):
        for i in range(10):
            tableName = "tb_chapter_{}".format(i)
            sql = "select t.table_name from information_schema.TABLES t where t.TABLE_SCHEMA = 'novel_site' and t.TABLE_NAME ='{}'".format(
                tableName)
            result = self.mydb.execute(sql)
            if not result: raise RuntimeError("{0}数据表[{1}]不存在!".format(EXCEPTION_PREFIX, tableName))
        return True

    def save_novel_info(self, novel):
        url = novel.get("url")
        novelName = novel.get("name")
        parserName = self.config.get_parser_name(novel.get("parser"))
        parser = self.config.parsers.get(parserName)

        try:
            novelInfo = parser.parse_info(url, encoding="gbk", timeout=30)

            if not novelName or not novelInfo.author:
                return

            # 判断小说是否已经保存
            sql = "select count(*) as nums from tb_novel where novel_name = '{0}'".format(novelName)
            result = self.mydb.execute(sql)
            if result[0].get("nums"): return  # 已保存的小说直接返回

            # 获取作者ID
            sql = '''
            insert into tb_novel_author(name, intro, detail, add_time)
            values('{name}', '{intro}', '{detail}', now())
            on DUPLICATE KEY UPDATE name = '{name}'
            '''.format(name=novelInfo.author, intro=novelInfo.author, detail=novelInfo.author)
            self.mydb.execute(sql)
            sql = "select id from tb_novel_author where name = '{0}'".format(novelInfo.author)
            authorId = self.mydb.execute(sql)[0].get("id")

            #获取'其他'分类ID
            sql = '''
            insert into tb_novel_category(name, add_time)
            values('{name}', now())
            on duplicate key update name = '{name}'
            '''.format(name='其他')
            self.mydb.execute(sql)
            sql = "select id from tb_novel_category where name = '{0}'".format("其他")
            categoryId = self.mydb.execute(sql)[0].get("id")

            # 插入小说信息
            self.mydb.insert("tb_novel", novel_name=novelName, site_name=novelInfo.site, url=url, intro=novelInfo.intro,
                             add_time=datetime.now(), author_id=authorId, parser=parserName, detail=novelInfo.detail,
                             category_id=categoryId)
            logger.info("保存小说({0}, url:{1}))信息成功.".format(novelName, url))
        except Exception as e:
            logger.error("保存小说({0}, url:{1}))信息失败, 原因:{2}".format(novelName, url, e))

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
        with futures.ThreadPoolExecutor(max_workers=self.config.base.get("novels", 1)) as executor:
            for novel in self.config.novels:
                executor.submit(self.parse_novel_thread, novel)

    def parse_novel_thread(self, novel):
        if not novel.get("status"): return None  # 不启动解析直接返回
        novelName = novel.get("name")
        parserName = self.config.get_parser_name(novel.get("parser"))

        logger.info("爬取小说[{0}]到数据表[{1}]开始.".format(novelName, parserName))
        time_start = time.time()

        try:
            chapterTable = self.get_chapter_table(novelName)
            self.save_chapter(novel, chapterTable)
        except Exception as e:
            logger.error("parse_novel_thread({0})失败, 原因: {1}".format(novelName, e))
        finally:
            time_end = time.time()
            logger.info("爬取小说[{0}]结束. 耗时:{1}".format(novelName, time_end - time_start))

    def get_chapter_table(self, novelName):
        '''获取章节表名称'''
        sql = "select id from tb_novel where novel_name = '{}'".format(novelName)
        novelId = self.mydb.execute(sql)[0].get("id")
        tableName = "tb_chapter_{}".format(novelId % 10)
        return tableName

    def parse_test(self, novel):
        try:
            url = novel.get("url")
            charset = novel.get("charset", "gbk")
            name = novel.get("name")
            parserName = self.config.get_parser_name(novel.get("parser"))

            self.config.parsers[parserName].parse_test(url, encoding=charset)
        except Exception as e:
            return "\n parse_test({0})失败, 原因: {1}".format(name, e)

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
                    self.mydb.insert("tb_user_message", message=content, user_id=userId, is_read=0,
                                     add_time=datetime.now())
                    logger.info("write message to [{0}] success.".format(username))

        except Exception as e:
            logger.error("update_notice({0}) error:{1}".format(novelName, str(e)))

    def save_chapter(self, novel, table):
        '''保存章节信息'''
        url = novel.get("url")
        novelName = novel.get("name")
        charset = novel.get("charset")
        parserName = self.config.get_parser_name(novel.get("parser"))

        try:
            sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
            novelId = self.mydb.execute(sql)[0].get("id")

            urls = list(self.get_all_chapter_url(table, novelId))
            novelId = str(self.get_novel_id(novelName))
            path = os.path.join(self.config.base.get("file_root"), novelId)
            if not os.path.exists(path):
                os.makedirs(path)

            has_update = False
            parser = self.config.parsers.get(parserName)

            with futures.ThreadPoolExecutor(max_workers=self.config.base.get("chapters", 1)) as executor:
                for chapter in parser.parse_chapter(url, encoding=charset):
                    if chapter.url in urls:
                        continue
                    has_update = True
                    executor.submit(self.save_chapter_thread, parser, chapter, path, table, novelName, novelId)

            if has_update:
                # 发送更新通知
                self.update_notice(novelId, novelName)
        except Exception as e:
            raise RuntimeError("{0}保存小说({1})章节失败, 原因: {2}".format(EXCEPTION_PREFIX, novelName, e))

    def save_chapter_thread(self, parser, chapter, path, table, novelName, novelId):
        try:
            # 生成文件
            content = parser.parse_content(chapter.url)
            self.write_content(path, chapter.url, content=content)

            # 保存到数据库
            self.mydb.insert(table, novel_id=novelId, chapter_url=chapter.url,
                             chapter_index=self.get_chapter_index(chapter.url),
                             chapter_name=chapter.name, add_time=datetime.now())
            logger.info("save [{0}({1})] to [{2}] success.".format(novelName, chapter.name, table))
        except Exception as e:
            raise RuntimeError("{0}save_chapter_thread({1})失败, 原因: {2}".format(EXCEPTION_PREFIX, chapter.url, e))

    def get_all_chapter_url(self, table, novelId):
        sql = "select chapter_url from {0} where novel_id = {1}".format(table, novelId)
        result = self.mydb.execute(sql)
        if not result:
            return []

        for r in result:
            yield r.get("chapter_url")

    def get_chapter_index(self, chapterUrl):
        pos = chapterUrl.rfind("/")
        chapterIndex = re.match(r"\d+", chapterUrl[pos + 1:]).group()
        return int(chapterIndex)

    def write_content(self, path, chapterUrl, content):
        try:
            name = "{0}.txt".format(self.get_chapter_index(chapterUrl))
            fullPath = os.path.join(path, name)
            if not os.path.exists(fullPath):
                with open(fullPath, "w", encoding="utf-8") as fileObj:
                    fileObj.write(content)
        except Exception as e:
            raise RuntimeError("{0}write_content({1}) error:{2}".format(EXCEPTION_PREFIX, fullPath, e))

    def get_novel_id(self, novelName):
        sql = "select id from tb_novel where novel_name = '{0}'".format(novelName)
        result = self.mydb.execute(sql)
        return result[0].get("id", novelName)

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(10 * 60)


if __name__ == "__main__":
    collect = Collect()
    collect.run()
