import random
from datetime import datetime
from collections import Counter, namedtuple
from operator import itemgetter
from selenium import webdriver
import time
from lxml import etree
import sys

LK3Info = namedtuple("LK3Info", ["period", "num_1", "num_2", "num_3"])

from mysqlV1 import MysqlManager
from log_settings import logger
from guessDiceUtils import result_prediction

mysqlConfig = {
    "host": "193.112.150.18",
    "port": 3306,
    "user": "ouru",
    "password": "5201314Ouru...",
    "db": "novel",
    "charset": "utf8",
    "max_overflow": 10,
}
mysqldb = MysqlManager(**mysqlConfig)


def linux_pre_start():
    if sys.platform[:3] != "win":
        from pyvirtualdisplay import Display
        display = Display(visible=0, size=(800, 600))
        display.start()


def get_info():
    url = r"https://1063333.cc/betcenter"
    browser = webdriver.Chrome(executable_path="chromedriver")
    browser.get(url)

    browser.find_element_by_css_selector(".menuItem___1Gogq button[value='KUAI3']").click()
    # print(browser.page_source)
    time.sleep(2)
    browser.find_element_by_css_selector(".menuItem___1Gogq button[value='HF_LFK3']").click()

    htmltree = etree.HTML(browser.page_source, parser=etree.HTMLParser())
    browser.quit()

    period = htmltree.xpath(
        "//div[@class='playground_headerLastOpenResult___cEu68']/p[@class='gameHeader_headerPhase___1z297']/strong/text()")[
        0]

    numsNodes = htmltree.xpath("//div[@class='gameHeader_openNumbers___NzikQ']/span[contains(@class, 'dice___3WFnf')]")
    nums = (int(node.get("data-num")) for node in numsNodes)

    return LK3Info(*(period, *nums))


if __name__ == "__main__":
    linux_pre_start()

    while True:
        try:
            lf3info = get_info()
            conditions = "period = '{0}'".format(lf3info.period)
            if mysqldb.exist("tb_guess_dice", conditions=conditions):
                logger.info(
                    "LK3INFO[{0}:{1} {2} {3}] 已存在.".format(lf3info.period, lf3info.num_1, lf3info.num_2, lf3info.num_3))
            else:
                total = sum([lf3info.num_1, lf3info.num_2, lf3info.num_3])
                history_records = mysqldb.execute("select * from tb_guess_dice order by period desc limit 4")
                mysqldb.insert("tb_guess_dice", period=lf3info.period, num_1=lf3info.num_1, num_2=lf3info.num_2,
                               num_3=lf3info.num_3, total=total, prediction=result_prediction(list(history_records)),
                               add_time=datetime.now())
                logger.info(
                    "保存 LK3INFO[{0}:{1} {2} {3}] 成功.".format(lf3info.period, lf3info.num_1, lf3info.num_2,
                                                             lf3info.num_3))
        except Exception as e:
            logger.error(str(e))
        time.sleep(20)

    # history_records = mysqldb.execute("select * from tb_guess_dice where period BETWEEN '20181026253' and '20181026255' order by period desc limit 4")
    # prediction = result_prediction(list(history_records))
    # print(prediction)
