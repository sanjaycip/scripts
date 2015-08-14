from ipcsh import ipcsh as sh
import hashlib, base64

def check_command(*arg):
    for a in arg:
        out = sh << "which %(a)s" > str
        if len(out) == 0:
            return False
    return True

def exit_error(e):
    print e
    exit(1)

def randompass(size):
    return base64.standard_b64encode(open("/dev/random").read(size))

def sha256sum(s):
    m = hashlib.sha256()
    m.update(s)
    return m.hexdigest()

def raise_error(s=""):
    raise Exception(s)
