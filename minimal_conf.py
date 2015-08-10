#!/usr/bin/env python2

import os
os.system("wget https://raw.githubusercontent.com/tanerguven/python-ipcsh/master/ipcsh.py -O ipcsh.py")
from ipcsh import ipcsh as sh

def exit_error(s):
    print s
    exit(1)

install_list = [
    "bin/fsimg",
    "bin/randomgen",
    "bin/tmpclean.sh",
    "bin/umountlist",
    "bin/ddwatch",
    "bin/cprsync"
]

bashrc = """
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '
if [ -n "$SSH_TTY" ]; then
   PS1="(ssh)$PS1"
fi
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias kvm='kvm -serial mon:stdio'
PATH=$PATH:%(pwd)s/bin
HOME=%(pwd)s/home
HISTFILE=%(pwd)s/home/.bash_history
HISTFILESIZE=10000
history -c
history -r $HISTFILE
""" % {"pwd" : os.getcwd()}


def main():
    for d in ["bin", "pylib", "tmp"]:
        if os.path.exists(d):
            exit_error("[error] directory '%s' exists" % d)

    sh << "wget https://github.com/tanerguven/scripts/archive/master.tar.gz -O scripts.tar.gz" > None
    sh << "mkdir -p tmp" > None
    sh << "tar xf scripts.tar.gz -C tmp" > None

    sh << "mkdir -p bin/ pylib/" > None
    sh << "mv ipcsh.py* pylib/" > None

    for x in install_list:
        print "installing: %s" % x
        sh << "mv tmp/*/%(x)s bin/" > None

    sh << "mkdir -p home/" > None
    open("home/.bashrc", "w").write(bashrc)

    sh << "rm -rf tmp scripts.tar.gz" > None

if __name__ == '__main__':
    main()
