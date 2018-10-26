from collections import Counter, namedtuple

DiceInfo = namedtuple("DiceInfo", ["period", "num_1", "num_2", "num_3", "total", "prediction"])


def nums_prediction(history, nums):
    num_list = list(nums)
    prediction_nums = []
    # 保存连续三期没出现的号码
    [prediction_nums.append(num) for num in num_list if
     num not in history[0] and num not in history[1] and num not in history[2]]

    # 保存没有连续出现了两期的号码
    [prediction_nums.append(num) for num in num_list if
     (num not in history[0] or num not in history[1]) and num not in prediction_nums]

    # 保证返回至少3个号码
    while len(prediction_nums) < 4:
        prediction_nums.append(num_list[0])
    return "".join(map(str, prediction_nums[:3]))


def result_prediction(history_records):
    # 发疯状态, 连续开
    if is_period_same(history_records, "大"):
        return "大"
    elif is_period_same(history_records, "小"):
        return "小"

    # 先分析最近两期记录
    maxCount, minCount = get_maxmin_count(history_records[:2])
    if maxCount != minCount:
        return "小" if maxCount > minCount else "大"

    # 后分析最近三期记录
    maxCount, minCount = get_maxmin_count(history_records[:3])
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
