import requests
from bs4 import BeautifulSoup
import os, time
from queue import Queue
from .xieediguoLog import logger
import threading
from datetime import datetime
from compressFile import ZipCompress
import shutil

class XEDGParser:
    def __init__(self, url, encoding="utf-8", timeout=60, dataDir=".", threadCount=15, isZip=False):
        self.url = url
        self.encoding = encoding
        self.timeout = timeout
        self.dataDir = dataDir
        self.threadCount = threadCount
        self.isZip = isZip
        self.linkQueue = Queue()
        self.load_filter()

    def load_filter(self):
        try:
            self.filter = [line[:-1] for line in open("xedg_filter.txt", encoding="utf-8")]
        except Exception as e:
            logger.warning("load_filter() error:{}".format(str(e)))
            self.filter = []

    def parse(self):
        parseUrl = self.url
        while True:
            html = self.get_html_text(parseUrl)

            [self.linkQueue.put(link) for link in self.get_link(html)]
            nextPageUrl = self.get_next_page(html)
            logger.info("paser url:{} finish.".format(parseUrl))
            if not nextPageUrl:
                break
            else:
                parseUrl = nextPageUrl

    def save(self):
        for i in range(self.threadCount):
            thread = threading.Thread(target=self.save_thread, args=())
            thread.setDaemon(True)
            thread.start()

    def save_thread(self):
        while True:
            link = self.linkQueue.get()
            if not self.title_filter(link[0]):
                logger.info("[{}]没有匹配过滤规则!".format(link[0]))
                continue

            dirName = self.dir_format(link[0])
            # 创建目录
            if (os.path.exists("{}_done".format(dirName)) and os.listdir("{}_done".format(dirName))) \
                    or os.path.exists("{}.zip".format(dirName)):
                logger.info("{} is already exist.".format(dirName))
                return
            else:
                self.make_dir(dirName)

            parseUrl = link[1]
            index = 0
            logger.info("parse [{}] start...".format(link[0]))
            start_time = time.time()

            # 解析内容
            while True:
                try:
                    html = self.get_html_text(parseUrl)
                    content = self.get_content(html)

                    filename = os.path.join(dirName, "{}.jpg".format(index))
                    open(filename, "wb").write(content)

                    nextPageUrl = self.get_next_page(html)
                    logger.info("paser url:{} finish.".format(parseUrl))

                    if not nextPageUrl: break
                    parseUrl = nextPageUrl
                    index += 1
                except Exception as e:
                    logger.error("->save url:{} error:{}".format(parseUrl, str(e)))
                    break

            if self.isZip:
                # 解析完成后压缩文件夹
                ZipCompress.zip_file(dirName, "{}.zip".format(dirName))
                shutil.rmtree(dirName)  # 压缩完成, 删除源文件夹
            else:
                os.rename(dirName, "{}_done".format(dirName))

            end_time = time.time()
            logger.info("parse [{}] finish, 耗时:{}".format(link[0], end_time - start_time))

    def dir_format(self, dirName):
        pos = dirName.find(":")
        if pos != -1:
            dirName = dirName.split(":")[1]
        return "{}/{}".format(self.dataDir, dirName)

    def url_format(self, subUrl):
        if subUrl[:4] != "http":
            pos = subUrl.rfind(r"/")
            subUrl = "{0}{1}".format(self.url, subUrl[pos + 1:])
        return subUrl

    def make_dir(self, dirName):
        try:
            if os.path.exists(dirName): shutil.rmtree(dirName)
            if os.path.exists("{}_done".format(dirName)) : shutil.rmtree("{}_done".format(dirName))
            os.makedirs(dirName)
        except Exception as e:
            dirName = "{}/{}".format(self.dataDir, datetime.now().strftime("%Y%m%d%H%M"))
            os.makedirs(dirName)

    def get_link(self, html):
        links = []
        soup = BeautifulSoup(html, "lxml")
        linksNode = soup.find(class_="c_inner").ul
        for child in linksNode.children:
            try:
                link = self.url_format(child.a["href"])
                title = child.a["title"]
                links.append((title, link))
            except:
                pass
        return links

    def get_content(self, html):
        try:
            soup = BeautifulSoup(html, "lxml")
            contentNode = soup.find(id="imgString")
            contentUrl = contentNode.a.img["src"]

            r = requests.get(contentUrl, headers={
                'user-agent': 'Mozilla/5.0'
            }, timeout=self.timeout)
            content = r.content
        except Exception as e:
            raise RuntimeError("->get_content() error:{}".format(str(e)))
        return content

    def get_next_page(self, html):
        nextPageUrl = None
        soup = BeautifulSoup(html, "lxml")
        pagesNode = soup.find(class_ = "showpage")
        for child in pagesNode.children:
            try:
                if child.string == "下一页" and child["href"] != "#":
                    nextPageUrl = self.url_format(child["href"])
            except:
                pass
        return nextPageUrl

    def get_html_text(self, url):
        respon = requests.get(url, headers={
            'user-agent': 'Mozilla/5.0'
        }, timeout=self.timeout)
        respon.encoding = self.encoding
        return respon.text

    def title_filter(self, title):
        if not self.filter: return True

        for line in self.filter:
            if title.find(line) != -1:
                logger.info("[{}]匹配过滤规则:[{}]".format(title, line))
                return True
        return False

    def run(self):
        parseThread = threading.Thread(target=self.parse, args=())
        parseThread.setDaemon(True)
        parseThread.start()

        saveThread = threading.Thread(target=self.save, args=())
        saveThread.setDaemon(True)
        saveThread.start()

        while True:
            time.sleep(5*60)

if __name__ == "__main__":
    url = r'http://m.xieediguo.cc/shaonv/'
    parser = XEDGParser(url, dataDir="./heihei")
    parser.run()



