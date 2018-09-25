import sys
from biqugeParser import parse_test

if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else 'https://www.booktxt.net/1_1600/'
    err = parse_test(url)
    if not err:
        print("解析成功.")
    else:
        print("解析失败, error:{0}".format(err))
