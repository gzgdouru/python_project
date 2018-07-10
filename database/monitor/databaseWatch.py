<<<<<<< HEAD
#coding:utf-8
from datetime import datetime
import os, time
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import email.utils

#pgLogDir = "/usr/local/pgsql/9.6/data/pg_log"
pgLogDir = "F:/"
filePre = "postgresql-"
fileSuff = ".log"
level = ["error", "log"]
charCount = 0
oldFile = pgLogDir + os.sep + filePre + datetime.now().strftime("%a") + fileSuff

sender = "18719091650@163.com"
receiver = "gzgdouru@163.com"
subject = "postgresql"
smtpServer = "smtp.163.com"
passWd = "5201314ouru..."
chart = "utf-8"
date = email.utils.formatdate()

def checkError(line, errorContent):
    for str in level:
        if line.find(str.upper()) != -1:
            errorContent += line

    return errorContent

def switchDeal():
    global charCount
    pfile = open(oldFile, "r")
    pfile.seek(charCount)
    errorCount = ""

    for line in pfile:
        errorCount = checkError(line, errorCount)
        charCount += len(line)
    pfile.close()
    charCount = 0
    if errorCount: sendEmail(errorCount)

def sendEmail(errorContent):
    msg = MIMEText(errorContent, "plain", chart)
    msg["Subject"] = subject
    msg["Date"] = date
    msg["From"] = sender
    msg["To"] = receiver
    server = smtplib.SMTP(smtpServer)
    server.login(sender, passWd)
    print msg.as_string()
    server.sendmail(sender, receiver, msg.as_string())

while True:
    file = pgLogDir + os.sep + filePre + datetime.now().strftime("%a") + fileSuff
    if oldFile != file: switchDeal()
    pfile = open(file, "r")
    pfile.seek(charCount)
    errorContent = ""

    for line in pfile:
        errorContent = checkError(line, errorContent)
        charCount += len(line)

    pfile.close()
    if errorContent: sendEmail(errorContent)

=======
#coding:utf-8
from datetime import datetime
import os, time
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import email.utils

#pgLogDir = "/usr/local/pgsql/9.6/data/pg_log"
pgLogDir = "F:/"
filePre = "postgresql-"
fileSuff = ".log"
level = ["error", "log"]
charCount = 0
oldFile = pgLogDir + os.sep + filePre + datetime.now().strftime("%a") + fileSuff

sender = "18719091650@163.com"
receiver = "gzgdouru@163.com"
subject = "postgresql"
smtpServer = "smtp.163.com"
passWd = "5201314ouru..."
chart = "utf-8"
date = email.utils.formatdate()

def checkError(line, errorContent):
    for str in level:
        if line.find(str.upper()) != -1:
            errorContent += line

    return errorContent

def switchDeal():
    global charCount
    pfile = open(oldFile, "r")
    pfile.seek(charCount)
    errorCount = ""

    for line in pfile:
        errorCount = checkError(line, errorCount)
        charCount += len(line)
    pfile.close()
    charCount = 0
    if errorCount: sendEmail(errorCount)

def sendEmail(errorContent):
    msg = MIMEText(errorContent, "plain", chart)
    msg["Subject"] = subject
    msg["Date"] = date
    msg["From"] = sender
    msg["To"] = receiver
    server = smtplib.SMTP(smtpServer)
    server.login(sender, passWd)
    print msg.as_string()
    server.sendmail(sender, receiver, msg.as_string())

while True:
    file = pgLogDir + os.sep + filePre + datetime.now().strftime("%a") + fileSuff
    if oldFile != file: switchDeal()
    pfile = open(file, "r")
    pfile.seek(charCount)
    errorContent = ""

    for line in pfile:
        errorContent = checkError(line, errorContent)
        charCount += len(line)

    pfile.close()
    if errorContent: sendEmail(errorContent)

>>>>>>> 31b751da9cab8c64478d0c061b88c453fb75d14a
    time.sleep(0.5)