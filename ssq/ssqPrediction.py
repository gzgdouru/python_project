import sys
import random
from datetime import datetime, date, timedelta
import time
from  parsefile import SSQParse
from  ssqPublic import list2str, dict2list
import requests

class NumProbability:
    def __init__(self, num, count, probability):
        self.num = num
        self.count = count
        self.probability = probability

    def __str__(self):
        strInfo = "num:%d   count:%d    probability:%f" % (self.num, self.count, self.probability)
        return strInfo

    def __lt__(self, other):
        return self.probability < other.probability

class BallStatus:
    def __init__(self, recordCount, balls, rightCount):
        self.recordCount= recordCount
        self.balls = balls
        self.rightCount = rightCount

    def __str__(self):
        strInfo = "recordCount:%d   balls:%s    rightCount:%d" % (self.recordCount, str(self.balls), self.rightCount)
        return strInfo

    def __lt__(self, other):
        return self.rightCount < other.rightCount

class NumCount:
    def __init__(self, numList, count):
        self.numList = numList
        self.count = count

    def __str__(self):
        strInfo = "numList:%s    count:%d" % (str(self.numList), self.count)
        return strInfo

    def __lt__(self, other):
        return self.count < other.count

class SSQ:
    def __init__(self):
        self.record = {}
        #self.getRecordByDB()
        self.getRecordByFile()

    def getRecordByFile(self):
        for line in open("ssq.txt"):
            records = line[:-1].split("\t")
            period = int(records[0])
            openDate = records[1]
            nums = records[2:]
            recordList = []
            recordList.append(openDate)
            [recordList.append(int(num)) for num in nums]
            self.record[period] = recordList

    def timeCheck(self):
        weekDay = date.today().weekday() + 1
        openDay = date.today()
        while weekDay not in (2, 4, 7):
            weekDay += 1
            openDay += timedelta(days=1)
            if weekDay > 7: weekDay = 1
        strOpenDate = openDay.strftime("%Y-%m-%d")
        strOpenDate += " 09:00:00"
        return strOpenDate

    # 生成随机号码
    def getRandomNum(self):
        startTime = time.time()
        numList = []
        openDate = self.timeCheck()
        dt = datetime.strptime(openDate, '%Y-%m-%d %H:%M:%S')
        endTime = time.time()
        numDate = dt.timestamp() + (endTime - startTime)

        while len(numList) < 6:
            startTime = time.time()
            random.seed(numDate)
            num = random.randint(1, 33)
            if num not in numList: numList.append(num)
            endTime = time.time()
            numDate += (endTime - startTime)
        random.seed(numDate)
        numList.sort()
        numList.append(random.randint(1, 16))
        return numList

    # 获取概率最大的蓝区号码
    def getMaxBlueNum(self, top=1, period=None):
        blueNumList, totalCount = self.getNumAndCount(redFlag=False, period=period)
        npList = []
        for i in range(1, 17):
            count = blueNumList.count(i)
            probability = count / totalCount
            numProbabilty = NumProbability(i, count, probability)
            npList.append(numProbabilty)
        npList.sort(reverse=1)
        return npList[0:top]

    # 获取概率最大的红区号码
    def getMaxRedNum(self, top=1, period=None):
        redNumList, totalCount = self.getNumAndCount(period=period)
        npList = []
        for i in range(1, 34):
            count = 0
            for redNum in redNumList:
                if i in redNum: count += 1
            probability = count / totalCount
            numProbability = NumProbability(i, count, probability)
            npList.append(numProbability)
            npList.sort(reverse=1)
        return npList[0:top]

    # 生成概率最大的号码
    def makeBySingle(self):
        redRecords = self.getMaxRedNum(top=6)
        blueRecords = self.getMaxBlueNum()

        balls = []
        [balls.append(record.num) for record in redRecords]
        balls.sort()
        [balls.append(record.num) for record in blueRecords]

        return balls

    # 生成最大概率视图
    def makeView(self):
        redRecords = self.getMaxRedNum(top=33)
        blueRecords = self.getMaxBlueNum(top=16)

        textView = "红区:\n"
        for record in redRecords:
            textView += ("号码:" + str(record.num) + "\t")
            textView += ("次数:" + str(record.count) + "\t")
            textView += ("概率:" + str(record.probability) + "\n")

        textView += "蓝区:\n"
        for record in blueRecords:
            textView += ("号码:" + str(record.num) + "\t")
            textView += ("次数:" + str(record.count) + "\t")
            textView += ("概率:" + str(record.probability) + "\n")

        return textView

    # 获取最佳概率的红区号码
    def getBestRedNum(self, top=1, period=None):
        redNumList, totalCount = self.getNumAndCount(period=period)
        npList = self.getMaxRedNum(top=33)
        for np in npList:
            count = 1
            for redNum in redNumList:
                if np.num in redNum:
                    break
                else:
                    count += 1
            np.probability *= count
        npList.sort(reverse=1)
        return npList[:top]

    # 获取最佳概率的蓝区号码
    def getBestBlueNum(self, top=1, period=None):
        blueNumList, totalCount = self.getNumAndCount(redFlag=False, period=period)
        npList = self.getMaxBlueNum(top=16)
        for np in npList:
            count = 1
            for blueNum in blueNumList:
                if np.num == blueNum:
                    break
                else:
                    count += 1
            np.probability *= count
        npList.sort(reverse=1)
        return npList[:top]

    # 生成最佳概率视图
    def makeBestView(self):
        redRecords = self.getBestRedNum(top=33)
        blueRecords = self.getBestBlueNum(top=16)

        textView = "红区:\n"
        for record in redRecords:
            textView += ("号码:" + str(record.num) + "\t")
            textView += ("次数:" + str(record.count) + "\t")
            textView += ("概率:" + str(record.probability) + "\n")

        textView += "蓝区:\n"
        for record in blueRecords:
            textView += ("号码:" + str(record.num) + "\t")
            textView += ("次数:" + str(record.count) + "\t")
            textView += ("概率:" + str(record.probability) + "\n")

        return textView

    # 生成最佳概率号码
    def makeBestNum(self):
        redRecords = self.getBestRedNum(top=6)
        blueRecords = self.getBestBlueNum()

        balls = []
        [balls.append(record.num) for record in redRecords]
        balls.sort()
        [balls.append(record.num) for record in blueRecords]

        return balls

    # 获取号码列表和记录总数
    def getNumAndCount(self, redFlag=True, period=None):
        numList = []
        for key in self.record.keys():
            if period is None or period >= key:
                if redFlag:
                    nums = self.record[key][1:-1]
                else:
                    nums = self.record[key][-1]
                numList.append(nums)
        totalCount = len(numList)
        return numList, totalCount

    # 获取往期记录视图
    def getHistoryResult(self, top=100):
        text = ""
        count = 0
        for key in self.record.keys():
            count += 1
            text += (list2str(self.record[key]) + "\n")
            if count == top: break
        return text

    # 获取号码的概率
    def getNumProbability(self, num, records):
        size = len(records)
        count = 0
        for record in records:
            if num in record: count += 1
        probability = count / size
        return probability

    # 获取号码的最佳概率
    def getNumBestProbability(self, num, records):
        probability = self.getNumProbability(num, records)
        count = 1
        for record in records:
            if num in record:
                break
            else:
                count += 1
        probability *= count
        return probability

    # 获取指定的往期记录
    def getHistoryRecords(self, period):
        analysisRecord = None
        redRecords = []
        blueRecords = []
        for key in self.record:
            if key <= period:
                if key == period:
                    analysisRecord = self.record[key][1:]
                else:
                    redRecords.append(self.record[key][1:-1])
                    blueRecords.append(self.record[key][-1:])
        return analysisRecord, redRecords, blueRecords

    # 往期记录分析视图
    def historyAnalysis(self, period):
        analysisRecord, redRecords, blueRecords = self.getHistoryRecords(period)
        redBall = analysisRecord[:-1]
        blueBall = analysisRecord[-1]

        text = (str(period) + "\n")
        text += "红区:\n"
        for num in redBall:
            probability = self.getNumBestProbability(num, redRecords)
            text += ("号码:%d\t概率:%f\n" % (num, probability))

        text += "蓝区:\n"
        probability = self.getNumBestProbability(blueBall, blueRecords)
        text += ("号码:%d\t概率:%f\n" % (blueBall, probability))

        return text

    # 同步记录
    def syncsRecord(self):
        url = r"http://datachart.500.com/ssq/history/history.shtml"
        text = ""
        try:
            reponse = requests.get(url)
            reponse.encoding = "gbk"
            html = reponse.text
            ssqParse = SSQParse(html)
            records = ssqParse.parseSSQNum()
            if requests != []:
                ssqParse.writeFile("ssq.txt", records)
                text = "同步记录成功"
            else:
                text = ("同步记录失败,error:解析网址: %s 出错!" % url)
        except Exception as e:
            text = ("同步记录失败, error: %s" % str(e))
        finally:
            self.record.clear()
            self.getRecordByFile()
        return text

    # 生成相似概率的号码
    def makeALikeNum(self, ballsProbability, redFlag=True):
        npList = self.getBestRedNum(top=33) if redFlag else self.getBestBlueNum(top=16)
        nums = []
        for numProbability in ballsProbability:
            gtProbability = None
            ltProbability = None
            allExist = False
            for np in npList:
                if allExist:
                    if np.num not in nums:
                        nums.append(np.num)
                        break
                    else:
                        continue

                if numProbability.probability < np.probability:
                    gtProbability = np
                elif numProbability.probability > np.probability:
                    ltProbability = np
                else:
                    if np.num not in nums:
                        nums.append(np.num)
                        break

                if gtProbability is not None and ltProbability is not None:
                    gtDiff = gtProbability.probability - numProbability.probability
                    ltDiff = numProbability.probability - ltProbability.probability
                    if gtProbability.num in nums and ltProbability.num in nums:
                        allExist = True
                        continue
                    elif gtDiff == ltDiff:
                        num = gtProbability.num if gtProbability.num not in nums else ltProbability.num
                    elif gtDiff < ltDiff and gtProbability.num not in nums:
                        nums.append(gtProbability.num)
                    elif gtDiff > ltDiff and ltProbability.num not in nums:
                        nums.append(ltProbability.num)
                    else:
                        continue
                    break

                if ltProbability is None and np == npList[-1]: nums.append(np.num)
        return nums

    # 获取相似概率的记录
    def getALikeNum(self, period=None):
        errorText = None
        try:
            if period is None:
                #直接取最新一期分析
                for key in self.record.keys():
                    period = key
                    break

            analysisRecord, redRecords, blueRecords = self.getHistoryRecords(period)
            redBallProbability = []
            for redBall in analysisRecord[:-1]:
                probability = self.getNumBestProbability(redBall, redRecords)
                numProbability = NumProbability(redBall, 0, probability)
                redBallProbability.append(numProbability)

            blueBallProbability = []
            blueBall = analysisRecord[-1]
            probability = self.getNumBestProbability(blueBall, blueRecords)
            numProbability = NumProbability(blueBall, 0, probability)
            blueBallProbability.append(numProbability)

            balls = self.makeALikeNum(redBallProbability)
            balls.sort()
            balls.extend(self.makeALikeNum(blueBallProbability, False))
        except Exception as e:
            errorText = ("生成相似概率号码失败,error: %s" % str(e))
        return balls, errorText

    # 获取指定期的最大概率号码
    def getMaxNumForPeriod(self, period):
        balls = []
        redBall = self.getMaxRedNum(top=6, period=period)
        [balls.append(redNum.num) for redNum in redBall]
        balls.sort()

        blueBall = self.getMaxBlueNum(period=period)
        [balls.append(blueNum.num) for blueNum in blueBall]
        return balls

    # 获取指定期的最佳概率号码
    def getBestNumForPeriod(self, period):
        balls = []
        redBall = self.getBestRedNum(top=6, period=period)
        [balls.append(redNum.num) for redNum in redBall]
        balls.sort()

        blueBall = self.getBestBlueNum(period=period)
        [balls.append(blueNum.num) for blueNum in blueBall]
        return balls

    def getALikeNumForPeriod(self, period):
        balls, errorText = self.getALikeNum(period=period)
        return balls, errorText

    def get_max_best_count(self):
        recordCount = 2
        ballRecords = dict2list(self.record)
        bsList = []

        while recordCount < len(ballRecords):
            records = ballRecords[1:recordCount+1]
            redBallList = []
            blueBallList = []
            for record in records:
                redBall = record[1][1:-1]
                blueBall = record[1][-1]
                redBallList.append(redBall)
                blueBallList.append(blueBall)
            redNPList = self.get_max_redBall_ex(redBallList, top=6)
            blueNPList = self.get_max_blueBall_ex(blueBallList)
            ssqBall = self.composition_ssq_ball(redNPList, blueNPList)
            count = self.comparison_ssq_ball(ssqBall)
            ballStatus = BallStatus(recordCount, ssqBall, count)
            bsList.append(ballStatus)
            recordCount += 1

        bsList.sort(reverse=1)
        #[print(bs) for bs in bsList]
        return bsList[0].recordCount

    def get_best_best_count(self):
        recordCount = 2
        ballRecords = dict2list(self.record)
        bsList = []

        while recordCount < len(ballRecords):
            records = ballRecords[1:recordCount + 1]
            redBallList = []
            blueBallList = []
            for record in records:
                redBall = record[1][1:-1]
                blueBall = record[1][-1]
                redBallList.append(redBall)
                blueBallList.append(blueBall)
            redNPList = self.get_best_redBall_ex(redBallList, top=6)
            blueNPList = self.get_best_blueBall_ex(blueBallList)
            ssqBall = self.composition_ssq_ball(redNPList, blueNPList)
            count = self.comparison_ssq_ball(ssqBall)
            ballStatus = BallStatus(recordCount, ssqBall, count)
            bsList.append(ballStatus)
            recordCount += 1

        bsList.sort(reverse=1)
        #[print(bs) for bs in bsList]
        return bsList[0].recordCount

    def get_alike_best_count(self):
        recordCount = 2
        ballRecords = dict2list(self.record)
        bsList = []
        analysisRecord = ballRecords[0][1][1:]

        while recordCount < len(ballRecords):
        #for i in range(1):
            records = ballRecords[1:recordCount + 1]
            redBallList = []
            blueBallList = []
            for record in records:
                redBall = record[1][1:-1]
                blueBall = record[1][-1:]
                redBallList.append(redBall)
                blueBallList.append(blueBall)
            ssqBall, errorText = self.make_alike_num_ex(analysisRecord, redBallList, blueBallList)
            if errorText == "":
                count = self.comparison_ssq_ball(ssqBall)
                ballStatus = BallStatus(recordCount, ssqBall, count)
                bsList.append(ballStatus)
                recordCount += 1
            else:
                return len(ballRecords)

        bsList.sort(reverse=1)
        #[print(bs) for bs in bsList]
        return bsList[0].recordCount

    def get_max_redBall_ex(self, redBallList, top=1):
        npList = []
        totalCount = len(redBallList)
        for i in range(1, 34):
            count = 0
            for redNum in redBallList:
                if i in redNum: count += 1
            probability = count / totalCount
            numProbability = NumProbability(i, count, probability)
            npList.append(numProbability)
            npList.sort(reverse=1)
        return npList[0:top]

    def get_max_blueBall_ex(self, blueBallList, top=1):
        npList = []
        totalCount = len(blueBallList)
        for i in range(1, 17):
            count = blueBallList.count(i)
            probability = count / totalCount
            numProbabilty = NumProbability(i, count, probability)
            npList.append(numProbabilty)
        npList.sort(reverse=1)
        return npList[0:top]

    def composition_ssq_ball(self, redNPList, blueNPList):
        balls = []
        for np in redNPList:
            if len(balls) >= 6: break
            balls.append(np.num)
        balls.sort()
        balls.append(blueNPList[0].num)
        return balls

    def comparison_ssq_ball(self, ssqBall):
        # 获取最新一期号码
        for key in self.record.keys():
            newBall = self.record[key][1:]
            break

        count = 0
        #先比较红球
        for num in ssqBall[:-1]:
            if num in newBall[:-1]:
                count += 1

        #比较篮球
        if ssqBall[-1] == newBall[-1]:count += 1

        return count

    def get_best_redBall_ex(self, redBallList, top=1):
        npList = self.get_max_redBall_ex(redBallList, top=33)
        for np in npList:
            count = 1
            for redNum in redBallList:
                if np.num in redNum:
                    break
                else:
                    count += 1
            np.probability *= count
        npList.sort(reverse=1)
        return npList[:top]

    def get_best_blueBall_ex(self, blueBallList, top=1):
        npList = self.get_max_blueBall_ex(blueBallList, top=16)
        for np in npList:
            count = 1
            for blueNum in blueBallList:
                if np.num == blueNum:
                    break
                else:
                    count += 1
            np.probability *= count
        npList.sort(reverse=1)
        return npList[:top]

    def make_alike_num_ex(self, analysisRecord, redBallList, blueBallList):
        errorText = ""
        balls = []
        try:
            redBallProbability = []
            for redBall in analysisRecord[:-1]:
                probability = self.getNumBestProbability(redBall, redBallList)
                numProbability = NumProbability(redBall, 0, probability)
                redBallProbability.append(numProbability)

            blueBallProbability = []
            blueBall = analysisRecord[-1]
            probability = self.getNumBestProbability(blueBall, blueBallList)
            numProbability = NumProbability(blueBall, 0, probability)
            blueBallProbability.append(numProbability)

            redNPList = self.get_best_redBall_ex(redBallList, top=33)
            balls = self.get_alike_num_ex(redBallProbability, redNPList)
            balls.sort()

            tmpList = []
            [tmpList.append(blueBall[0]) for blueBall in blueBallList]
            blueNPList = self.get_best_blueBall_ex(tmpList, top=16)
            balls.extend(self.get_alike_num_ex(blueBallProbability, blueNPList))
        except Exception as e:
            errorText = ("生成相似概率号码失败,error: %s" % str(e))
        return balls, errorText

    def get_alike_num_ex(self, ballsProbability, npList):
        nums = []
        for numProbability in ballsProbability:
            gtProbability = None
            ltProbability = None
            allExist = False if numProbability.probability < npList[0].probability else True
            for np in npList:
                if allExist:
                    if np.num not in nums:
                        nums.append(np.num)
                        break
                    else:
                        continue

                if numProbability.probability < np.probability:
                    gtProbability = np
                elif numProbability.probability > np.probability:
                    ltProbability = np
                else:
                    if np.num not in nums:
                        nums.append(np.num)
                        break

                if gtProbability is not None and ltProbability is not None:
                    gtDiff = gtProbability.probability - numProbability.probability
                    ltDiff = numProbability.probability - ltProbability.probability
                    if gtProbability.num in nums and ltProbability.num in nums:
                        allExist = True
                        continue
                    elif gtDiff == ltDiff:
                        num = gtProbability.num if gtProbability.num not in nums else ltProbability.num
                    elif gtDiff < ltDiff and gtProbability.num not in nums:
                        nums.append(gtProbability.num)
                    elif gtDiff > ltDiff and ltProbability.num not in nums:
                        nums.append(ltProbability.num)
                    else:
                        continue
                    break

                if ltProbability is None and np == npList[-1]: nums.append(np.num)
        return nums

    def make_max_ball(self):
        recordCount = self.get_max_best_count()
        records = dict2list(self.record)[:recordCount]

        redBallList = []
        blueBallList = []
        for record in records:
            redBall = record[1][1:-1]
            blueBall = record[1][-1]
            redBallList.append(redBall)
            blueBallList.append(blueBall)
        redNPList = self.get_max_redBall_ex(redBallList, top=6)
        blueNPList = self.get_max_blueBall_ex(blueBallList)
        ssqBall = self.composition_ssq_ball(redNPList, blueNPList)
        return list2str(ssqBall)

    def make_best_ball(self):
        recordCount = self.get_best_best_count()
        records = dict2list(self.record)[:recordCount]

        redBallList = []
        blueBallList = []
        for record in records:
            redBall = record[1][1:-1]
            blueBall = record[1][-1]
            redBallList.append(redBall)
            blueBallList.append(blueBall)
        redNPList = self.get_best_redBall_ex(redBallList, top=6)
        blueNPList = self.get_best_blueBall_ex(blueBallList)
        ssqBall = self.composition_ssq_ball(redNPList, blueNPList)
        return list2str(ssqBall)

    def make_alike_ball(self):
        recordCount = self.get_alike_best_count()
        records = dict2list(self.record)[:recordCount]
        bsList = []

        analysisRecord = records[0][1][1:]
        redBallList = []
        blueBallList = []
        for record in records:
            redBall = record[1][1:-1]
            blueBall = record[1][-1:]
            redBallList.append(redBall)
            blueBallList.append(blueBall)

        ssqBall, errorText = self.make_alike_num_ex(analysisRecord, redBallList, blueBallList)
        if errorText != "":
            return errorText
        return list2str(ssqBall)

    def showNumCount(self):
        balls = []
        for key in self.record:
            balls.append(self.record[key][1:])

        totalCount = len(balls)
        ncList = []
        for i in range(totalCount):
            ball = balls[i]
            numCount = NumCount(ball, 0)
            for j in range(totalCount):
                if str(ball) == str(balls[j]):
                    numCount.count += 1
            ncList.append(numCount)

        for nc in ncList:
            print(nc)

    def getNumCount(self, ball):
        balls = []
        for key in self.record:
            balls.append(self.record[key][1:])

        totalCount = len(balls)
        numCount = NumCount(ball, 0)
        for i in range(totalCount):
            if str(ball) == str(balls):
                numCount.count += 1
        return numCount

if __name__ == "__main__":
    ssq = SSQ()
    print(ssq.make_max_ball())
    print(ssq.make_best_ball())

