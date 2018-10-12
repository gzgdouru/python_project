import requests
import os, re
from urllib import parse
from lxml import etree

from dataStructures import NovelInfo, ChapterInfo, EXCEPTION_PREFIX


def get_html_text(url, encoding, timeout):
    response = requests.get(url, headers={
        'user-agent': 'Mozilla/5.0'
    }, timeout=timeout)
    response.encoding = encoding

    if not response.text:
        raise RuntimeError("{0}获取[{1}]内容失败!".format(EXCEPTION_PREFIX, url))

    return response.text


def parse_info(url, encoding="gbk", timeout=30):
    '''提取小说信息(网站名称, 小说名称, 作者, 简介, 详细介绍)'''
    try:
        html = get_html_text(url, encoding, timeout)
        htmltree = etree.HTML(html)


        site = htmltree.xpath("//div[@class='header']/div[@class='header_logo']/a/text()")[0]
        author = htmltree.xpath("//div[@id='info']/p[1]/text()")[0]

        r = re.match(r"^作.*?者：(\w+)", author)
        author = r.group(1) if r else None

        intro = htmltree.xpath("//div[@id='intro']/p[1]/text()")
        intro = "\n".join(intro)
        detail = intro
        intro = (intro[:252] + "...") if len(intro) > 255 else intro
    except Exception as e:
        raise RuntimeError("{0}biqugeParser::parse_info({1})失败, 原因:{2}".format(EXCEPTION_PREFIX, url, e))

    if not author:
        raise RuntimeError("{0}biqugeParser::parse_info({1})失败, 原因:小说作者为None!".format(EXCEPTION_PREFIX, url))

    return NovelInfo(site=site, author=author, intro=intro, detail=detail)


def parse_chapter(url, encoding="gbk", timeout=30):
    try:
        htmltree = etree.HTML(get_html_text(url, encoding, timeout))
        chapters = htmltree.xpath("//div[@id='list']/dl/dd/a")
        for chapter in chapters:
            chapterUrl = parse.urljoin(url, chapter.get("href"))
            charpterName = chapter.text
            yield ChapterInfo(url=chapterUrl, name=charpterName)
    except Exception as e:
        raise RuntimeError("{0}biqugeParser::paser_chapter({1})失败, 原因:{2}".format(EXCEPTION_PREFIX, url, e))


def parse_test(url, encoding="gbk", timeout=30):
    try:
        chapters = parse_chapter(url, encoding=encoding, timeout=timeout)
        for chapter in chapters:
            return True
    except Exception as e:
        raise RuntimeError("{0}biqugeParser:parse_test({1})失败, 原因: {2}".format(EXCEPTION_PREFIX, url, e))
    raise RuntimeError("{0}biqugeParser:parse_test({1})失败, 原因: 提取章节信息失败!".format(EXCEPTION_PREFIX, url))

def parse_content(url, encoding="gbk", timeout=30):
    try:
        htmltree = etree.HTML(get_html_text(url, encoding, timeout))
        contentNode = htmltree.xpath("//div[@id='content']")[0]
    except Exception as e:
        raise RuntimeError("{0}biqugeParser:parse_content({1})失败, 原因: {2}".format(EXCEPTION_PREFIX, url, e))
    return etree.tostring(contentNode, encoding="utf-8").decode("utf-8")


if __name__ == "__main__":
    url = "https://www.woquge.com/0_857/653455.html"
    print(parse_content(url))