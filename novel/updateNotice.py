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

        self.parseContentMethod = {
            "笔趣阁": self.default_parse_content,
            "顶点中文网": self.default_parse_content,
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

    def reset_config(self, confPath="novelConfig.json"):
        logger.info("reload config....")
        self.conf = ParseConfig(confPath)
        self.init_email()
        self.init_database()
        self.init_novel()

    def show_config(self):
        logger.info(json.dumps(self.conf.data, indent=2, ensure_ascii=False))

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

    def get_all_chapter(self, table):
        sql = "select name from {}".format(table)
        res, dbout = self.mydb.execute(sql)
        allChapter = [chapter.get("name") for chapter in dbout]
        return allChapter

    def send_email(self, receiver, subject, content, mimeType="plain"):
        with self.lock:
            self.myemail.set_receiver(receiver)
            stderr = self.myemail.send_email(subject, content, mimeType=mimeType)
        return stderr

    def parse_novel_thread(self, novel):
        novelName = novel.get("name")
        table = novel.get("table")
        siteList = novel.get("site")
        receiver = novel.get("receiver")
        sendContent = novel.get("send_content")

        try:
            for site in siteList:
                if not site.get("status"): continue
                siteName = site.get("name")
                parseFunc = self.parseMethod.get(siteName, self.default_parse)
                chapters = parseFunc(site)
                if chapters and not self.chapter_is_exist(chapters[-1][1], table):
                    if sendContent:
                        self.send_chapter_has_content(table, chapters, novelName, siteName, receiver)
                    else:
                        self.send_chapter(table, chapters[-1][1], novelName, siteName, receiver)
                    break
                else:
                    logger.info("{0}({1})最新章节: {2}".format(novelName, siteName, chapters[-1][1]))
        except Exception as e:
            logger.error("parse_novel_thread({0}) error:{1}".format(novelName, str(e)))

    def parse_novel(self):
        threads = []
        for novel in self.novelList:
            thread = threading.Thread(target=self.parse_novel_thread, args=(novel,))
            threads.append(thread)
            thread.start()
        [thread.join() for thread in threads]

    def chapter_is_exist(self, chapter, table):
        chapterName = self.get_chapter_name(chapter)
        allChapters = self.get_all_chapter(table)
        return (chapterName in allChapters)

    def save_chapter(self, siteName, newChapter, table):
        try:
            sql = "insert into {table}(source_site, name, send_time) values('{source_site}', '{name}', now())".format(
                table=table, source_site=siteName, name=newChapter)
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
            }, timeout=30)
            respon.encoding = "gbk"
            html = respon.text
            soup = BeautifulSoup(html, "lxml")
            subNode = soup.body.dl
            for child in subNode.children:
                try:
                    chapterUrl = "{}/{}".format(url, child.a["href"])
                    charpter = child.a.string
                    chapters.append((chapterUrl, charpter))
                except:
                    pass
        except Exception as e:
            logger.error("parse() {site_name} {site_url} error:{errinfo}".format(site_name=name, site_url=url, errinfo=str(e)))
            chapters = None
        return chapters

    def default_parse_content(self, url):
        content = stderr = None
        try:
            respon = requests.get(url, headers={
                'user-agent': 'Mozilla/5.0'
            }, timeout=30)
            respon.encoding = "gbk"
            html = respon.text
            soup = BeautifulSoup(html, "lxml")
            contentNode = soup.find(id="content")
            if contentNode.text: content = str(contentNode)
        except Exception as e:
            stderr = str(e)
        return content, stderr

    def send_chapter(self, table, chapter, novelName, siteName, receiver):
        newChapter = self.get_chapter_name(chapter)
        if not self.save_chapter(siteName, newChapter, table): return None
        subject = "小说更新提醒({0}-{1}-{2})".format(novelName, siteName, chapter)
        content = "最新章节:{}".format(chapter)
        stderr = self.send_email(receiver, subject, content)
        if not stderr:
            logger.info("{0} send email to {1} success.".format(subject, str(receiver)))
        else:
            logger.error("{0} send email to {1} failed!, error:{2}".format(subject, str(receiver), stderr))

    def send_chapter_has_content(self, table, chapters, novelName, siteName, receiver):
        allChapter = self.get_all_chapter(table)
        if not self.get_record_count(table): chapters = chapters[-1:]    #如果表中没有数据, 则只发送最新一章
        timeCount = 1
        for chapter in chapters[::-1]:
            if timeCount > 3: break # 每次最多发送3封邮件
            timeCount += 1

            url = chapter[0]
            chapterName = self.get_chapter_name(chapter[1])
            if (chapterName in allChapter) or (not self.save_chapter(siteName, chapterName, table)): break
            parseContentFunc = self.parseContentMethod.get(siteName, self.default_parse_content)
            content, stderr = parseContentFunc(url)
            if content:
                content = "<h3>{0}</h3>{1}".format(chapter[1], content)
                subject = "小说更新提醒({0}-{1}-{2})".format(novelName, siteName, chapter[1])

                # 邮件发送失败只输出错误, 不重新发送该章节
                stderr = self.send_email(receiver, subject, content, mimeType="html")
                if not stderr:
                    logger.info("{0} send email to {1} success.".format(subject, str(receiver)))
                else:
                    logger.error("{0} send email to {1} failed!, error:{2}".format(subject, str(receiver), stderr))
            elif stderr:     # 解析网页出错
                logger.error("paser url:{0} failed, error:{1}".format(url, stderr))
            else:    # 内容还没更新, 下次再次解析
                sql = "delete from {0} where name='{1}'".format(table, self.get_chapter_name(chapter))
                self.mydb.execute(sql)
                logger.info("{0}-{1}-{2}, 内容尚未更新.".format(novelName, siteName, chapter[1]))

    def get_record_count(self, table):
        sql = "select count(*) as charpter_num from {}".format(table)
        res, dbout = self.mydb.execute(sql)
        return dbout[0].get("charpter_num")

    def get_chapter_name(self, chapter):
        return chapter.split(" ")[1].strip()

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(10 * 60)

if __name__ == "__main__":
    notice = UpdateNotice()
    notice.run()
