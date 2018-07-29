import logging

logger = logging.getLogger("xieediguo")
logger.setLevel(logging.DEBUG)

sHandle = logging.StreamHandler()
sHandle.setLevel(logging.DEBUG)

formatter = logging.Formatter("[%(asctime)s] [%(name)s] [%(levelname)s] : %(message)s")
sHandle.setFormatter(formatter)

logger.addHandler(sHandle)