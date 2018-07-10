import requests
from bs4 import BeautifulSoup

if __name__ == "__main__":
    soup = BeautifulSoup(open("ssq_data.html"), "html.parser")

    subNode = None
    for child in soup.body.children:
        flag = child.find("div")
        if flag != -1:
            try:
                print(child)
                print("_"*100)
            except Exception as e:
                pass