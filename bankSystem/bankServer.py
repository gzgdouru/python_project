#coding:utf-8
import SocketServer
import json
import msgData
from mysqlDB import mysqlDB, DBConfig
import sys
import socket
import traceback

class BankServer(SocketServer.BaseRequestHandler):
    def setup(self):
        self.ip = self.client_address[0]
        self.port = self.client_address[1]
        self.request.settimeout(60)
        self.userName = None
        self.func = {}
        self.registerFunc()
        print self.ip, ":", self.port, " connect server..."

    def handle(self):
        try:
            while True:
                data = self.request.recv(msgData.buffSize)
                if not data: break
                if data.lower() == "quit":
                    self.request.send("quit")
                    break
                msg = json.loads(data)
                type = msg["msgType"]
                self.msgDeal(type, data)
        except socket.timeout:
            print self.ip, ":", self.port, " recv timeout!"
        except Exception as e:
            traceback.print_exc()

    def registerFunc(self):
        self.func["login"] = self.login
        self.func["register"] = self.register
        self.func["logout"] = self.logout
        self.func["query"] = self.queryBalance
        self.func["save"] = self.saveMoney
        self.func["take"] = self.takeMoney
        self.func["transfer"] = self.transferMoney
        self.func["check"] = self.checkRecord

    def msgDeal(self, msgType, msg):
        opt = self.func.get(msgType)
        if opt:
            opt(msg)
        else:
            print "invalid operation: ", msgType

    def checkLogin(self, userName):
        '''检查是否已经登录'''
        sql = "select status from tb_bank_user where user_name = '%s'" % userName
        bRes, result = mysqlDB.execute(sql)
        if not result:
            bRes = False
        elif result[0].get("status") == 0:
            bRes = False
        else:
            bRes = True
        return bRes

    def login(self, msg):
        loginMsg = msgData.LoginMsg()
        loginMsg.deserialization(msg)
        result = self.loginDeal(loginMsg.userName, loginMsg.passwd)
        self.request.send(result.serialization())

    def loginDeal(self, userName, passWd):
        '''用户登录处理函数'''
        resultMsg = msgData.ResultMsg()
        if self.userName or self.checkLogin(userName):
            resultMsg.status = 3
            resultMsg.msgText = "you already login"
            return resultMsg

        sql = "select passwd from tb_bank_user where user_name = '%s'" % userName
        bRes, result = mysqlDB.execute(sql)
        if not result or len(result) == 0:
            resultMsg.status = 1
            resultMsg.msgText = "user not exits"
        elif result[0].get("passwd") != passWd:
            resultMsg.status = 2
            resultMsg.msgText = "passwd error"
        else:
            self.userName = userName
            sql = "update tb_bank_user set status = 1 where user_name = '%s'" % userName
            bRes, result = mysqlDB.execute(sql)
            resultMsg.status = 0
            resultMsg.msgText = "login success"
        return resultMsg

    def register(self, msg):
        registerMsg = msgData.RegisterMsg()
        registerMsg.deserialization(msg)
        result = self.registerDeal(registerMsg.userName, registerMsg.passwd)
        self.request.send(result.serialization())

    def registerDeal(self, userName, passwd):
        '''用户注册处理函数'''
        resultMsg = msgData.ResultMsg()
        if self.userName:
            resultMsg.status = 2
            resultMsg.msgText = "你已经登录了,请退出登录后再进行账号注册"
            return resultMsg

        sql = "select * from tb_bank_user where user_name = '%s'" % userName
        bRes, result = mysqlDB.execute(sql)
        if not result:
            sql = "insert into tb_bank_user(user_name, passwd) values('%s', '%s')" % (userName, passwd)
            bRes, result = mysqlDB.execute(sql)
            resultMsg.status = 0
            resultMsg.msgText = "register success"
        else:
            resultMsg.status = 1
            resultMsg.msgText = "user already exits"
        return resultMsg

    def logout(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            self.logoutDeal()
            resultMsg.status = 0
            resultMsg.msgText = "logout success"
        self.request.send(resultMsg.serialization())

    def logoutDeal(self):
        sql = "update tb_bank_user set status = 0 where user_name = '%s'" % self.userName
        bRes, result = mysqlDB.execute(sql)
        if bRes: self.userName = None
        return bRes

    def queryBalance(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            queryMsg = msgData.QueryMsg()
            queryMsg.deserialization(msg)
            sql = "select balance from tb_bank_user where user_name = '%s'" % self.userName
            bRes, result = mysqlDB.execute(sql)
            resultMsg.status = 0
            resultMsg.msgText = "query success"
            resultMsg.data["balance"] = float(result[0].get("balance"))
        self.request.send(resultMsg.serialization())

    def saveMoney(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            saveMsg = msgData.SaveMsg()
            saveMsg.deserialization(msg)
            sql = "select balance from tb_bank_user where user_name = '%s'" % self.userName
            bRes, result = mysqlDB.execute(sql)
            balance =  float(result[0].get("balance")) + saveMsg.money
            sql = "update tb_bank_user set balance = %.2f where user_name = '%s'" % (balance, self.userName)
            bRes, result = mysqlDB.execute(sql)
            resultMsg.status = 0
            resultMsg.msgText = "save money success"
            self.saveRecord(self.userName, 1, saveMsg.money)
        self.request.send(resultMsg.serialization())

    def takeMoney(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            takeMsg = msgData.TakeMsg();
            takeMsg.deserialization(msg)
            resultMsg = self.takeMoneyDeal(takeMsg.money)
        self.request.send(resultMsg.serialization())

    def takeMoneyDeal(self, money):
        sql = "select balance from tb_bank_user where user_name = '%s'" % self.userName
        bRes, result = mysqlDB.execute(sql)
        balance = float(result[0].get("balance"))
        resultMsg = msgData.ResultMsg()
        if balance < money:
            resultMsg.status = 2
            resultMsg.msgText = "balance not enough"
        else:
            balance -= money
            sql = "update tb_bank_user set balance = %.2f where user_name = '%s'" % (balance, self.userName)
            bRes, result = mysqlDB.execute(sql)
            resultMsg.status = 0
            resultMsg.msgText = "take money success"
            self.saveRecord(self.userName, 2, money)
        return resultMsg

    def transferMoney(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            transferMsg = msgData.TransferMsg()
            transferMsg.deserialization(msg)
            resultMsg = self.transferMoneyDeal(transferMsg.userName, transferMsg.money)
        self.request.send(resultMsg.serialization())

    def transferMoneyDeal(self, userName, money):
        resultMsg = msgData.ResultMsg()
        try:
            with mysqlDB.lock:
                sql = "select balance from tb_bank_user where user_name = '%s'" % (self.userName)
                mysqlDB.cursor.execute(sql)
                result = mysqlDB.cursor.fetchall()
                srcBalance = float(result[0].get("balance"))
                if srcBalance < money:
                    resultMsg.status = 4
                    resultMsg.msgText = "balance is not enough"
                    return resultMsg

                sql = "select balance from tb_bank_user where user_name = '%s'" % (userName)
                mysqlDB.cursor.execute(sql)
                result = mysqlDB.cursor.fetchall()
                if not result:
                    resultMsg.status = 3
                    resultMsg.msgText = "user %s not exist" % userName
                    return resultMsg
                dstBalance = float(result[0].get("balance"))

                srcBalance -= money
                dstBalance += money

                sql = "update tb_bank_user set balance = %.2f where user_name = '%s'" % (srcBalance, self.userName)
                mysqlDB.cursor.execute(sql)

                sql = "update tb_bank_user set balance = %.2f where user_name = '%s'" % (dstBalance, userName)
                mysqlDB.cursor.execute(sql)

                sql = "insert into tb_bank_record(user_name, type, money, date) values('%s', %d, %f, now())" % (self.userName, 2, money)
                mysqlDB.cursor.execute(sql)

                sql = "insert into tb_bank_record(user_name, type, money, date) values('%s', %d, %f, now())" % (userName, 1, money)
                mysqlDB.cursor.execute(sql)

                mysqlDB.connection.commit()
                resultMsg.status = 0
                resultMsg.msgText = "tranfer money success"
        except Exception as e:
            mysqlDB.connection.rollback()
            resultMsg.status = 2
            resultMsg.msgText = "transfer money failed"
        return resultMsg

    def saveRecord(self, userName, type, money):
        sql = "insert into tb_bank_record(user_name, type, money, date) values('%s', %d, %f, now())" % (userName, type, money)
        bRes, result = mysqlDB.execute(sql)

    def checkRecord(self, msg):
        resultMsg = msgData.ResultMsg()
        if not self.userName:
            resultMsg.status = 1
            resultMsg.msgText = "please login first"
        else:
            sql = "select type, money, date from tb_bank_record where user_name = '%s'" % self.userName
            bRes, result = mysqlDB.execute(sql)
            resultList = []
            for res in result:
                recordType = "transfer in" if res.get("type") == 1 else "transfer out"
                recordMoney = res.get("money")
                recordTime = res.get("date")
                resultList.append("[%s]%s %.2f" % (recordTime, recordType, recordMoney))
            resultMsg.status = 0
            resultMsg.msgText = "check record success"
            resultMsg.data["record"] = resultList
        self.request.send(resultMsg.serialization())

    def finish(self):
        if self.userName: self.logoutDeal()
        print self.ip, ":", self.port, " quit server..."

if __name__ == "__main__":
    myHost = ""
    myPort = 10002
    myAddr = (myHost, myPort)
    server = SocketServer.ThreadingTCPServer(myAddr, BankServer)

    dbConfig = DBConfig().getdict()
    mysqlDB.connectDB(dbConfig)

    print "bank server start success..."
    server.serve_forever()