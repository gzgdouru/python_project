import paramiko

class RemoteOpt:
    def __init__(self, host, port, username, passwd):
        self.host = host
        self.port = port
        self.username = username
        self.passwd = passwd

    def init_server_connect(self):
        trans = paramiko.Transport((self.host, self.port))
        trans.connect(username=self.username, password=self.passwd)
        self.trans = trans
        self.ssh = paramiko.SSHClient()
        self.ssh._transport = self.trans

    def checkDir(self, path):
        errorText = ""
        stdin, stdout, stderr = self.ssh.exec_command("ls %s" % path)
        if not stdout.read():
            errorText = ("%s 服务器中不存在目录: %s" % (self.host, path))
        return errorText

    def exec_command(self, command):
        stdin, stdout, stderr = self.ssh.exec_command(command)
        outText = stdout.read()
        errorText = stderr.read()
        return outText, errorText

    def get_file_content(self, path):
        command = "cat %s" % path
        return self.exec_command(command)

if __name__ == "__main__":
    opt = RemoteOpt("192.168.34.203", 22, "postgres", "postgres")
    opt.init_server_connect()
    stdout, stderror = opt.get_file_content("/usr/local/pgsql/.pgpass")
    print(stdout)
