import json

class ParseConfig(object):
    def __init__(self, filePath="config.json"):
        self.data = json.loads(open(filePath, encoding="utf-8").read())
        self.novels = []
        self.parse()

    def parse(self):
        self.paser_novel()

    def paser_novel(self):
        novelNodes = self.data.get("novel")
        [self.novels.append(node) for node in novelNodes]

if __name__ == "__main__":
    parseConfig = ParseConfig()
    print(parseConfig.data)
    print(parseConfig.novels)
