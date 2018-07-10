import paramiko
import os, sys
from tkinter import *
import threading

class ServerConfig:
    def __init__(self, host, username, passwd, prodir):
        self.host = host
        self.port = 22
        self.username = username
        self.passwd = passwd
        self.prodir = prodir

class AutoUpgrade:
    def __init__(self, srcServer, dstServer, programs=[]):
        self.srcServer = srcServer
        self.dstServer = dstServer
        self.programs = programs
        self.lock = threading.Lock()

        # 初始化源服务器连接
        self.srcTrans = self.connect(srcServer)
        self.srcssh = paramiko.SSHClient()
        self.srcssh._transport = self.srcTrans

        #初始化目标服务器连接
        self.dstTrans = self.connect(dstServer)
        self.dstssh = paramiko.SSHClient()
        self.dstssh._transport = self.dstTrans

    def connect(self, server):
        trans = paramiko.Transport((server.host, server.port))
        trans.connect(username=server.username, password=server.passwd)
        return trans

    def getLocalDir(self):
        if sys.platform[:3] == "win":
            localdir = "d:/"
        else:
            localdir = "/home/" + self.srcServer.username + "/"
        return localdir

    def check(self, from_path, to_path):
        to_dir = os.path.dirname(to_path)

        # 检查目标服务器中目录是否存在
        stdin, stdout, stderr = self.dstssh.exec_command("ls %s" % to_dir)
        if not stdout.read():
            print("%s 服务器中不存在目录: %s" % (self.dstServer.host, to_dir))
            sys.exit()

        # 检查源服务器中文件是否存在
        stdin, stdout, stderr = self.srcssh.exec_command("ls %s" % from_path)
        if not stdout.read():
            print("%s 服务器中不存在文件: %s" % (self.srcServer.host, from_path))
            return False

        # 检查目标服务器中文件是否存在
        stdin, stdout, stderr = self.dstssh.exec_command("ls %s" % to_path)
        if stdout.read():
            print("%s 服务器中已存在文件: %s" % (self.dstServer.host, to_path))
            return False

        return True

    def transPrograms(self):
        srcsftp = paramiko.SFTPClient.from_transport(self.srcTrans)
        dstsftp = paramiko.SFTPClient.from_transport(self.dstTrans)
        localdir = self.getLocalDir()
        threads = []
        for program in self.programs:
            srcpath = self.srcServer.prodir + "/" + program
            localpath = localdir + program
            dstpath = self.dstServer.prodir + "/" + program + "_new"
            if self.check(srcpath, dstpath):
                thread = threading.Thread(target=self.transSinglePro, args=(srcpath, dstpath, localpath))
                thread.start()
                threads.append(thread)
        [thread.join() for thread in threads]

    def transSinglePro(self, srcpath, dstpath, localpath):
        try:
            from_trans = self.connect(self.srcServer)
            from_sftp = paramiko.SFTPClient.from_transport(from_trans)
            to_trans = self.connect(self.dstServer)
            to_sftp = paramiko.SFTPClient.from_transport(to_trans)

            with self.lock: print("trans file:", srcpath)
            from_sftp.get(srcpath, localpath)
            to_sftp.put(localpath, dstpath)
            os.remove(localpath)
            with self.lock: print("trans file:", srcpath, "complete...")
        except Exception as e:
            with self.lock: print("transSinglePro():", str(e))

    def execUpgrade(self):
        try:
            print("start upgrade...")
            upgradePath = self.dstServer.prodir + "/sap_auto_upgrade.sh"
            stdin, stdout, stderr = self.dstssh.exec_command("sh %s" % upgradePath)
            if stdout:
                print("stdout:")
                print(stdout.read())

            if stderr:
                print("stderr:")
                print(stderr.read())
        except Exception as e:
            print("execUpgrade():", str(e))

    def run(self):
        self.transPrograms()
        self.execUpgrade()

class AutoUpgradeGui:
    def __init__(self):
        # 源服务器节点
        self.fServerFields = [
            ["from_host", "172.16.34.16"],
            ["from_username", "anjubao_sap"],
            ["from_passwd", "sap_monitor"],
            ["from_dir", "/usr/local/acloud/bin"],
        ]

        # 目标服务器节点
        self.tServerFields = [
            ["to_host", "192.168.34.203"],
            ["to_username", "anjubao_sap"],
            ["to_passwd", "sap_monitor"],
            ["to_dir", "/usr/local/acloud/bin"]
        ]

        # 公共节点
        self.publicFields = [
            ["program", "control_server"]
        ]

    def run(self):
        entries = {}
        root = Tk()
        self.makeform(root, "from server", self.fServerFields, entries)
        self.makeform(root, "to server", self.tServerFields, entries)
        self.makeform(root, "public", self.publicFields, entries)
        root.bind("<Return>", lambda event: self.deal(entries))
        Button(root, text="submit", command=lambda: self.deal(entries)).pack(side=LEFT)
        Button(root, text="quit", command=sys.exit).pack(side=RIGHT)
        root.mainloop()

    def makeform(self, root, hint, fields, entries):
        lable = Label(root, text=hint)
        lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
        lable.pack(side=TOP)
        for entry in fields:
            keyStr = entry[0]
            valueStr = entry[1]
            row = Frame(root)
            row.pack(side=TOP, fill=X)
            ent = self.makeEntry(row, keyStr, valueStr)
            entries[keyStr] = ent

    def makeEntry(self, root, keyStr, valueStr):
        lab = Label(root, width=15, text=keyStr)
        ent = Entry(root, width=100)
        ent.insert(0, valueStr)
        lab.pack(side=LEFT)
        ent.pack(side=RIGHT, expand=YES, fill=X)
        return ent

    def makeCheckButton(self, root, fields, entries):
        for filed in fields:
            ent = Checkbutton(text=filed).pack()

    def deal(self, entries):
        from_server = ServerConfig(entries["from_host"].get(), entries["from_username"].get(), entries["from_passwd"].get(), entries["from_dir"].get())
        to_server = ServerConfig(entries["to_host"].get(), entries["to_username"].get(), entries["to_passwd"].get(), entries["to_dir"].get())
        program = list(entries["program"].get().split(" "))
        autoUpgrade = AutoUpgrade(from_server, to_server, program)
        autoUpgrade.run()

if __name__ == "__main__":
    upgradeGui = AutoUpgradeGui()
    upgradeGui.run()

