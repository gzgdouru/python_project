import logging

logger = logging.getLogger("novel")
logger.setLevel(logging.DEBUG)

sHandle = logging.StreamHandler()
sHandle.setLevel(logging.DEBUG)

fHandle = logging.FileHandler("guess_dice_collect.log")
fHandle.setLevel(logging.DEBUG)

formatter = logging.Formatter("[%(asctime)s] [%(name)s] [%(levelname)s] : %(message)s")
sHandle.setFormatter(formatter)
fHandle.setFormatter(formatter)

logger.addHandler(sHandle)
logger.addHandler(fHandle)