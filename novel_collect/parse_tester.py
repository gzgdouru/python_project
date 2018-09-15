import sys
from novelParser import BiQuGeParser

if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else 'https://www.booktxt.net/1_1600/'
    parser = BiQuGeParser(url, encoding="gbk")
    try:
       chapters = parser.parse_chapter()
       print(list(chapters))
    except Exception as e:
        print("解析出错, error:{}".format(str(e)))
