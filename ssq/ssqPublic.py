def list2str(elemList, splitFlag=" "):
    elemStr = ""
    for elem in elemList:
        elemStr += (str(elem) + splitFlag)
    return elemStr[:-1]

def str2list(text, splitFlag=" "):
    elemList = text.split(splitFlag)
    return elemList

def dict2list(elemDict):
    elemList = []
    for key in elemDict.keys():
        record = []
        record.append(key)
        record.append(elemDict[key])
        elemList.append(record)
    return elemList