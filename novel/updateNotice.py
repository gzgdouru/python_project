import time, sys, json, requests, smtplib
from email.mime.text import MIMEText
from email.header import Header
from datetime import datetime
import threading
from operator import itemgetter
from collections import OrderedDict

from bs4 import BeautifulSoup

from myEmail import MyEmail
from mysqlV1 import MysqlManager
from parseConfig import ParseConfig
from novelLog import logger


class UpdateNotice:
    def __init__(self, confPath="novelConfig.json"):
        self.conf = ParseConfig(confPath)
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

    def init_database(self):
        try:
            self.mydb = MysqlManager(**self.conf.database)
            logger.info("init_database() success.")
        except Exception as e:
            logger.error("init database failed, error:[{0}]".format(str(e)))
            sys.exit(-1)

    def init_novel(self):
        self.novelList = []
        try:
            for novel in self.conf.novel:
                if not novel.get("status"): continue;
                table = novel.get("table")
                if self.make_table(table):
                    self.novelList.append(novel)
                else:
                    logger.error("init novel failed, error:[创建表{}失败!]".format(table))
                    sys.exit(-1)
            logger.info("init_novel() success.")
        except Exception as e:
            logger.error("init novel failed, error:[{0}]".format(str(e)))
            sys.exit(-1)

    def reset_config(self, confPath="novelConfig.json"):
        logger.info("reload config....")
        self.conf = ParseConfig(confPath)
        self.init_database()
        self.init_novel()

    def show_config(self):
        logger.info(json.dumps(self.conf.data, indent=2, ensure_ascii=False))

    def make_table(self, table):
        sql = '''
            create table if NOT EXISTS {table_name} (
              id int primary key AUTO_INCREMENT,
              site varchar(255) UNIQUE,
              site_name varchar(255),
              chapter_name varchar(255),
              send_time datetime,
              KEY idx_site (site),
              KEY idx_chapter_name (chapter_name)
            );
            '''.format(table_name=table)
        self.mydb.execute(sql)
        return True

    def get_all_chapter(self, table):
        sql = "select name from {}".format(table)
        result = self.mydb.execute(sql)
        allChapter = [chapter.get("name") for chapter in result]
        return allChapter

    def send_email(self, **kwargs):
        with self.lock:
            smtpServer = kwargs.get("smtp_server")
            sender = kwargs.get("sender")
            passwd = kwargs.get("sender_passwd")
            charset = kwargs.get("charset")
            receiver = kwargs.get("receiver")
            subject = kwargs.get("subject")
            content = kwargs.get("content")
            mimeType = kwargs.get("mimeType")

            myemail = MyEmail(smtpServer, sender, passwd, receiver, charset=charset)
            stderr = myemail.send_email(subject, content, mimeType=mimeType)
        return stderr

    def parse_novel_thread(self, novel):
        novelName = novel.get("name")
        table = novel.get("table")
        siteList = novel.get("site")
        receiver = novel.get("receiver")
        sendContent = novel.get("send_content")

        for site in siteList:
            try:
                if not site.get("status"): continue
                siteName = site.get("name")
                parseFunc = self.parseMethod.get(siteName, self.default_parse)
                chapters = parseFunc(site)
                lastChapterUrl, lastChapterName = chapters.popitem()
                if not self.chapter_is_exist((lastChapterUrl, lastChapterName), table):
                    chapters[lastChapterUrl] = lastChapterName
                    if sendContent:
                        self.send_chapter_has_content(table, chapters, novelName, siteName, receiver)
                    else:
                        self.send_chapter(table, (lastChapterUrl, lastChapterName), novelName, siteName, receiver)
                    logger.info("{0}({1})最新章节: {2}".format(novelName, siteName, lastChapterName))
                    break
                else:
                    logger.info("{0}({1})最新章节: {2}".format(novelName, siteName, lastChapterName))
            except Exception as e:
                logger.error("parse_novel_thread({0}) failed, error:[{1}]".format(site.get("url"), str(e)))

    def parse_novel(self):
        for novel in self.novelList:
            thread = threading.Thread(target=self.parse_novel_thread, args=(novel,))
            thread.setDaemon(True)
            thread.start()

    def chapter_is_exist(self, chapter, table):
        chapterUrl = chapter[0]
        chapterName = self.get_chapter_name(chapter[1])
        sql = "select count(*) as num from {0} where site = '{1}' or chapter_name = '{2}'".format(table, chapterUrl, chapterName)
        result = self.mydb.execute(sql)
        return result[0].get("num")

    def save_chapter(self, siteName, chapter, table):
        try:
            sql = "insert into {0}(site, site_name, chapter_name, send_time) values('{1}', '{2}', '{3}', now())".format(
                table, chapter[0], siteName, self.get_chapter_name(chapter[1]))
            self.mydb.execute(sql)
            return True
        except Exception as e:
            logger.error("save chapter failed, error:[{0}]".format(str(e)))
        return False

    def default_parse(self, site):
        url = site.get("url")
        chapters = OrderedDict()
        try:
            timeStart = time.time()
            html = self.get_html_text(url, encode="gbk")
            soup = BeautifulSoup(html, "html.parser")
            subNode = soup.body.dl
            for child in subNode.children:
                try:
                    pos = child.a["href"].rfind(r"/")
                    chapterUrl = "{0}{1}".format(url, child.a["href"][pos+1:])
                    chapterName = child.a.string

                    #去掉重复的章节
                    if chapterUrl in chapters:
                        chapters.move_to_end(chapterUrl)
                    else:
                        chapters[chapterUrl] = chapterName
                except:
                    pass
            timeEnd = time.time()
            logger.info("parse {0} finish, 耗时:{1}".format(url, timeEnd - timeStart))
        except Exception as e:
            logger.error("parse ({0} failed, error:[{1}])".format(url, str(e)))
            chapters = None
        return chapters

    def default_parse_content(self, url):
        try:
            html = self.get_html_text(url, encode="gbk")
            soup = BeautifulSoup(html, "html.parser")
            contentNode = soup.find(id="content")

            # 内容节点有内容才返回
            if contentNode.text:
                content = str(contentNode)
                return content
        except Exception as e:
           raise RuntimeError("parse ({0}) content failed, error:[{1}]".format(url, str(e)))
        return None

    def send_chapter(self, table, chapter, novelName, siteName, receiver):
        if not self.save_chapter(siteName, chapter, table): return None
        subject = "小说更新提醒({0}-{1}-{2})".format(novelName, siteName, chapter[1])
        content = "最新章节:{}".format(chapter[1])
        self.send(receiver, subject, content)

    def send_chapter_has_content(self, table, chapters, novelName, siteName, receiver):
        sendCount = 3  # 每次最多发送3封邮件, 避免邮件轰炸
        if not self.get_record_count(table):
            sendCount = 1  # 如果表中没有数据, 则只发送最新一章

        while sendCount > 0:
            sendCount -= 1
            chapter = chapters.popitem()
            chapterName = self.get_chapter_name(chapter[1])
            if self.chapter_is_exist(chapter, table) or (not self.save_chapter(siteName, chapter, table)):
                break

            chapterUrl, chapterName = chapter
            parseContentFunc = self.parseContentMethod.get(siteName, self.default_parse_content)
            content = parseContentFunc(chapterUrl)
            if content:
                content = "<h3>{0}</h3>{1}".format(chapterName, content)
                subject = "小说更新提醒({0}-{1}-{2})".format(novelName, siteName, chapterName)

                # 邮件发送失败只输出错误, 不重新发送该章节
                self.send(receiver, subject, content, mimeType="html")
            else:  # 内容还没更新, 下次再次解析
                sql = "delete from {0} where site='{1}'".format(table, chapterUrl)
                self.mydb.execute(sql)
                logger.info("{0}-{1}-{2}, 内容尚未更新.".format(novelName, siteName, chapterName))

    def send(self, receivers, subject, content, mimeType="plain"):
        receiverList = self.list_split(receivers, nums=30)  # 一封邮件最多有三十个收件人
        for receiver in receiverList:
            # 对于发送失败的邮件, 换个发送人再次发送
            for myemail in self.conf.emails:
                myemail["receiver"] = receiver
                myemail["subject"] = subject
                myemail["content"] = content
                myemail["mimeType"] = mimeType

                stderr = self.send_email(**myemail)
                if not stderr:
                    logger.info("({0})[{1}] send email to {2} success.".format(subject, myemail.get("sender"), str(receiver)))
                    break
                else:
                    logger.error("({0})[{1}] send email to {2} failed!, error:{3}".format(subject, myemail.get("sender"), str(receiver), stderr))

    def get_html_text(self, url, encode="utf-8", timeout=30):
        respon = requests.get(url, headers={
            'user-agent': 'Mozilla/5.0'
        }, timeout=timeout)
        respon.encoding = encode
        return respon.text

    def get_record_count(self, table):
        sql = "select count(*) as charpter_num from {}".format(table)
        result = self.mydb.execute(sql)
        return result[0].get("charpter_num")

    def get_chapter_name(self, chapter):
        return chapter.split(" ")[1].strip()

    def list_split(self, srcList, nums=30):
        outList = []
        tmpList = srcList[:]
        while len(tmpList) > nums:
            outList.append(tmpList[:nums])
            tmpList = tmpList[nums:]
        if tmpList: outList.append(tmpList)
        return outList

    def run(self):
        while True:
            self.parse_novel()
            time.sleep(10 * 60)

if __name__ == "__main__":
    notice = UpdateNotice()
    notice.run()
