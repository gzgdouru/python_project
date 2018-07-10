<<<<<<< HEAD
import SocketServer
import time

class ChatroomServer(SocketServer.BaseRequestHandler):
    client = {}

    def handle(self):
        try:
            self.addClient()
            self.sendWelcome()

            while True:
                data = self.request.recv(1024);
                if not data:
                    break
                if data.lower() == "quit":
                    self.sendQuit(self.client_address)
                    break
                self.sendData(self.client_address, data)
        except Exception as e:
            print "handle():", str(e)
        finally:
            self.request.close()
            self.removeClient()

    def sendWelcome(self):
        str = "[%s]: welcome %s login in chatroom" % (self.now(), self.client_address)
        print str
        for key in self.client.keys():
            clientSock = self.client.get(key)
            clientSock.send(str)

    def now(self):
        return time.ctime()

    def addClient(self):
        if not self.client.get(self.client_address, None):
            self.client[self.client_address] = self.request

    def removeClient(self):
        if self.client.get(self.client_address):
            del self.client[self.client_address]

    def sendQuit(self, clinetAddr):
        for key in self.client.keys():
            clientSock = self.client.get(key)
            if key == clinetAddr:
                str = "quit"
            else:
                str = "[%s]: %s quit chatroom" % (self.now(), key)
            clientSock.send(str)
        del self.client[clinetAddr]

    def sendData(self, clientAddr, data):
        for key in self.client.keys():
            clintSock = self.client.get(key)
            str = "[%s]: %s" % (clientAddr, data)
            clintSock.send(str)

if __name__ == "__main__":
    myHost = ""
    myPort = 50007
    myAddr = (myHost, myPort)
    server = SocketServer.ThreadingTCPServer(myAddr, ChatroomServer)
    print "chatroom server start success....."
=======
import SocketServer
import time

class ChatroomServer(SocketServer.BaseRequestHandler):
    client = {}

    def handle(self):
        self.addClient()
        self.sendWelcome()

        while True:
            data = self.request.recv(1024);
            if data.lower() == "quit":
                self.sendQuit(self.client_address)
                break
            self.sendData(self.client_address, data)
        self.request.close()

    def sendWelcome(self):
        str = "[%s]: welcome %s login in chatroom" % (self.now(), self.client_address)
        for key in self.client.keys():
            clientSock = self.client.get(key)
            clientSock.send(str)

    def now(self):
        return time.ctime()

    def addClient(self):
        if not self.client.get(self.client_address, None):
            self.client[self.client_address] = self.request

    def sendQuit(self, clinetAddr):
        for key in self.client.keys():
            clientSock = self.client.get(key)
            if key == clinetAddr:
                str = "quit"
            else:
                str = "[%s]: %s quit chatroom" % (self.now(), key)
            clientSock.send(str)
        del self.client[clinetAddr]

    def sendData(self, clientAddr, data):
        for key in self.client.keys():
            clintSock = self.client.get(key)
            str = "[%s]: %s" % (clientAddr, data)
            clintSock.send(str)

if __name__ == "__main__":
    myHost = ""
    myPort = 50007
    myAddr = (myHost, myPort)
    server = SocketServer.ThreadingTCPServer(myAddr, ChatroomServer)
    print "chatroom server start success....."
>>>>>>> 31b751da9cab8c64478d0c061b88c453fb75d14a
    server.serve_forever()