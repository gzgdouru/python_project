import socket
import msgData
import sys
import traceback

class BankClient:
    def __init__(self, serverHost="127.0.0.1", serverPort=10002):
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.buffSize = 4096
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.func = {}
        self.registerFunc()
        self.userName = ""

    def connectServer(self):
        print "connect server....."
        self.sock.connect((self.serverHost, self.serverPort))
        recvData = self.sock.recv(msgData.buffSize)
        print recvData

    def run(self):
        try:
            self.connectServer()
            self.showMenu()
        except socket.error:
            print "connection is closed!"
        except Exception as e:
            traceback.print_exc()

    def registerFunc(self):
        self.func["login"] = self.login
        self.func["quit"] = self.quit
        self.func["register"] = self.register
        self.func["logout"] = self.logout
        self.func["query"] = self.query
        self.func["save"] = self.save
        self.func["take"] = self.take
        self.func["transfer"] = self.transfer
        self.func["check"] = self.check

    def showMenu(self):
        menu = '''
        login (user login)
        quit (quit system)
        register (user register)
        logout (user logout)
        query (query balance)
        save (save money)
        take (take money)
        transfer (transfer money)
        check (check record)
        entry your choice:
        '''
        while True:
            choice = raw_input(menu)
            opt = self.func.get(choice)
            if opt:
                opt()
            else:
                print "invalid choice!"

    def login(self):
        if self.userName:
            print "please logout first"
        else:
            loginMsg = msgData.LoginMsg()
            loginMsg.userName = raw_input("entry user name: ")
            loginMsg.passwd = raw_input("entry user password: ")
            result = self.sendMsg(loginMsg.serialization())
            if result.status == 0 or result.status == 2:
                self.userName = loginMsg.userName
            print result.msgText

    def quit(self):
        quitMsg = msgData.QuitMsg();
        quitMsg.userName = self.userName
        self.sock.send(quitMsg.serialization())
        recvData = self.sock.recv(msgData.buffSize)
        result = msgData.ResultMsg()
        result.deserialization(recvData)
        if result.status == 0:
            self.userName = ""
            sys.exit(0)
        else:
            print result.msgText

    def register(self):
        if self.userName:
            print "please logout first"
        else:
            registerMsg = msgData.RegisterMsg()
            registerMsg.userName = raw_input("entry user name: ")
            registerMsg.passwd = raw_input("entry password: ")
            result = self.sendMsg(registerMsg.serialization())
            print result.msgText

    def logout(self):
        logoutMsg = msgData.LogoutMsg()
        logoutMsg.userName = self.userName
        result = self.sendMsg(logoutMsg.serialization())
        if result.status == 0: self.userName = ""
        print result.msgText

    def save(self):
        saveMsg = msgData.SaveMsg()
        saveMsg.userName = self.userName;
        saveMsg.money = float(raw_input("input sum of money: "))
        result = self.sendMsg(saveMsg.serialization())
        print result.msgText

    def take(self):
        takeMsg = msgData.TakeMsg()
        takeMsg.userName = self.userName
        takeMsg.money = float(raw_input("input sum of money: "))
        result = self.sendMsg(takeMsg.serialization())
        print result.msgText

    def query(self):
        queryMsg = msgData.QueryMsg()
        queryMsg.userName = self.userName
        result = self.sendMsg(queryMsg.serialization())
        if result.status == 0:
            print result.data.get("balance")
        else:
            print result.msgText

    def transfer(self):
        transferMsg = msgData.TransferMsg()
        transferMsg.srcUserName = self.userName
        transferMsg.dstUserName = raw_input("entry user name: ")
        transferMsg.money = float(raw_input("input sum of money: "))
        result = self.sendMsg(transferMsg.serialization())
        print result.msgText

    def check(self):
        checkMsg = msgData.CheckMsg()
        checkMsg.userName = self.userName
        result = self.sendMsg(checkMsg.serialization())
        if result.status == 0:
            records = result.data.get("records")
            for rec in records:
                print rec
        else:
            print result.msgText

    def sendMsg(self, sendData):
        self.sock.send(sendData)
        recvData = self.sock.recv(msgData.buffSize)
        result = msgData.ResultMsg()
        result.deserialization(recvData)
        if result.status == 5: self.userName = ""
        return result

if __name__ == "__main__":
    client = BankClient()
    client.run()
