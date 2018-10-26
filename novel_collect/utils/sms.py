import requests
import json

def send_sms(mobile, novelName):
    url = r'https://api.mysubmail.com/message/xsend'
    params = {
      "novel" : novelName,
    }

    data = {
        "appid": "27038",
        "to": mobile,
        "project": "tz4Nm1",
        "vars": json.dumps(params),
        "signature": "c7ed55eb026edf67c87183a28948872a",
    }

    response = requests.post(url, data=data)
    res = json.loads(response.text)
    if res.get("status") == "error":
        raise RuntimeError("send sms error:{0}".format(res.get("msg")))

if __name__ == "__main__":
    pass