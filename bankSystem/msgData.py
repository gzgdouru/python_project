import json

buffSize = 4096

class LoginMsg:
    def __init__(self):
        self.msgType = "login"
        self.userName = ""
        self.passwd = ""

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.userName = res["userName"]
        self.passWd = res["passwd"]

class ResultMsg:
    def __init__(self):
        self.status = -1
        self.msgText = ""
        self.data = {}

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.status = res["status"]
        self.msgText = res["msgText"]
        self.data = res["data"]

class QuitMsg:
    def __init__(self):
        self.msgType = "quit"
        self.userName = ""

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.userName = res["userName"]

class RegisterMsg:
    def __init__(self):
        self.msgType = "register"
        self.userName = ""
        self.passwd = ""

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.userName = res["userName"]
        self.passwd = res["passwd"]

class LogoutMsg:
    def __init__(self):
        self.msgType = "logout"
        self.userName = ""

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.userName = res["userName"]

class QueryMsg:
    def __init__(self):
        self.msgType = "query"
        self.userName = ""
        self.balance = 0

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.userName = res["userName"]
        self.balance = res["balance"]

class SaveMsg:
    def __init__(self):
        self.msgType = "save"
        self.userName = ""
        self.money = None

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.userName = res["userName"]
        self.money = res["money"]

class TakeMsg:
    def __init__(self):
        self.msgType = "take"
        self.srcUserName = ""
        self.dstUserName = ""
        self.money = None

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.srcUserName = res["srcUserName"]
        self.dstUserName = res["dstUserName"]
        self.money = res["money"]

class TransferMsg:
    def __init__(self):
        self.msgType = "transfer"
        self.srcUserName = ""
        self.dstUserName = ""
        self.money = None

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.srcUserName = res["srcUserName"]
        self.dstUserName = res["dstUserName"]
        self.money = res["money"]

class CheckMsg:
    def __init__(self):
        self.msgType = "check"
        self.userName = ""

    def serialization(self):
        return json.dumps(self.__dict__, skipkeys=True, indent=4)

    def deserialization(self, strMsg):
        res = json.loads(strMsg)
        self.msgType = res["msgType"]
        self.userName = res["userName"]