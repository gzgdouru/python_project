<<<<<<< HEAD
#coding:utf-8
from datetime import datetime
import os, time, sys
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import email.utils
import logging

config = {
    "pgLogDir" : "F:/",     #postgres数据库日志文件路径
    "filePre" : "postgresql-",  #数据库日志文件前缀
    "fileSuff" : ".log",    #数据库日志文件后缀
    "sender" : "18719091650@163.com",   #邮件发送者账号
    "passWd": "5201314ouru...",  # 邮件发送者密码
    "receiver" : "gzgdouru@163.com",    #邮件接收者账号
    "subject" : "postgresql error",     #邮件标题
    "smtpServer" : "smtp.163.com",      #邮件服务器
    "chart" : "utf-8",       #字符集
    "level" : ["error", "log"]  #监控的错误等级
}

logConfig = {
    "logName" : "postgres_watch",
    "logFile" : "postgresWatch.log",
    "logLevel" : logging.INFO,
    "logFormatter" : "[%(asctime)s] [%(levelname)s]: %(message)s"
}

class DatabaseWatch:
    def __init__(self):
        self.pgLogDir = config.get("pgLogDir", None)
        self.filePre = config.get("filePre", None)
        self.fileSuff = config.get("fileSuff", None)
        self.level = config.get("level", None)    #等级
        self.charCount = 0   #偏移量
        self.sender = config.get("sender", None)
        self.receiver = config.get("receiver", None)
        self.subject = config.get("subject", None)
        self.smtpServer = config.get("smtpServer", None)
        self.passWd = config.get("passWd", None)
        self.chart = config.get("chart", None)
        self.sourceFile = self.pgLogDir + os.sep + self.filePre + datetime.now().strftime("%a") + self.fileSuff
        self.initLog()

    def initLog(self):
        '''
        self.logger = logging.getLogger(logConfig.get("logName"))
        self.logger.setLevel(logConfig.get("logLevel"))

        self.flogger = logging.FileHandler(logConfig.get("logFile"))
        self.flogger.setLevel(logConfig.get("logLevel"))
        formatter = logging.Formatter(logConfig.get("logFormatter"))
        self.flogger.setFormatter(formatter)

        self.logger.addHandler(self.flogger)
        '''

        logFile = logConfig.get("logFile")
        logLevel = logConfig.get("logLevel")
        formatter = logConfig.get("logFormatter")
        logging.basicConfig(filename=logFile, level=logLevel, format=formatter, filemode="w")

    def checkError(self, line):
        errorContent = ""
        for str in self.level:
            if line.find(str.upper()) != -1:
                errorContent = line
                break
        return errorContent

    def sendEmail(self, errorContent):
        try:
            server = smtplib.SMTP(self.smtpServer)  # 初始化邮件服务
            server.login(self.sender, self.passWd)  # 登入邮件服务
            msg = MIMEText(errorContent, "plain", self.chart)
            msg["Subject"] = self.subject
            #msg["Date"] = email.utils.formatdate()
            msg["From"] = self.sender
            msg["To"] = self.receiver
            server.sendmail(self.sender, self.receiver, msg.as_string())
            server.quit()
        except:
            logging.error(sys.exc_info()[1])

    def getErrorContent(self, fileName):
        errorContent = ""
        pfile = None
        try:
            pfile = open(fileName, "r")
            pfile.seek(self.charCount)
            for line in pfile:
                errorContent += self.checkError(line)
                self.charCount += len(line)
        except:
            logging.error(sys.exc_info()[1])
        finally:
            if pfile: pfile.close()
        return errorContent

    def switchDeal(self):
        errorCount = self.getErrorContent(self.sourceFile)
        self.charCount = 0
        if errorCount: self.sendEmail(errorCount)

    def run(self):
        while True:
            newFile = self.pgLogDir + os.sep + self.filePre + datetime.now().strftime("%a") + self.fileSuff
            #self.logger.info("sourceFile: %s, newFile: %s" % (self.sourceFile, newFile))
            logging.info("sourceFile: %s, newFile: %s" % (self.sourceFile, newFile))
            if self.sourceFile != newFile:
                self.switchDeal()
                self.sourceFile = newFile

            errorContent = self.getErrorContent(newFile)
            if errorContent: self.sendEmail(errorContent)

            time.sleep(30)

if __name__ == "__main__":
    postgresWatch = DatabaseWatch()
=======
#coding:utf-8
from datetime import datetime
import os, time, sys
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import email.utils
import logging

config = {
    "pgLogDir" : "F:/",     #postgres数据库日志文件路径
    "filePre" : "postgresql-",  #数据库日志文件前缀
    "fileSuff" : ".log",    #数据库日志文件后缀
    "sender" : "18719091650@163.com",   #邮件发送者账号
    "passWd": "5201314ouru...",  # 邮件发送者密码
    "receiver" : "gzgdouru@163.com",    #邮件接收者账号
    "subject" : "postgresql error",     #邮件标题
    "smtpServer" : "smtp.163.com",      #邮件服务器
    "chart" : "utf-8",       #字符集
    "level" : ["error", "log"]  #监控的错误等级
}

logConfig = {
    "logName" : "postgres_watch",
    "logFile" : "postgresWatch.log",
    "logLevel" : logging.INFO,
    "logFormatter" : "[%(asctime)s] [%(levelname)s]: %(message)s"
}

class DatabaseWatch:
    def __init__(self):
        self.pgLogDir = config.get("pgLogDir", None)
        self.filePre = config.get("filePre", None)
        self.fileSuff = config.get("fileSuff", None)
        self.level = config.get("level", None)    #等级
        self.charCount = 0   #偏移量
        self.sender = config.get("sender", None)
        self.receiver = config.get("receiver", None)
        self.subject = config.get("subject", None)
        self.smtpServer = config.get("smtpServer", None)
        self.passWd = config.get("passWd", None)
        self.chart = config.get("chart", None)
        self.sourceFile = self.pgLogDir + os.sep + self.filePre + datetime.now().strftime("%a") + self.fileSuff
        self.initLog()

    def initLog(self):
        '''
        self.logger = logging.getLogger(logConfig.get("logName"))
        self.logger.setLevel(logConfig.get("logLevel"))

        self.flogger = logging.FileHandler(logConfig.get("logFile"))
        self.flogger.setLevel(logConfig.get("logLevel"))
        formatter = logging.Formatter(logConfig.get("logFormatter"))
        self.flogger.setFormatter(formatter)

        self.logger.addHandler(self.flogger)
        '''

        logFile = logConfig.get("logFile")
        logLevel = logConfig.get("logLevel")
        formatter = logConfig.get("logFormatter")
        logging.basicConfig(filename=logFile, level=logLevel, format=formatter, filemode="w")

    def checkError(self, line):
        errorContent = ""
        for str in self.level:
            if line.find(str.upper()) != -1:
                errorContent = line
                break
        return errorContent

    def sendEmail(self, errorContent):
        try:
            server = smtplib.SMTP(self.smtpServer)  # 初始化邮件服务
            server.login(self.sender, self.passWd)  # 登入邮件服务
            msg = MIMEText(errorContent, "plain", self.chart)
            msg["Subject"] = self.subject
            #msg["Date"] = email.utils.formatdate()
            msg["From"] = self.sender
            msg["To"] = self.receiver
            server.sendmail(self.sender, self.receiver, msg.as_string())
            server.quit()
        except:
            logging.error(sys.exc_info()[1])

    def getErrorContent(self, fileName):
        errorContent = ""
        pfile = None
        try:
            pfile = open(fileName, "r")
            pfile.seek(self.charCount)
            for line in pfile:
                errorContent += self.checkError(line)
                self.charCount += len(line)
        except:
            logging.error(sys.exc_info()[1])
        finally:
            if pfile: pfile.close()
        return errorContent

    def switchDeal(self):
        errorCount = self.getErrorContent(self.sourceFile)
        self.charCount = 0
        if errorCount: self.sendEmail(errorCount)

    def run(self):
        while True:
            newFile = self.pgLogDir + os.sep + self.filePre + datetime.now().strftime("%a") + self.fileSuff
            #self.logger.info("sourceFile: %s, newFile: %s" % (self.sourceFile, newFile))
            logging.info("sourceFile: %s, newFile: %s" % (self.sourceFile, newFile))
            if self.sourceFile != newFile:
                self.switchDeal()
                self.sourceFile = newFile

            errorContent = self.getErrorContent(newFile)
            if errorContent: self.sendEmail(errorContent)

            time.sleep(30)

if __name__ == "__main__":
    postgresWatch = DatabaseWatch()
>>>>>>> 31b751da9cab8c64478d0c061b88c453fb75d14a
    postgresWatch.run()