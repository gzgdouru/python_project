import sys

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import QApplication
from PyQt5.QtWidgets import QLabel, QWidget, QLineEdit, QGridLayout
from PyQt5.QtWidgets import QPushButton, QTextEdit, QComboBox, QMessageBox
from wordSpell import WordSpell, ComparType, TransMode
from  publicFunc import list2str, str2list, dict2list
import random

# make word exercise
class MakeWordExerWindow(QWidget):
    def __init__(self, titleList, answerList, msgSignal):
        super().__init__()
        self.titleList = titleList
        self.answerList = answerList
        self.msgSignal = msgSignal
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        lineList = []
        row = 0
        col = 0
        for title in self.titleList:
            titleLabel = QLabel(title)
            answerLE  = QLineEdit()
            lineList.append(answerLE)
            grid.addWidget(titleLabel, row, col)
            col += 1
            grid.addWidget(answerLE, row, col)
            col += 1
            if col == 10:
                row += 1
                col = 0

        commitBT = QPushButton("commit test")
        commitBT.clicked.connect(lambda: self.commit(lineList))
        grid.addWidget(commitBT, row+1, 0)

        self.setLayout(grid)
        self.setWindowTitle("word test")

    def commit(self, lineList):
        textList = []
        for answer in lineList:
            textList.append(answer.text())

        text = WordSpell.answerComp(self.titleList, self.answerList, textList)
        text = "error word:\n" + text

        # send signal
        self.msgSignal.emit("clear")
        self.msgSignal.emit(text)
        self.close()
        # self.showUI = ShowWindow("result", text)
        # self.showUI.show()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

#make word test
class MakeWordTestWindow(QWidget):
    def __init__(self, wordList, errorWordFile):
        super().__init__()
        self.wordList = wordList
        self.errorWordFile = errorWordFile
        self.index = 0
        self.totalCount = len(wordList)
        self.rightCount = 0
        self.errorCount = 0
        self.errorWord = ""
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        word = self.wordList[0][0]

        self.totalLabel = QLabel("total:" + str(self.totalCount))
        grid.addWidget(self.totalLabel, 0, 0)

        self.currentLabel = QLabel("current:" + str(self.index + 1))
        grid.addWidget(self.currentLabel, 0, 1)

        self.rightLabel = QLabel("right:" + str(self.rightCount))
        grid.addWidget(self.rightLabel, 1, 0)

        self.errorLabel = QLabel("error:" + str(self.errorCount))
        grid.addWidget(self.errorLabel, 1, 1)

        self.transLB = QLabel(word)
        grid.addWidget(self.transLB, 2, 0)

        self.wordLE = QLineEdit()
        grid.addWidget(self.wordLE, 2, 1)

        commitBT = QPushButton("commit")
        commitBT.clicked.connect(self.commit)
        grid.addWidget(commitBT, 3, 0)

        self.setLayout(grid)
        self.setWindowTitle("make word test")
        self.move(600, 400)

    def commit(self):
        word = self.wordList[self.index][0]
        trans = self.wordList[self.index][1]
        commitText = self.wordLE.text()

        text = WordSpell.singleComp(word, trans, commitText)
        if text != "":
            QMessageBox.about(None, "error", text)
            self.errorWord += text
            self.errorCount += 1
        else:
            self.rightCount += 1

        self.index += 1
        if self.index >= self.totalCount:
            self.showEndHint()
            self.saveErrorWord(self.errorWord)
            self.close()
        else:
            self.totalLabel.setText("total: " + str(self.totalCount))
            self.currentLabel.setText("current: " + str(self.index + 1))
            self.rightLabel.setText("right: " + str(self.rightCount))
            self.errorLabel.setText("error: " + str(self.errorCount))
            word = self.wordList[self.index][0]
            self.transLB.setText(word)
            self.wordLE.clear()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.showEndHint()
            self.saveErrorWord(self.errorWord)
            self.close()
        elif e.key() == Qt.Key_Enter or e.key() == Qt.Key_Return:
            self.commit()

    def showEndHint(self):
        text = "word exercises end\n"
        text += ("total:%d right:%d error:%d" % (self.totalCount, self.rightCount, self.errorCount))
        QMessageBox.about(None, "hint", text)

    def saveErrorWord(self, errorWord):
        text = WordSpell.writErrorWord(errorWord, self.errorWordFile)
        if text != "": QMessageBox.about(None, "error hint", text)

#make lesson exercise
class MakeLessExerWindow(QWidget):
    def __init__(self, mode, msgSignal):
        super().__init__()
        self.mode = mode
        self.msgSignal = msgSignal
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        self.lessonCb = QComboBox()
        self.makeItem()
        grid.addWidget(self.lessonCb, 0, 0)

        makeBT = QPushButton("make lesson")
        makeBT.clicked.connect(self.makeLesson)
        grid.addWidget(makeBT, 1, 0)

        self.setLayout(grid)
        self.setWindowTitle("Lesson Exercise")
        self.setGeometry(700, 400, 150  , 50)

    def makeItem(self):
        lessonList = WordSpell.getLessonName()
        index = 0
        for item in lessonList:
            self.lessonCb.insertItem(index, item)
            index += 1

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

    def makeLesson(self):
        self.close()
        lesson = self.lessonCb.currentText()
        self.lessonUI = LessonWindow(lesson, self.mode, self.msgSignal)

class LessonWindow(QWidget):
    def __init__(self, lesson, mode, msgSignal):
        super().__init__()
        self.lesson = lesson
        self.mode = mode
        self.msgSignal = msgSignal
        self.makeLesson()

    def makeLesson(self):
        contentList, answerList, errorText = WordSpell.getLessonContent(self.lesson, self.mode)
        if errorText == "":
            self.showLessonContent(contentList)
            self.showLessonWriting(answerList)
        else:
            QMessageBox.warning(None, "getLessonContent():", errorText)

    def showLessonContent(self, contentList):
        content = list2str(contentList, "")
        self.msgSignal.emit("clear")
        self.msgSignal.emit(content)

    def showLessonWriting(self, answerList):
        self.lessonWritingUI = LessonWritingWindow(answerList)
        self.lessonWritingUI.show()

#lesson write window
class LessonWritingWindow(QWidget):
    def __init__(self, answerList):
        super().__init__()
        self.answerList = answerList
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        self.lessonText = QTextEdit()
        font = QFont()
        font.setPointSize(14)
        self.lessonText.setFont(font)
        grid.addWidget(self.lessonText, 0, 0)

        commitBT = QPushButton("look at answer")
        commitBT.clicked.connect(self.commit)
        grid.addWidget(commitBT, 0, 1)

        self.setLayout(grid)
        self.setWindowTitle("lesson writing")
        self.setGeometry(960, 200, 680, 480)

    def commit(self):
        answer = list2str(self.answerList, "")
        self.answerWindow = ShowWindow("Lesson Exercise Answer", answer)
        self.answerWindow.show()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

#add word
class AddWordWindow(QWidget):
    def __init__(self, wordSpell):
        super().__init__()
        self.wordSpell = wordSpell
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        wordLB = QLabel("word:")
        grid.addWidget(wordLB, 0, 0)

        self.wordLE = QLineEdit()
        grid.addWidget(self.wordLE, 0, 1)

        transLB = QLabel("translation:")
        grid.addWidget(transLB, 1, 0)

        self.transLE = QLineEdit()
        grid.addWidget(self.transLE, 1, 1)

        saveBT = QPushButton("save")
        saveBT.clicked.connect(self.save)
        grid.addWidget(saveBT, 2, 0)

        self.setLayout(grid)
        self.setWindowTitle("add word")
        self.move(700, 400)

    def save(self):
        word = self.wordLE.text()
        trans = self.transLE.text()
        text = self.wordSpell.addWord(word, trans)
        if text == "add word success.":
            self.wordLE.clear()
            self.transLE.clear()
        QMessageBox.about(None, "add word result", text)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()
        elif e.key() == Qt.Key_Enter or e.key() == Qt.Key_Return:
            self.save()

#add lesson
class AddLessonWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        font = QFont()
        font.setPointSize(14)

        lessonLB = QLabel("lesson:")
        grid.addWidget(lessonLB, 0, 0)

        self.lessonLE = QLineEdit()
        self.lessonLE.setFont(font)
        grid.addWidget(self.lessonLE, 0, 1)

        contentLB = QLabel("english:")
        grid.addWidget(contentLB, 1, 0)

        self.contentTE = QTextEdit()
        self.contentTE.setFont(font)
        grid.addWidget(self.contentTE, 1, 1)

        transLB = QLabel("chinese:")
        grid.addWidget(transLB, 2, 0)

        self.transTE = QTextEdit()
        self.transTE.setFont(font)
        grid.addWidget(self.transTE, 2, 1)

        saveBT = QPushButton("save")
        saveBT.clicked.connect(self.save)
        grid.addWidget(saveBT, 3, 0)

        self.setLayout(grid)
        self.setWindowTitle("add lesson")
        self.setGeometry(700, 250, 680, 480)

    def save(self):
        lessonNum = self.lessonLE.text()
        content = self.contentTE.toPlainText()
        translation = self.transTE.toPlainText()
        text = WordSpell.addLesson(lessonNum, content, translation)
        if text == "save lesson success.":
            self.lessonLE.clear()
            self.contentTE.clear()
            self.transTE.clear()
        QMessageBox.about(None, "add lesson result", text)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

#show window
class ShowWindow(QWidget):
    def __init__(self, title="", text=""):
        super().__init__()
        self.text = text
        self.title = title
        self.initUI()

    def initUI(self):
        contentEdit = QTextEdit()
        font = QFont()
        font.setPointSize(14)
        contentEdit.setFont(font)
        contentEdit.setPlainText(self.text)

        grid = QGridLayout()
        grid.setSpacing(10)
        grid.addWidget(contentEdit, 0, 0)

        self.setLayout(grid)
        self.move(200, 200)
        self.setWindowTitle(self.title)
        self.setGeometry(200, 200, 680, 480)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    ex = ShowWindow()
    ex.show()
    sys.exit(app.exec_())