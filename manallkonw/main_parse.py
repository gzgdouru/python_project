from xedg.xieediguo import XEDGParser

if __name__ == "__main__":
    url = r'http://m.xieediguo.cc/shaonv/'
    parser = XEDGParser(url, dataDir=r"d:/xieediguo_data")
    parser.run()