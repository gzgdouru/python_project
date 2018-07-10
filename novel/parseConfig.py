import json

class ParseConfig(object):
    def __init__(self, filePath="novelConfig.json"):
        self.data = json.loads(open(filePath, encoding="utf-8").read())
        self.email = None
        self.novel = []
        self.database = None
        self.parse()

    def parse(self):
        self.parse_email()
        self.parse_database()
        self.paser_novel()

    def parse_email(self):
        self.email = self.data.get("email")

    def parse_database(self):
        self.database = self.data.get("database")

    def paser_novel(self):
        novelNodes = self.data.get("novel")
        [self.novel.append(node) for node in novelNodes]

if __name__ == "__main__":
    parseConfig = ParseConfig()
    print(parseConfig.data)
