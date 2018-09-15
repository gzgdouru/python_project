import json

class ParseConfig(object):
    def __init__(self, filePath="config.json"):
        self.data = json.loads(open(filePath, encoding="utf-8").read())
        self.email = None
        self.novels = []
        self.database = None
        self.parse()

    def parse(self):
        self.parse_database()
        self.parse_email()
        self.parse_novel()

    def parse_database(self):
        self.database = self.data.get("database")

    def parse_novel(self):
        novelNodes = self.data.get("novel")
        [self.novels.append(node) for node in novelNodes]

    def parse_email(self):
        self.email = self.data.get("email")

if __name__ == "__main__":
    parseConfig = ParseConfig()
    print(parseConfig.data)
    print(parseConfig.novels)
