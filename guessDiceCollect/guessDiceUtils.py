from collections import Counter, namedtuple

DiceInfo = namedtuple("DiceInfo", ["period", "num_1", "num_2", "num_3", "total", "prediction"])


def result_prediction(history_records):
    if not history_records:
        return "未知"

    # 发疯状态, 连续开, 3期及以上
    if is_period_same(history_records[:3], "大"):
        return "大"
    elif is_period_same(history_records[:3], "小"):
        return "小"

    #按大小个数分析
    maxCount, minCount = get_maxmin_count(history_records)
    return "小" if maxCount > minCount else "大"


def get_maxmin_count(history_records):
    num_list = []
    [num_list.extend([dice.num_1, dice.num_2, dice.num_3]) for dice in history_records]
    numsCounter = Counter(num_list)
    nums = numsCounter.most_common()

    minCount = sum(num[1] for num in nums if num[0] <= 3)
    maxCount = sum(num[1] for num in nums if num[0] > 3)

    return maxCount, minCount


def is_period_same(history_records, value="大"):
    for record in history_records:
        if value != get_value_convert(record.total):
            return False
    return True


def get_value_convert(totalCount):
    return "大" if totalCount > 10 else "小"
