from updateNotice import UpdateNotice
import signal, json

novelNotice = UpdateNotice("novelConfig.json")

def deal_41_signal(signum, stack):
    global novelNotice
    novelNotice.show_config()

def deal_42_signal(signum, stack):
    global novelNotice
    novelNotice.reset_config("novelConfig.json")

if __name__ == "__main__":
    # signal.signal(41, deal_41_signal)
    # signal.signal(42, deal_42_signal)

    novelNotice.run()