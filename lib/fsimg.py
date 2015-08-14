#!/usr/bin/env python2

_DEPENDENCY_PROGRAMS_ = ("umountlist", "randomgen", "cryptsetup", "mkfs", "blkid")

import sys, os

sys.path.append("/taner/scripts/lib/")
import ipcsh
from ipcsh import ipcsh as sh

from util import check_command, exit_error, raise_error

MOUNT_NO=0

def generate_luks_name():
    global MOUNT_NO
    MOUNT_NO += 1
    return "fsimg_%s_%s" % (os.getpid(), MOUNT_NO)

def create(filepath, size, fstype, pwd=None):
    assert type(size) == str
    if size[-1] in "kKmMgG":
        size_suffix = size[-1]
        size = int(size[:-1])
    else:
        size_suffix = ""
        size = int(size)

    if size_suffix == "":
        pass
    elif size_suffix in "kK":
        size <<= 10
    elif size_suffix in "mM":
        size <<= 20
    elif size_suffix in "gG":
        size <<= 30
    else:
        raise Exception("unknown size suffix. use K, M or G")

    if os.path.exists(filepath):
        sh << "rm -f %(filepath)s" > None
        if sh.r != 0:
            raise Exception("")

    if pwd:
        sh.stdin("") << "randomgen %(size)s > %(filepath)s" > None
        if sh.r != 0:
            raise Exception("")

        sh.stdin(pwd) << "cryptsetup --key-file=- luksFormat %(filepath)s -c aes-xts-plain64 -s 512 -h sha512" > None
        LUKS_NAME = generate_luks_name()
        sh.stdin(pwd) << "cryptsetup --key-file=- luksOpen %(filepath)s %(LUKS_NAME)s" > None
        sh << "mkfs -t %(fstype)s /dev/mapper/%(LUKS_NAME)s" > None
        sh << "cryptsetup luksClose %(LUKS_NAME)s" > None
    else:
        sh << "truncate -s %(size)s %(filepath)s" > None
        if sh.r != 0:
            raise Exception("")

        sh << "mkfs -t %(fstype)s %(filepath)s" > None
        if sh.r != 0:
            raise Exception("")


def mount(img, d, pwd=None, options="-o ro", name=None):

    isLUKS = False
    if img.startswith("/dev/"):
        out = sh << "blkid %(img)s" > str
        if 'TYPE="crypto_LUKS"' in out:
            isLUKS = True
    else:
        out = sh << "file %(img)s" > str
        if "LUKS encrypted file" in out:
            isLUKS = True

    if isLUKS:
        if name == None:
            LUKS_NAME = generate_luks_name()
        else:
            LUKS_NAME = name
        sh.stdin(pwd) << "cryptsetup luksOpen %(img)s %(LUKS_NAME)s" > None
        img = "/dev/mapper/%s" % LUKS_NAME

    sh << "mount %(options)s %(img)s %(d)s" > None
    if sh.r != 0:
        if isLUKS:
            sh << "cryptsetup luksClose %(LUKS_NAME)s" > None
        raise Exception("")



def command_convert(TMP_FOLDER, infile, outfile, outsize, outfstype, PWD):
    # FIXME: other mount options (compress=lzo etc.)
    source = "%s/source" % TMP_FOLDER
    target = "%s/target" % TMP_FOLDER

    sh << "mkdir %(source)s %(target)s" > None
    sh.r == 0 or raise_error()
    mount(infile, source, pwd=PWD)

    if outfile.startswith("/dev/"):
        print "convert to /dev not supported"
        raise_error()
        # print "outfile startswith /dev/"
        # stdout = sh << "blockdev --getsize64 %(outfile)s" > str
        # outsize = "%s" % int(stdout)
        # print "size changed to %s = sizeof(%s)" % (outsize, outfile)
        # outfile_tmp = raw_input('write path for outfile_tmp:')
        # print "tmpfile: %s" % outfile_tmp
    else:
        outfile_tmp="%s.tmp" % outfile

    print "creating outfile"
    create(outfile_tmp, outsize, outfstype, pwd=PWD)
    print "mounting outfile"
    mount(outfile_tmp, target, pwd=PWD, options="-o rw")

    print "copying files to new image"
    sh << "cd %(source)s; cp2 ./ %(target)s" > None
    sh.r == 0 or raise_error()
    print "copy task completed"

    print "umounting source"
    sh << "umountlist %(source)s | sh" > None

    print "umounting tmp disk"
    sh << "umountlist %(target)s | sh" > None
    sh.r == 0 or raise_error()

    if outfile == infile:
        print "same file not supported"
        raise_error()
        # print "temporarily umounting source"
        # source_umount_list = sh << "umountlist %(source)s" > str
        # run("umount %s" % source) or exit(1)

    if outfile.startswith("/dev/") and not outfile.startswith("/dev/shm/"):
        print "convert to /dev not supported"
        raise_error()
        #print "copy to device"
        #run("dd if=%s of=%s oflag=direct bs=64K" % (outfile_tmp, outfile))
        # sh << "rm -f %(outfile_tmp)s" > None
    else:
        sh << "mv %(outfile_tmp)s %(outfile)s" > None

    if outfile == infile:
        print "same file not supported"
        raise_error()
        # print "umounting source"
        # run("%s" % source_umount_list)

    sh << "rmdir %(TMP_FOLDER)s/source" > None
    sh << "rmdir %(TMP_FOLDER)s/target" > None