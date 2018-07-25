import os, sys
from parseConfig import ParseConfig

class Collect:
    def __init__(self, configFile="config.json"):
        self.config = ParseConfig(configFile)
        self.init_db()

    def init_db(self):
        pass

    def make_main_table(self):
        pass