import json
import sys
import os

import biqugeParser


class ParseConfig(object):
    def __init__(self, filePath="config.json"):
        self.data = json.loads(open(filePath, encoding="utf-8").read())
        self.email = None
        self.novels = []
        self.database = None
        self.parsers = {}
        self.parse()

    def parse(self):
        self.parse_database()
        self.parse_email()
        self.parse_novel()

    def parse_database(self):
        self.database = self.data.get("database")

    def parse_novel(self):
        novelNodes = self.data.get("novel")
        for novel in novelNodes:
            parser = novel.get("parser")

            if parser:
                if not os.path.exists(parser) or not os.path.isfile(parser):
                    raise RuntimeError("{0} 不存在或不是文件.".format(parser))
                extModule = self.load_parser(parser)
            else:
                extModule = biqugeParser

            name = self.get_parser_name(parser)
            if name not in self.parsers:
                self.parsers[name] = extModule
            self.novels.append(novel)

    def load_parser(self, parser):
        extDir = os.path.dirname(parser)
        extFile = os.path.basename(parser)
        extModuleName = os.path.splitext(extFile)[0]
        if extDir not in sys.path:
            sys.path.insert(0, extDir)
        extModule = __import__('{0}'.format(extModuleName))
        return extModule

    def parse_email(self):
        self.email = self.data.get("email")

    @staticmethod
    def get_parser_name(parser):
        if parser:
            name = os.path.splitext(os.path.basename(parser))[0]
        else:
            name = biqugeParser.__name__
        return name


if __name__ == "__main__":
    print(biqugeParser.__name__)
