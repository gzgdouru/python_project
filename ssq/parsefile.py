from bs4 import BeautifulSoup
import requests
from  ssqPublic import list2str
from datetime import datetime

class SSQParse:
    def __init__(self, html):
        self.html = html

    def parseRedBall(self, node):
        balls = node.span.string
        for sibling in node.span.next_siblings:
            ball = sibling.string
            if ball is not None:
                balls += sibling.string
        return "\t".join(balls.split())

    def parseBlueBall(self, node):
        blueBall = list(node.span.strings)[0]
        return blueBall.strip()

    def combineRecord(self, perdadility, ssqDate, redBall, blueBall):
        record = (perdadility, ssqDate[:10], redBall, blueBall)
        record = "\t".join(record)
        record = record.replace("&nbsnbsp;", "\t")
        record = record.replace("nbsp;", "")
        return record

    def parseSSQNum(self):
        soup = BeautifulSoup(self.html, "html.parser")
        subNode = None
        for child in soup.body.children:
            flag = child.find("table")
            if flag != -1:
                try:
                    subNode = child.table.div
                except Exception as e:
                    pass

        ssqNode = None
        divList = subNode.find_all("div")
        for div in divList:
            try:
                if div["class"][0] == "chart":
                    ssqNode = div.table.tbody
            except Exception as e:
                pass

        records = []
        trList = ssqNode.find_all("tr")
        for tr in trList:
                record = []
                periodNode = tr.td
                record.append(self.formatPeriod(periodNode.string))
                for sibling in periodNode.next_siblings:
                    record.append(sibling.string)

                redBall = list2str(record[1:7], "\t")
                blueBall = record[7]
                record = self.combineRecord(record[0], record[-1], redBall, blueBall)
                records.append(record + "\n")

        return records

    def formatPeriod(self, period):
        strYear = str(datetime.now().year)[:2]
        return (strYear + period)

    def writeFile(self, filePath, records):
        datas = []
        for line in open(filePath):
            datas.append(line)

        for record in records:
            if record not in datas:
                datas.append(record)

        datas.sort(reverse=1)
        writeObj = open(filePath, "w+")
        for data in datas:
            writeObj.write(data)
        writeObj.close()

if __name__ == "__main__":
    url = r"http://datachart.500.com/ssq/history/history.shtml"
    reponse = requests.get(url)
    reponse.encoding = "gbk"
    html = reponse.text
    ssqParse = SSQParse(html)
    records = ssqParse.parseSSQNum()
    for record in records:
        print(record[:-1])