import sys
import os
import random
from datetime import datetime
from enum import Enum
import re

class TransMode(Enum):
    c2e = 1 # chinese->english
    e2c = 2 # english->chinese

class ComparType(Enum):
    inclusive = 1
    equal = 2

class WordSpell:
    sourceDir = "data_source/"
    lessonDir = "data_source/lessons/"
    errorWordCFile = (sourceDir + "error_word_chinese.txt")
    errorWordEFile = (sourceDir + "error_word_english.txt")
    def __init__(self):
        self.wordFile = WordSpell.sourceDir + "base_data.txt"
        self.loadData()

    def loadData(self):
        self.datas = {}
        for line in open(self.wordFile):
            record = line[:-1].split("|") if line[-1] == "\n" else line.split("|")
            self.datas[record[0]] = record[1]

    def showDatas(self):
        for word in self.datas.keys():
            print(word, self.datas[word])

    def getRadomDatas(self, top=30):
        size = len(self.datas)
        count = top if size >= top else size
        records = random.sample(self.datas.keys(), count)
        titleList = []
        answerList = []
        for word in records:
            titleList.append(word)
            answerList.append(self.datas[word])
        return titleList, answerList

    def getLastDatas(self, top=30):
        size = len(self.datas)
        count = top if size >= top else size
        titleList = []
        answerList = []
        for word in self.datas:
            titleList.append(word)
            answerList.append(self.datas[word])
            if count <= len(titleList): break
        titleList.reverse()
        answerList.reverse()
        return titleList, answerList

    def addWord(self, word, trans):
        text = ""
        try:
            if word in self.datas.keys():
                text = "word is already exist!"
            elif word == "" or trans == "":
                text = "word or translation is empty!"
            else:
                record = (word + "|" + trans + "\n")
                fileObj = open(self.wordFile, "a+")
                fileObj.write(record)
                fileObj.close()
                self.datas[word] = trans
                text = "add word success."
        except Exception as e:
            text = str(e)
        return text

    @staticmethod
    def getComparMode(title):
        comparMode = ComparType.equal
        matchObj = re.match(r"[a-z][A-Z]+.*", title, re.M|re.I)
        if matchObj:
            comparMode = ComparType.inclusive
        return comparMode

    @staticmethod
    def singleComp(title, answer, commit):
        resultText = ""
        if title != "": title = title if title[-1] != "\n" else title[:-1]
        if answer != "": answer = answer if answer[-1] != "\n" else answer[:-1]
        if commit != "": commit = commit if commit[-1] != "\n" else commit[:-1]

        comparMode = WordSpell.getComparMode(title)
        if comparMode == ComparType.equal:
            if answer.lower() != commit.lower(): resultText = ("%s|%s|%s\n" % (title, answer, commit))
        else:
            if commit == "" or answer.find(commit) == -1: resultText += ("%s|%s|%s\n" % (title, answer, commit))

        return resultText

    @staticmethod
    def answerComp(titleList, answerList, commitList):
        resultText = ""
        size = len(answerList)
        while len(commitList) < size: commitList.append("")

        for i in range(size):
           resultText += WordSpell.singleComp(titleList[i], answerList[i], commitList[i])

        if resultText == "":
            resultText = "No error!"

        return resultText

    @staticmethod
    def getLessonContent(lesson, mode):
        errorText = ""
        try:
            if mode == TransMode.c2e:
                contentFile = WordSpell.lessonDir + lesson + "_chinese.txt"
                answerFile = WordSpell.lessonDir + lesson + "_english.txt"
            elif mode == TransMode.e2c:
                answerFile = WordSpell.lessonDir + lesson + "_chinese.txt"
                contentFile = WordSpell.lessonDir + lesson + "_english.txt"
            contetList = []
            answerList = []
            [contetList.append(line) for line in open(contentFile)]
            [answerList.append(line) for line in open(answerFile)]
        except Exception as e:
            errorText = str(e)
        return contetList, answerList, errorText

    @staticmethod
    def getLessonName():
        fileList = os.listdir(WordSpell.lessonDir)
        lessonList = []
        for file in fileList:
            pos = file.rfind("_")
            if pos != -1 and file[:pos] not in lessonList:
                lessonList.append(file[:pos])
        return lessonList

    @staticmethod
    def getRandomLesson():
        fileList = os.listdir(WordSpell.lessonDir)
        file = random.choice(fileList)
        pos = file.rfind("_")
        if pos != -1: lesson = file[:pos]
        return lesson

    @staticmethod
    def addLesson(lessonNum, content, translation):
        text = ""
        try:
            lessonList = WordSpell.getLessonName()
            if lessonNum in lessonList:
                text = ("lesson %s already exist!" % lessonNum)
            elif content == "" or translation == "":
                text = "content or translation is empty!"
            else:
                if content[-1] != "\n": content += "\n"
                if translation[-1] != "\n": translation += "\n"
                text = WordSpell.writeLesson(lessonNum, content, translation)
        except Exception as e:
            text = str(e)
        return text

    @staticmethod
    def writeLesson(lessonNum, content, translation):
        text = ""
        try:
            contentSuffixe = "_english.txt"
            translationSuffix = "_chinese.txt"

            filePath = (WordSpell.lessonDir + lessonNum + contentSuffixe)
            fileObj = open(filePath, "w+")
            fileObj.write(content)
            fileObj.close()

            filePath = (WordSpell.lessonDir + lessonNum + translationSuffix)
            fileObj = open(filePath, "w+")
            fileObj.write(translation)
            fileObj.close()

            text = "save lesson success."
        except Exception as e:
            text = str(e)
        return text

    @staticmethod
    def getErrorWord(filePath):
        errorText = ""
        wordList = []
        try:
            wordList = WordSpell.text2word(open(filePath).read())
        except Exception as e:
            errorText = str(e)
        return wordList, errorText

    @staticmethod
    def writErrorWord(text, filePath):
        errorText = ""
        try:
            wordList =  WordSpell.text2word(open(filePath).read())
            wordKeys = []
            [wordKeys.append(word[0]) for word in wordList]

            errorWordList = WordSpell.text2word(text)
            [wordList.append(record) for record in errorWordList if record[0] not in wordKeys]

            fileObj = open(filePath, "w+")
            [fileObj.write(record[0] + "|" + record[1] + "|" + record[2] + "\n") for record in wordList]
            fileObj.close()
        except Exception as e:
            errorText = str(e)
        return errorText

    @staticmethod
    def clearErrorWord(filePath):
        errorText = ""
        try:
            fileObj = open(filePath, "w+")
            fileObj.close()
        except Exception as e:
            errorText = str(e)
        return errorText

    @staticmethod
    def text2word(text):
        wordLine = text.split("\n")
        wordList = []
        for line in wordLine:
            record = line.split("|")
            if len(record) >= 3:
                word = record[0]
                translation = record[1]
                commit = record[2]
                wordList.append([word, translation, commit])
        return wordList

    @staticmethod
    def copyFile(fileFrom, fileTo, maxFileLoad=1000000, blkSize=1024*500):
        if os.path.getsize(fileFrom) <= maxFileLoad:
            bytesFrom = open(fileFrom, "rb").read()
            open(fileTo, "wb").write(bytesFrom)
        else:
            fileFromObj = open(fileFrom, "rb")
            fileToObj = open(fileTo, "wb")
            while True:
                bytesFrom = fileFromObj.read(blkSize)
                if not bytesFrom: break
                fileToObj.write(bytesFrom)
            fileFromObj.close()
            fileToObj.close()

    @staticmethod
    def datasBackup(dirFrom, dirTo):
        errorText = ""
        try:
            if not os.path.exists(dirTo): os.mkdir(dirTo)
            for (thisDir, subsHere, filesHere) in os.walk(dirFrom):
                pos = str(thisDir).find(dirFrom)
                tempPath = "" if (pos != -1 and thisDir == dirFrom) else thisDir[pos + len(dirFrom):]
                dirPath = dirTo + tempPath
                if not os.path.exists(dirPath): os.mkdir(dirPath)
                for fileName in filesHere:
                    fileFrom = os.path.join(thisDir, fileName)
                    fileTo = os.path.join(dirPath, fileName)
                    WordSpell.copyFile(fileFrom, fileTo)
        except Exception as e:
            errorText = str(e)
        return errorText

    @staticmethod
    def getBackupDir():
        now = datetime.now().strftime("%Y%m%d")
        srcDir = WordSpell.sourceDir if WordSpell.sourceDir[-1] != "/" else WordSpell.sourceDir[:-1]
        dstDir = (srcDir + "_" + now + "/")
        return dstDir

if __name__ == "__main__":
    wordSpell = WordSpell()
    backupDir = WordSpell.getBackupDir()
    print(WordSpell.getLessonName())
    # text = WordSpell.datasBackup(WordSpell.sourceDir, backupDir)
    # print(text)
    #wordList = WordSpell.getErrorWord()
    #print(wordList)