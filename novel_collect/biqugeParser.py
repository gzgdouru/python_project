from bs4 import BeautifulSoup
import requests
import os


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
        subNode = soup.body.dl
        for child in subNode.children:
            try:
                chapterUrl = child.a["href"]
                if chapterUrl[:4] != "http":
                    pos = chapterUrl.rfind(r"/")
                    chapterUrl = "{0}{1}".format(url, child.a["href"][pos + 1:])
                charpterName = child.a.string
                yield (chapterUrl, charpterName)
            except:
                pass
    except Exception as e:
        raise RuntimeError("\n paser_chapter({0}) error:{1}".format(url, e))


def parse_test(url, encoding="utf-8", timeout=30):
    try:
        html = get_html_text(url, encoding, timeout)
        soup = BeautifulSoup(html, "html.parser")
        subNode = soup.body.dl
        for child in subNode.children:
            try:
                chapterUrl = child.a["href"]
                charpterName = child.a.string
                return None
            except:
                pass
    except Exception as e:
        return "parse url: {0} failed, error:{1}".format(url, e)
    return "找不到章节信息!"
