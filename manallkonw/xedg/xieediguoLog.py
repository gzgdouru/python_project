import logging
import os

logger = logging.getLogger("xieediguo")
logger.setLevel(logging.DEBUG)

# 日志格式
formatter = logging.Formatter("[%(asctime)s] [%(name)s] [%(levelname)s] : %(message)s")

# 后台输出日志
sHandle = logging.StreamHandler()
sHandle.setLevel(logging.DEBUG)
sHandle.setFormatter(formatter)
logger.addHandler(sHandle)

# 文件日志输出
logfileName = "xieediguo.log"
if not os.path.exists(logfileName): open(logfileName, "w")
fHandle = logging.FileHandler(logfileName)
fHandle.setLevel(logging.DEBUG)
fHandle.setFormatter(formatter)
logger.addHandler(fHandle)