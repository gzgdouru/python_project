from PyQt5.QtWidgets import QMainWindow, QAction, QApplication
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QLabel, QWidget, QLineEdit, QGridLayout
from PyQt5.QtWidgets import QPushButton, QMessageBox, QTextEdit, QComboBox
from PyQt5.QtCore import Qt
import sys
from ssqPrediction import SSQ
from  ssqPublic import list2str

class SSQUI(QWidget):
    def __init__(self):
        super().__init__()
        self.ssq = SSQ()
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        syncBt = QPushButton("同步记录")
        syncBt.clicked.connect(self.syncRecord)
        grid.addWidget(syncBt, 0, 0)

        makeRandomBt = QPushButton("随机生成")
        makeRandomBt.clicked.connect(self.makeRandom)
        grid.addWidget(makeRandomBt, 0, 1)

        makeMaxNumBt = QPushButton("生成最大概率号码")
        makeMaxNumBt.clicked.connect(self.makeMaxNum)
        grid.addWidget(makeMaxNumBt, 1, 0)

        makeViewBt = QPushButton("生成最大概率图")
        makeViewBt.clicked.connect(self.makeView)
        grid.addWidget(makeViewBt, 1, 1)

        makeBestNumBt = QPushButton("生成最优概率号码")
        makeBestNumBt.clicked.connect(self.makeBestNum)
        grid.addWidget(makeBestNumBt, 2, 0)

        makeBestViewBt = QPushButton("生成最优概率图")
        makeBestViewBt.clicked.connect(self.makeBestView)
        grid.addWidget(makeBestViewBt, 2, 1)

        makeHistoryBt = QPushButton("往期回顾")
        makeHistoryBt.clicked.connect(self.makeHistory)
        grid.addWidget(makeHistoryBt, 3, 0)

        hisAnalysisBt = QPushButton("往期分析")
        hisAnalysisBt.clicked.connect(self.historyAnalysis)
        grid.addWidget(hisAnalysisBt, 3, 1)

        makeALikeBt = QPushButton("生成相似概率号码")
        makeALikeBt.clicked.connect(self.makeALike)
        grid.addWidget(makeALikeBt, 4, 0)

        hisPredictionBt = QPushButton("往期预测")
        hisPredictionBt.clicked.connect(self.historyPrediction)
        grid.addWidget(hisPredictionBt, 4, 1)

        self.setLayout(grid)
        #self.setGeometry(100, 100, 50, 50)
        self.setWindowTitle('ssq')
        self.show()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

    def syncRecord(self):
        text = self.ssq.syncsRecord()
        QMessageBox.about(None, "同步记录", text)

    def makeRandom(self):
        record = self.ssq.getRandomNum()
        text = list2str(record)
        self.makeRandomUI = ShowWindow(text, "随机号码")
        self.makeRandomUI.show()

    def makeMaxNum(self):
        balls = self.ssq.makeBySingle()
        text = list2str(balls)
        self.makeMaxNumUI = ShowWindow(text, "最大概率号码")
        self.makeMaxNumUI.show()

    def makeView(self):
        text = self.ssq.makeView()
        self.makeViewUI = ShowWindow(text, "最大概率图")
        self.makeViewUI.show()

    def makeBestNum(self):
        balls = self.ssq.makeBestNum()
        text = list2str(balls)
        self.makeBestNumUI = ShowWindow(text, "最优概率号码")
        self.makeBestNumUI.show()

    def makeBestView(self):
        text = self.ssq.makeBestView()
        self.makeBestViewUI = ShowWindow(text, "最优概率图")
        self.makeBestViewUI.show()

    def makeHistory(self):
        text = self.ssq.getHistoryResult()
        self.makeHistoryUI = ShowWindow(text, "往期结果")
        self.makeHistoryUI.show()

    def historyAnalysis(self):
        self.hisAnalysisUI = HistoryAnalysisUI(self.ssq, "往期分析")
        self.hisAnalysisUI.show()

    def makeALike(self):
        balls, text = self.ssq.getALikeNum()
        if text is None:
            text = list2str(balls)
        self.makeALikeUI = ShowWindow(text, "相似概率号码")
        self.makeALikeUI.show()

    def historyPrediction(self):
        self.historyPredictionUI = HistoryPredictionUI(self.ssq, "往期预测")
        self.historyPredictionUI.show()

class ShowWindow(QWidget):
    def __init__(self, text="", title=""):
        super().__init__()
        self.text = text
        self.title = title
        self.initUI()

    def initUI(self):
        contentEdit = QTextEdit()
        contentEdit.setPlainText(self.text)

        grid = QGridLayout()
        grid.setSpacing(10)
        grid.addWidget(contentEdit, 0, 0)

        self.setLayout(grid)
        self.move(200, 200)
        self.setWindowTitle(self.title)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

class HistoryAnalysisUI(QWidget):
    def __init__(self, ssq, title):
        super().__init__()
        self.ssq = ssq
        self.title = title
        self.initUI()

    def initUI(self):
        self.periodCb = QComboBox()
        self.makeItem()

        self.analysisBt = QPushButton("分析")
        self.analysisBt.clicked.connect(self.analysis)

        grid = QGridLayout()
        grid.setSpacing(10)
        grid.addWidget(self.periodCb, 0, 0)
        grid.addWidget(self.analysisBt, 0, 1)

        self.setLayout(grid)
        self.move(200, 400)
        self.setWindowTitle(self.title)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

    def analysis(self):
        period = int(self.periodCb.currentText())
        text = self.ssq.historyAnalysis(period)
        self.showUI = ShowWindow(text, "往期分析")
        self.showUI.show()

    def getItem(self):
        itemList = []
        for key in self.ssq.record.keys():
            itemList.append(str(key))
            if len(itemList) == 50: break
        return itemList

    def makeItem(self):
        index = 0
        itemList = self.getItem()
        for item in itemList:
            self.periodCb.insertItem(index, item)
            index += 1

class HistoryPredictionUI(QWidget):
    def __init__(self, ssq, title):
        super().__init__()
        self.ssq = ssq
        self.title = title
        self.initUI()

    def initUI(self):
        grid = QGridLayout()
        grid.setSpacing(10)

        self.periodCb = QComboBox()
        self.makeItem()
        grid.addWidget(self.periodCb, 0, 1)

        maxBt = QPushButton("最大概率预测")
        maxBt.clicked.connect(self.maxPrediction)
        grid.addWidget(maxBt, 1, 0)

        bestBt = QPushButton("最佳概率预测")
        bestBt.clicked.connect(self.bestPrediction)
        grid.addWidget(bestBt, 1, 1)

        alikeBt = QPushButton("相似概率预测")
        alikeBt.clicked.connect(self.alikePrediction)
        grid.addWidget(alikeBt, 1, 2)

        self.setLayout(grid)
        self.move(200, 400)
        self.setWindowTitle(self.title)

    def getItem(self):
        itemList = []
        for key in self.ssq.record.keys():
            itemList.append(str(key))
            if len(itemList) == 50: break
        return itemList

    def makeItem(self):
        index = 0
        itemList = self.getItem()
        for item in itemList:
            self.periodCb.insertItem(index, item)
            index += 1

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

    def maxPrediction(self):
        period = int(self.periodCb.currentText()) - 1
        balls = self.ssq.getMaxNumForPeriod(period)
        text = list2str(balls)
        self.MaxShowUI = ShowWindow(text, "最大概率预测")
        self.MaxShowUI.show()

    def bestPrediction(self):
        period = int(self.periodCb.currentText()) - 1
        balls = self.ssq.getBestNumForPeriod(period)
        text = list2str(balls)
        self.BestShowUI = ShowWindow(text, "最佳概率预测")
        self.BestShowUI.show()

    def alikePrediction(self):
        period = int(self.periodCb.currentText()) - 1
        balls, text = self.ssq.getALikeNumForPeriod(period)
        if text is None: text = list2str(balls)
        self.aLikeShowUI = ShowWindow(text, "相似概率预测")
        self.aLikeShowUI.show()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    ex = SSQUI()
    sys.exit(app.exec_())