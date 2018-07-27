from collect import Collect
import signal, json

collecter = Collect("config.json")

def deal_41_signal(signum, stack):
    global collecter
    collecter.show_config()

def deal_42_signal(signum, stack):
    global collecter
    collecter.reset_config("config.json")

if __name__ == "__main__":
    signal.signal(41, deal_41_signal)
    signal.signal(42, deal_42_signal)

    collecter.run()