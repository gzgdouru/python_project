from bs4 import BeautifulSoup
import requests
import os
from urllib import parse


def get_html_text(url, encoding, timeout):
    respon = requests.get(url, headers={
        'user-agent': 'Mozilla/5.0'
    }, timeout=timeout)
    respon.encoding = encoding
    return respon.text


def parse_chapter(url, encoding="gbk", timeout=30):
    names = []
    urls = []
    try:
        html = get_html_text(url, encoding, timeout)
        soup = BeautifulSoup(html, "html.parser")
        subNode = soup.body.dl
        for child in subNode.children:
            try:
                chapterUrl = parse.urljoin(url, child.a["href"])
                charpterName = child.a.string
                yield (chapterUrl, charpterName)
            except:
                pass
    except Exception as e:
        raise RuntimeError("\n paser_chapter({0}) error:{1}".format(url, e))


def parse_test(url, encoding="gbk", timeout=30):
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


def parse_content(url, encoding="gbk", timeout=30):
    html = get_html_text(url, encoding, timeout)
    soup = BeautifulSoup(html, "html.parser")
    contentNode = soup.find(id="content")
    return contentNode.text

if __name__ == "__main__":
    url = "https://www.cangqionglongqi.com/quanzhifashi/"
    for chapter in parse_chapter(url):
        print(chapter)
