import time, sys, json, requests, smtplib
from email.mime.text import MIMEText
from email.header import Header
from bs4 import BeautifulSoup
from datetime import datetime
from myEmail import MyEmail
from mysql_ex import MysqlManager
from parseConfig import ParseConfig
import threading
from novelLog import logger

class UpdateNotice:
    def __init__(self, confPath="novelConfig.json"):
        self.conf = ParseConfig(confPath)
        self.init_email()
        self.init_database()
        self.init_novel()
        self.lock = threading.Lock()
        self.parseMethod = {
            "笔趣阁" : self.default_parse,
            "顶点中文网" : self.default_parse,
        }

    def init_email(self):
        try:
            smtpServer = self.conf.email.get("smtp_server")
            sender = self.conf.email.get("sender")
            passwd = self.conf.email.get("sender_passwd")
            charset = self.conf.email.get("charset")
            self.myemail = MyEmail(smtpServer, sender, passwd, charset=charset)
            logger.info("init_email() success.")
        except Exception as e:
            logger.error("init_email() error:{}".format(str(e)))
            sys.exit(-1)

    def init_database(self):
        try:
            self.mydb = MysqlManager(**self.conf.database)
            logger.info("init_database() success.")
        except Exception as e:
            logger.error("init_database() error:{}".format(str(e)))
            sys.exit(-1)

    def init_novel(self):
        self.novelList = []
        try:
            for novel in self.conf.novel:
                if not novel.get("status"): continue;
                table = novel.get("table")
                if self.make_table(table):
                    self.novelList.append(novel)
                    continue
                else:
                    logger.error("init_novel() error:创建表{}失败!".format(table))
                    sys.exit(-1)
            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init_novel() error:{}".format(str(e)))
            sys.exit(-1)

    def make_table(self, table):
        sql = "select count(*) as table_count from information_schema.TABLES WHERE table_name ='{}'".format(table)
        res, dbout = self.mydb.execute(sql)
        if dbout[0].get("table_count"): return True
        sql = '''
            create table {table_name} (
              id int primary key AUTO_INCREMENT,
              source_site varchar(255),
              name varchar(255),
              send_time datetime
            );
            '''.format(table_name=table)
        res, dbout = self.mydb.execute(sql)
        return res

    def get_all_send_chapter(self, table):
        sql = "select name from {}".format(table)
        res, dbout = self.mydb.execute(sql)
        allChapter = [chapter.get("name") for chapter in dbout]
        return allChapter

    def send_email(self, receiver, subject, content):
        with self.lock:
            self.myemail.set_receiver(receiver)
            stderr = self.myemail.send_email(subject, content)
        return stderr

    def parse_novel_thread(self, novel):
        novelName = novel.get("name")
        table = novel.get("table")
        siteList = novel.get("site")
        receiver = novel.get("receiver")

        try:
            for site in siteList:
                if not site.get("status"): continue
                siteName = site.get("name")
                parseFunc = self.parseMethod.get(siteName, self.default_parse)
                newChapter = parseFunc(site)
                if newChapter and self.save_chapter(siteName, newChapter, table):
                    stderr = self.send_email(receiver, "小说更新提醒({})".format(novelName), "最新章节:{}".format(newChapter))
                    if not stderr:
                        logger.info("小说更新提醒({0}-{1}-{2}), send email to {3} success!)".format(
                            novelName, siteName, newChapter, str(receiver)))
                    else:
                        logger.info("小说更新提醒({0}-{1}-{2}) send email to {3} failed!, error:{4})".format(
                            novelName, siteName, newChapter, str(receiver), stderr))

                    break
                else:
                    logger.info("{0}({1})最新章节: {2}".format(novelName, siteName, newChapter))
        except Exception as e:
            logger.error("parse_novel_thread({0}) error:{1}".format(novelName, str(e)))

    def parse_novel(self):
        threads = []
        for novel in self.novelList:
            thread = threading.Thread(target=self.parse_novel_thread, args=(novel,))
            threads.append(thread)
            thread.start()
        [thread.join() for thread in threads]

    def save_chapter(self, siteName, newChapter, table):
        try:
            chapter = newChapter.split(" ")[1].strip()
            allChapters = self.get_all_send_chapter(table)
            if chapter not in allChapters:
                sql = "insert into {table}(source_site, name, send_time) values('{source_site}', '{name}', now())".format(
                    table=table, source_site=siteName, name=chapter)
                self.mydb.execute(sql)
                return True
        except Exception as e:
            logger.error("save_chapter() error:{}".format(str(e)))
        return False

    def default_parse(self, site):
        name = site.get("name")
        url = site.get("url")
        chapters = []
        try:
            respon = requests.get(url, headers={
                'user-agent' : 'Mozilla/5.0'
            }, timeout=10)
            respon.encoding = "gbk"
            html = respon.text
            soup = BeautifulSoup(html, "html.parser")
            subNode = soup.body.dl
            for child in subNode.children:
                try:
                    chapters.append(child.a.string)
                except:
                    pass
        except Exception as e:
            logger.error("parse() {site_name} {site_url} error:{errinfo}".format(site_name=name, site_url=url, errinfo=str(e)))
            chapters = None
        return (None if not chapters else chapters[-1])

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(10 * 60)

if __name__ == "__main__":
    notice = UpdateNotice()
    notice.run()
