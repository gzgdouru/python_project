import requests
from bs4 import BeautifulSoup
import os, time
from queue import Queue
from xieediguoLog import logger
import threading

class Parser:
    def __init__(self, url, encoding="utf-8", timeout=60):
        self.url = url
        self.encoding = encoding
        self.timeout = timeout
        self.linkQueue = Queue()

    def formatUrl(self, subUrl):
        if subUrl[:4] != "http":
            pos = subUrl.rfind(r"/")
            subUrl = "{0}{1}".format(self.url, subUrl[pos + 1:])
        return subUrl

    def get_link(self, html):
        links = []
        soup = BeautifulSoup(html, "lxml")
        linksNode = soup.find(class_="c_inner").ul
        for child in linksNode.children:
            try:
                link = self.formatUrl(child.a["href"])
                title = child.a["title"]
                links.append((title, link))
            except:
                pass
        return links

    def get_next_page(self, html):
        nextPageUrl = None
        soup = BeautifulSoup(html, "lxml")
        pagesNode = soup.find(class_ = "showpage")
        for child in pagesNode.children:
            try:
                if child.string == "下一页" and child["href"] != "#":
                    nextPageUrl = self.formatUrl(child["href"])
            except:
                pass
        return nextPageUrl

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

    def format_dir(self, dirName):
        pos = dirName.find(":")
        if pos != -1:
            dirName = dirName.split(":")[1]
        return dirName

    def save(self):
        for i in range(15):
            thread = threading.Thread(target=self.save_thread, args=())
            thread.setDaemon(True)
            thread.start()

    def save_thread(self):
        while True:
            link = self.linkQueue.get()
            dirName = self.format_dir(link[0])
            parseUrl = link[1]
            index = 0

            # 创建目录
            try:
                if os.path.exists(dirName):
                    logger.info("{} is already exist.".format(dirName))
                    return
                else:
                    os.makedirs(dirName)
            except Exception as e:
                print("make dir:{} error:{}".format(dirName, str(e)))

            # 解析内容
            while True:
                try:
                    html = self.get_html_text(parseUrl)

                    soup = BeautifulSoup(html, "lxml")
                    contentNode = soup.find(id="imgString")
                    contentUrl = contentNode.a.img["src"]
                    filename = os.path.join(dirName, "{}.jpg".format(index))
                    r = requests.get(contentUrl)
                    file = os.path.join(dirName, filename)
                    open(filename, "wb").write(r.content)

                    nextPageUrl = self.get_next_page(html)
                    logger.info("paser url:{} finish.".format(parseUrl))

                    if not nextPageUrl: break
                    parseUrl = nextPageUrl
                    index += 1

                except Exception as e:
                    logger.error("save url:{} error:{}".format(parseUrl, str(e)))
                    break

    def get_html_text(self, url):
        respon = requests.get(url, headers={
            'user-agent': 'Mozilla/5.0'
        }, timeout=self.timeout)
        respon.encoding = self.encoding
        return respon.text

    def run(self):
        parseThread = threading.Thread(target=self.parse, args=())
        parseThread.setDaemon(True)
        parseThread.start()

        saveThread = threading.Thread(target=self.save, args=())
        saveThread.setDaemon(True)
        saveThread.start()

        while True: pass

if __name__ == "__main__":
    url = r'http://m.xieediguo.cc/shaonv/'
    parser = Parser(url)
    parser.run()



