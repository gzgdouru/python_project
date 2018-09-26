from bs4 import BeautifulSoup
import requests
import os, re

BASE_URL = "http://www.diyibanzhu.one/"

def get_html_text(url, encoding, timeout):
    respon = requests.get(url, headers={
        'user-agent': 'Mozilla/5.0'
    }, timeout=timeout)
    respon.encoding = encoding
    return respon.text


def parse_chapter(url, encoding="utf-8", timeout=30):
    names = []
    urls = []

    try:
        html = get_html_text(url, encoding, timeout)
        soup = BeautifulSoup(html, "html.parser")
        aNodes = soup.select(".list_box ul li a")
        for aNode in aNodes:
            try:
                chapterUrl = aNode["href"]
                if chapterUrl[:4] != "http":
                    chapterUrl = "{0}{1}".format(BASE_URL, chapterUrl)
                charpterName = aNode.string
                yield (chapterUrl, charpterName)
            except:
                pass
    except Exception as e:
        raise RuntimeError("\n paser_chapter({0}) error:{1}".format(url, e))


def parse_test(url, encoding="utf-8", timeout=30):
    try:
        html = get_html_text(url, encoding, timeout)
        soup = BeautifulSoup(html, "html.parser")
        aNodes = soup.select(".list_box ul li a")
        for aNode in aNodes:
            try:
                chapterUrl = aNode["href"]
                charpterName = aNode.string
                return None
            except:
                pass
    except Exception as e:
        return "parse url: {0} failed, error:{1}".format(url, e)
    return "找不到章节信息!"


def parse_content(url, encoding="gbk", timeout=30):
    html = get_html_text(url, encoding, timeout)
    soup = BeautifulSoup(html, "html.parser")
    contentNode = soup.select(".box_box")[0]
    return str(contentNode).replace("<br/>", "\n")


if __name__ == "__main__":
    url = r'http://www.diyibanzhu.one//0/11209/1541929.html'
    print(parse_content(url))
