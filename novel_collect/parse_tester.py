import requests
from bs4 import BeautifulSoup
from parser import Parser
import sys

if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else 'https://www.booktxt.net/1_1600/'
    try:
       chapters = Parser.paser_chapter(url, encoding="gbk")
       print(chapters)
    except Exception as e:
        print("解析出错, error:{}".format(str(e)))
