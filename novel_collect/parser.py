from bs4 import BeautifulSoup
import requests

class Parser:
    def __init__(self, url, encoding="utf-8", timeout=15):
        self.url = url
        self.encoding = encoding
        self.timeout = timeout

    def parse_chapter(self):
        names = []
        urls = []
        try:
            html = self.get_html_text()
            soup = BeautifulSoup(html, "html.parser")
            subNode = soup.body.dl
            for child in subNode.children:
                try:
                    chapterUrl = child.a["href"]
                    if chapterUrl[:4] != "http":
                        pos = chapterUrl.rfind(r"/")
                        chapterUrl = "{0}{1}".format(self.url, child.a["href"][pos + 1:])
                    charpterName = child.a.string

                    # 去掉重复更新的章节
                    if chapterUrl not in urls:
                        names.append(charpterName)
                        urls.append(chapterUrl)
                except:
                    pass
            chapters = zip(urls, names)
        except Exception as e:
            raise RuntimeError("->paser_chapter({}) error:{}".format(self.url, str(e)))
            chapters = None
        return chapters

    def parse_content(self):
        pass

    def get_html_text(self):
        respon = requests.get(self.url, headers={
            'user-agent': 'Mozilla/5.0'
        }, timeout=self.timeout)
        respon.encoding = self.encoding
        return respon.text