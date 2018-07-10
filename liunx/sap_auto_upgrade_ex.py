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

            with self.lock: print("传输文件:", srcpath)
            from_sftp.get(srcpath, localpath)
            to_sftp.put(localpath, dstpath)
            os.remove(localpath)
            with self.lock: print("传输文件:", srcpath, "complete...")
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

        # 横向布局
        self.row = 0

        # 可执行文件
        self.programs = []

    def addRow(self):
        self.row += 1

    def run(self):
        entries = {}
        root = Tk()
        self.make_from_server(root, self.fServerFields, entries)
        self.make_to_server(root, self.tServerFields, entries)
        self.make_programs(root, entries)
        root.bind("<Return>", lambda event: self.deal(entries))
        Button(root, text="submit", command=lambda: self.deal(entries)).grid(row=self.row, sticky=W)
        Button(root, text="quit", command=sys.exit).grid(row=self.row, column=2, sticky=E)
        root.mainloop()

    def make_from_server(self, root, fields, entries):
        #构造标识
        lable = Label(root, text="from server")
        lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
        lable.grid(row=self.row, sticky=W)
        self.addRow()

        #构造表单
        for entry in fields:
            keyStr = entry[0]
            valueStr = entry[1]
            ent = self.makeEntry(root, keyStr, valueStr)
            entries[keyStr] = ent

    def make_to_server(self, root, fields, entries):
        # 构造标识
        lable = Label(root, text="to server")
        lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
        lable.grid(row=self.row, sticky=W)
        self.addRow()

        # 构造表单
        for entry in fields:
            keyStr = entry[0]
            valueStr = entry[1]
            ent = self.makeEntry(root, keyStr, valueStr)
            entries[keyStr] = ent

    def make_programs(self, root, entries):
        # 构造标识
        lable = Label(root, text="programs")
        lable.config(bg="black", fg="yellow", font=("times", 20, "bold"))
        lable.grid(row=self.row, sticky=W)
        self.addRow()

        # 构造表单
        proFrame = Frame(root).grid(row=self.row)
        Checkbutton(proFrame, text="control_server", command=lambda: self.setPrograms("control_server")).grid(row=self.row, column=0,sticky=W)
        Checkbutton(proFrame, text="ajb_rtsp_client", command=lambda: self.setPrograms("ajb_rtsp_client")).grid(row=self.row, column=1, sticky=W)
        Checkbutton(proFrame, text="Darwin_realtime_service", command=lambda: self.setPrograms("Darwin_realtime_service")).grid(row=self.row, column=2, sticky=W)
        self.addRow()
        Checkbutton(proFrame, text="Darwin_record_service", command=lambda: self.setPrograms("Darwin_record_service")).grid(row=self.row, column=0, sticky=W)
        Checkbutton(proFrame, text="Darwin_worker_mgr",command=lambda: self.setPrograms("Darwin_worker_mgr")).grid(row=self.row, column=1, sticky=W)
        Checkbutton(proFrame, text="image_uploader", command=lambda: self.setPrograms("image_uploader")).grid(row=self.row, column=2, sticky=W)
        self.addRow()
        Checkbutton(proFrame, text="ios_push_worker",command=lambda: self.setPrograms("ios_push_worker")).grid(row=self.row, column=0, sticky=W)
        Checkbutton(proFrame, text="op_server", command=lambda: self.setPrograms("op_server")).grid(row=self.row, column=1, sticky=W)
        Checkbutton(proFrame, text="push_server_mgr", command=lambda: self.setPrograms("push_server_mgr")).grid(row=self.row, column=2, sticky=W)
        self.addRow()
        Checkbutton(proFrame, text="push_worker", command=lambda: self.setPrograms("push_worker")).grid(row=self.row, column=0, sticky=W)
        Checkbutton(proFrame, text="rtp_worker", command=lambda: self.setPrograms("rtp_worker")).grid(row=self.row, column=1, sticky=W)
        Checkbutton(proFrame, text="rtp_worker_mgr", command=lambda: self.setPrograms("rtp_worker_mgr")).grid(row=self.row, column=2, sticky=W)
        self.addRow()
        Checkbutton(proFrame, text="sap_admin", command=lambda: self.setPrograms("sap_admin")).grid(row=self.row, column=0,sticky=W)
        Checkbutton(proFrame, text="upgrade_server", command=lambda: self.setPrograms("upgrade_server")).grid(row=self.row, column=1, sticky=W)
        self.addRow()
        ent = self.makeEntry(root, "other_program", "")
        entries["other_program"] = ent

    def setPrograms(self, program):
        if program in self.programs:
            self.programs.remove(program)
        else:
            self.programs.append(program)

    def makeEntry(self, root, keyStr, valueStr):
        lab = Label(root, width=15, text=keyStr)
        ent = Entry(root)
        ent.insert(0, valueStr)
        lab.grid(row=self.row, sticky=W)
        ent.grid(row=self.row, column=1, sticky=W)
        self.addRow()
        return ent

    def deal(self, entries):
        from_server = ServerConfig(entries["from_host"].get(), entries["from_username"].get(), entries["from_passwd"].get(), entries["from_dir"].get())
        to_server = ServerConfig(entries["to_host"].get(), entries["to_username"].get(), entries["to_passwd"].get(), entries["to_dir"].get())
        programs = self.programs[:]
        other_programs = entries["other_program"].get()
        if other_programs: programs.extend(list(other_programs.split(" ")))
        autoUpgrade = AutoUpgrade(from_server, to_server, programs)
        autoUpgrade.run()

if __name__ == "__main__":
    upgradeGui = AutoUpgradeGui()
    upgradeGui.run()

