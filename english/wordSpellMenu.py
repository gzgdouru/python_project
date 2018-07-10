import sys
from PyQt5.QtWidgets import QMainWindow, QAction, QApplication, QMenu, QTextEdit, QMessageBox
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QFont
from wordSpell import WordSpell, TransMode
from wordSpellWindow import MakeWordExerWindow, MakeWordTestWindow, MakeWordTestWindow, MakeLessExerWindow,\
    AddWordWindow, AddLessonWindow, LessonWindow

class WordSpellMenu(QMainWindow):
    msgSignal = pyqtSignal(str) # timely show
    def __init__(self):
        super().__init__()
        self.wordSpell = WordSpell()
        self.initUI()

    def initUI(self):
        menubar = self.menuBar()

        self.textEd = QTextEdit()
        self.textEd.setReadOnly(True)
        font = QFont()
        font.setPointSize(14)
        self.textEd.setFont(font)
        self.setCentralWidget(self.textEd)

        #word
        wordMenu = menubar.addMenu("word")
        self.initWordUI(wordMenu)

        #lesson
        lessonMenu = menubar.addMenu("lesson")
        self.initLesson(lessonMenu)

        #datas
        datasMenu = menubar.addMenu("datas")
        self.initDatas(datasMenu)

        self.setGeometry(500, 250, 680, 480)
        self.setWindowTitle("New Concept English")
        self.show()

    def initWordUI(self, menu):
        # word exercise of Chinese to English
        wordExerC2EMenu = QMenu("Word Exercise for C to E", self)
        menu.addMenu(wordExerC2EMenu)

        wordExerC2E30Act = QAction("30", self)
        wordExerC2E30Act.triggered.connect(lambda: self.wordExer(30, True))
        wordExerC2EMenu.addAction(wordExerC2E30Act)

        wordExerC2E50Act = QAction("50", self)
        wordExerC2E50Act.triggered.connect(lambda: self.wordExer(50, True))
        wordExerC2EMenu.addAction(wordExerC2E50Act)

        wordExerC2E100Act = QAction("100", self)
        wordExerC2E100Act.triggered.connect(lambda: self.wordExer(100, True))
        wordExerC2EMenu.addAction(wordExerC2E100Act)

        #word exercise of English to Chinese
        wordExerE2CMenu = QMenu("Word Exercise for E to C", self)
        menu.addMenu(wordExerE2CMenu)

        wordExerE2C30Act = QAction("30", self)
        wordExerE2C30Act.triggered.connect(lambda: self.wordExer(30, False))
        wordExerE2CMenu.addAction(wordExerE2C30Act)

        wordExerE2C50Act = QAction("50", self)
        wordExerE2C50Act.triggered.connect(lambda: self.wordExer(50, False))
        wordExerE2CMenu.addAction(wordExerE2C50Act)

        wordExerE2C100Act = QAction("100", self)
        wordExerE2C100Act.triggered.connect(lambda: self.wordExer(100, False))
        wordExerE2CMenu.addAction(wordExerE2C100Act)

        menu.addSeparator()

        #Word Test for Chinese to English
        wordTestC2EMenu = QMenu("Word Test for C to E", self)
        menu.addMenu(wordTestC2EMenu)

        wordTestC2E100Act = QAction("100", self)
        wordTestC2E100Act.triggered.connect(lambda: self.wordTest(100, True, False))
        wordTestC2EMenu.addAction(wordTestC2E100Act)

        wordTestC2E200Act = QAction("200", self)
        wordTestC2E200Act.triggered.connect(lambda: self.wordTest(200, True, False))
        wordTestC2EMenu.addAction(wordTestC2E200Act)

        wordTestC2E500Act = QAction("500", self)
        wordTestC2E500Act.triggered.connect(lambda: self.wordTest(500, True, False))
        wordTestC2EMenu.addAction(wordTestC2E500Act)

        WTLastC2E100Act = QAction("last 100", self)
        WTLastC2E100Act.triggered.connect(lambda: self.wordTest(100, True, True))
        wordTestC2EMenu.addAction(WTLastC2E100Act)

        WTLastC2E200Act = QAction("last 200", self)
        WTLastC2E200Act.triggered.connect(lambda: self.wordTest(200, True, True))
        wordTestC2EMenu.addAction(WTLastC2E200Act)

        WTLastC2E500Act = QAction("last 500", self)
        WTLastC2E500Act.triggered.connect(lambda: self.wordTest(500, True, True))
        wordTestC2EMenu.addAction(WTLastC2E500Act)

        wordTestC2EAllAct = QAction("ALL", self)
        wordTestC2EAllAct.triggered.connect(lambda: self.wordTest(len(self.wordSpell.datas), True, False))
        wordTestC2EMenu.addAction(wordTestC2EAllAct)

        # Word Test for English to Chinese
        wordTestE2CMenu = QMenu("Word Test for E to C", self)
        menu.addMenu(wordTestE2CMenu)

        wordTestE2C100Act = QAction("100", self)
        wordTestE2C100Act.triggered.connect(lambda: self.wordTest(100, False, False))
        wordTestE2CMenu.addAction(wordTestE2C100Act)

        wordTestE2C200Act = QAction("200", self)
        wordTestE2C200Act.triggered.connect(lambda: self.wordTest(200, False, False))
        wordTestE2CMenu.addAction(wordTestE2C200Act)

        wordTestE2C500Act = QAction("500", self)
        wordTestE2C500Act.triggered.connect(lambda: self.wordTest(500, False, False))
        wordTestE2CMenu.addAction(wordTestE2C500Act)

        WTLastE2C100Act = QAction("last 100", self)
        WTLastE2C100Act.triggered.connect(lambda: self.wordTest(100, False, True))
        wordTestE2CMenu.addAction(WTLastE2C100Act)

        WTLastE2C200Act = QAction("last 200", self)
        WTLastE2C200Act.triggered.connect(lambda: self.wordTest(200, False, True))
        wordTestE2CMenu.addAction(WTLastE2C200Act)

        WTLastE2C500Act = QAction("last 500", self)
        WTLastE2C500Act.triggered.connect(lambda: self.wordTest(500, False, True))
        wordTestE2CMenu.addAction(WTLastE2C500Act)

        wordTestE2CAllAct = QAction("ALL", self)
        wordTestE2CAllAct.triggered.connect(lambda: self.wordTest(len(self.wordSpell.datas), False, True))
        wordTestE2CMenu.addAction(wordTestE2CAllAct)

        menu.addSeparator()

        #error recheck for Chinese to English
        errCheckC2EAct = QAction("Error Recheck for C to E", self)
        errCheckC2EAct.triggered.connect(lambda: self.errorRecheck(self.wordSpell.errorWordCFile))
        menu.addAction(errCheckC2EAct)

        #error recheck for English to Chinese
        errCheckE2CAct = QAction("Error Recheck for E to C", self)
        errCheckE2CAct.triggered.connect(lambda: self.errorRecheck(self.wordSpell.errorWordEFile))
        menu.addAction(errCheckE2CAct)

    def initLesson(self, menu):
        #lesson exercise for Chinese to english
        lessExerC2EAct = QAction("Lesson Exercise for C to E", self)
        lessExerC2EAct.triggered.connect(lambda : self.lessExer(TransMode.c2e))
        menu.addAction(lessExerC2EAct)

        #lesson exercise for Englisg to Chinese
        lessExerE2CAct = QAction("Lesson Exercise for E to C", self)
        lessExerE2CAct.triggered.connect(lambda : self.lessExer(TransMode.e2c))
        menu.addAction(lessExerE2CAct)

        menu.addSeparator()

        #random lesson(chinese to english)
        randomLessC2EAct = QAction("Random Lesson for C to E", self)
        randomLessC2EAct.triggered.connect(lambda : self.randomLesson(TransMode.c2e))
        menu.addAction(randomLessC2EAct)

        #random lesson(englisg to chinese)
        randomLessE2CAct = QAction("Random Lesson for E to C", self)
        randomLessE2CAct.triggered.connect(lambda : self.randomLesson(TransMode.e2c))
        menu.addAction(randomLessE2CAct)

    def initDatas(self, menu):
        #add word
        addWordAct = QAction("Add Word", self)
        addWordAct.triggered.connect(self.addWord)
        menu.addAction(addWordAct)

        #add lesson
        addLessonAct = QAction("Add Lesson", self)
        addLessonAct.triggered.connect(self.addLesson)
        menu.addAction(addLessonAct)

        menu.addSeparator()

        #datas backup
        datasBkAct = QAction("Datas Backup", self)
        datasBkAct.triggered.connect(self.datasBackup)
        menu.addAction(datasBkAct)

    def msgDisplay(self, msg):
        if msg == "clear":
            self.textEd.clear()
        else:
            self.textEd.append(msg)

    def wordExer(self, wordCount, C2Eflag):
        if C2Eflag:
            answerList, titleList = self.wordSpell.getRadomDatas(wordCount)
        else:
            titleList, answerList = self.wordSpell.getRadomDatas(wordCount)
        self.wordExerUI = MakeWordExerWindow(titleList, answerList, self.msgSignal)
        self.wordExerUI.show()

    def wordTest(self, wordCount, C2Eflag, reverse):
        if C2Eflag:
            answerList, titleList = self.wordSpell.getLastDatas(top=wordCount) if reverse else self.wordSpell.getRadomDatas(top=wordCount)
            errorFile = self.wordSpell.errorWordCFile
        else:
            titleList, answerList = self.wordSpell.getLastDatas(top=wordCount) if reverse else self.wordSpell.getRadomDatas(top=wordCount)
            errorFile = self.wordSpell.errorWordEFile
        tmpList = list(map(lambda title, answer: [title, answer], titleList, answerList))
        self.wordTestUI = MakeWordTestWindow(tmpList, errorFile)
        self.wordTestUI.show()

    def errorRecheck(self, filePath):
        wordList, errorText = self.wordSpell.getErrorWord(filePath)
        if errorText == "":
            if wordList == []:
                QMessageBox.about(None, "error hint", "no error word")
            else:
                WordSpell.clearErrorWord(filePath)
                self.errorRecheckUI = MakeWordTestWindow(wordList, filePath)
                self.errorRecheckUI.show()
        else:
            QMessageBox.about(None, "error hint", errorText)

    def lessExer(self, mode):
        self.lessExerUI = MakeLessExerWindow(mode, self.msgSignal)
        self.lessExerUI.show()

    def randomLesson(self, mode):
        lesson = self.wordSpell.getRandomLesson()
        if lesson:
            self.lessonUI = LessonWindow(lesson, mode, self.msgSignal)
        else:
            QMessageBox.warning(None, "randomLesson", "lesson is None")

    def addWord(self):
        self.addWordUI = AddWordWindow(self.wordSpell)
        self.addWordUI.show()

    def addLesson(self):
        self.addLessonUI = AddLessonWindow()
        self.addLessonUI.show()

    def datasBackup(self):
        backupDir = self.wordSpell.getBackupDir()
        errorText = self.wordSpell.datasBackup(self.wordSpell.sourceDir, backupDir)
        if errorText == "":
            QMessageBox.about(None, "backup hint", "datas backup success.")
        else:
            QMessageBox.warning(None, "backup hint", errorText)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.close()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = WordSpellMenu()
    ex.msgSignal.connect(ex.msgDisplay)
    sys.exit(app.exec_())
