from  collections import namedtuple

#网站名称, 作者, 简介, 详细介绍
NovelInfo = namedtuple("novelInfo", ["site", "author", "intro", "detail"])

#章节链接, 章节名称
ChapterInfo = namedtuple("ChapterInfo", ["url", "name"])

EXCEPTION_PREFIX = "\n-->"

if __name__ == "__main__":
    pass
