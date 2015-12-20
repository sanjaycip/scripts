#!/usr/bin/python2
import sys, os, subprocess
import inspect

def run(cmd, read_stdout=True, read_stderr=False):
    if read_stdout:
        stdout = subprocess.PIPE
    else:
        stdout = None
    if read_stderr:
        stderr = subprocess.PIPE
    else:
        stderr = None

    p = subprocess.Popen(cmd, shell=True, stdout=stdout, stderr=stderr)
    stdout, stderr = p.communicate()
    return p.returncode, stdout, stderr

def run1(cmd):
    parent_scope = dict(globals(), **inspect.currentframe().f_back.f_locals)
    return run(cmd % parent_scope, read_stdout=False, read_stderr=False)[0]

def run2(cmd):
    parent_scope = dict(globals(), **inspect.currentframe().f_back.f_locals)
    return run(cmd % parent_scope, read_stdout=True, read_stderr=False)[0:2]

def run3(cmd):
    parent_scope = dict(globals(), **inspect.currentframe().f_back.f_locals)
    return run(cmd % parent_scope, read_stdout=True, read_stderr=True)[0:3]

def echo(s):
    parent_scope = dict(globals(), **inspect.currentframe().f_back.f_locals)
    print s % parent_scope

def cmd_mount(path, size):
    path = os.path.abspath(path)
    name = os.path.basename(path)
    hidden_path = os.path.abspath(os.path.join(path, "../.%s" % name))

    _, out1 = run2("umountlist %(path)s")
    _, out2 = run2("umountlist %(hidden_path)s")

    if out1 != "" or out2 != "":
        echo("mount error: %(path)s or %(hidden_path)s mounted")
        exit(1)

    run1("mkdir -p %(path)s %(hidden_path)s") == 0 or exit(1)
    run1("mount -t tmpfs tmpfs %(hidden_path)s -o size=%(size)s") == 0 or exit(1)
    run1("fsimg create %(hidden_path)s/fs.btrfs %(size)s btrfs") == 0 or exit(1)
    run1("fsimg mount %(hidden_path)s/fs.btrfs %(path)s btrfs") == 0 or exit(1)
    exit(0)

def cmd_umount(path):
    path = os.path.abspath(path)
    name = os.path.basename(path)
    hidden_path = os.path.abspath(os.path.join(path, "../.%s" % name))

    _, out1 = run2("umountlist %(path)s")
    _, out2 = run2("umountlist %(hidden_path)s")

    if out1 == "" or out2 == "":
        echo("umount error: %(path)s or %(hidden_path)s not mounted")
        exit(1)

    run1("umountlist %(path)s | sh")
    echo("writing zero")
    _, _, _ = run3("cat /dev/zero > %(hidden_path)s/fs.btrfs")
    run1("umountlist %(hidden_path)s | sh")
    run1("rmdir %(path)s %(hidden_path)s") == 0 or exit(1)

    exit(0)

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == "mount":
        cmd_mount(sys.argv[2], sys.argv[3])
    elif cmd == "umount":
        cmd_umount(sys.argv[2])
