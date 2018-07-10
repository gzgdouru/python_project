<<<<<<< HEAD
# encoding:utf-8
import sys
from socket import *
import threading
import time

class ChatroomClient:
    def __init__(self, serverHost, serverPort):
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.sockObj = socket(AF_INET, SOCK_STREAM)
        self.lock = threading.Lock()
        self.threads = []

    def connectServer(self):
        self.sockObj.connect((self.serverHost, self.serverPort))

    def run(self):
        self.connectServer()

    def sendMsg(self):
        while True:
            data = raw_input("> ")

            with self.lock:
                self.sockObj.send(data)
                if str(data).lower() == "quit":
                    break

    def recvMsg(self):
        while True:
            data = self.sockObj.recv(1024)
            if data.lower() == "quit":
                break
            else:
                with self.lock:
                    print data

    def run(self):
        self.connectServer()
        sendThread = threading.Thread(target=ChatroomClient.sendMsg, args=(self,))
        #sendThread.setDaemon(True)
        sendThread.start()
        self.threads.append(sendThread)

        recvThread = threading.Thread(target=ChatroomClient.recvMsg, args=(self,))
        #recvThread.setDaemon(True)
        recvThread.start()
        self.threads.append(recvThread)

        [thread.join() for thread in self.threads]
        self.quit()

    def quit(self):
        self.sockObj.close()
        sys.exit(0)

if __name__ == "__main__":
    serverHost = "192.168.34.203"
    serverPort = 50007

    client = ChatroomClient(serverHost, serverPort)
=======
# encoding:utf-8
import sys
from socket import *
import threading
import time

class ChatroomClient:
    def __init__(self, serverHost, serverPort):
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.sockObj = socket(AF_INET, SOCK_STREAM)
        self.lock = threading.Lock()
        self.threads = []

    def connectServer(self):
        self.sockObj.connect((self.serverHost, self.serverPort))

    def run(self):
        self.connectServer()

    def sendMsg(self):
        while True:
            data = raw_input("> ")

            with self.lock:
                self.sockObj.send(data)
                if str(data).lower() == "quit":
                    sys.exit(0)

    def recvMsg(self):
        while True:
            data = self.sockObj.recv(1024)
            if data.lower() == "quit":
                sys.exit(0)
            else:
                with self.lock:
                    print data

    def run(self):
        self.connectServer()
        sendThread = threading.Thread(target=ChatroomClient.sendMsg, args=(self,))
        #sendThread.setDaemon(True)
        sendThread.start()
        self.threads.append(sendThread)

        recvThread = threading.Thread(target=ChatroomClient.recvMsg, args=(self,))
        #recvThread.setDaemon(True)
        recvThread.start()
        self.threads.append(recvThread)

        [thread.join() for thread in self.threads]
        self.quit()

    def quit(self):
        self.sockObj.close()
        sys.exit(0)

if __name__ == "__main__":
    serverHost = "192.168.232.130"
    serverPort = 50007

    client = ChatroomClient(serverHost, serverPort)
>>>>>>> 31b751da9cab8c64478d0c061b88c453fb75d14a
    client.run()