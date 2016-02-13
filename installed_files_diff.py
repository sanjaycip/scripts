import os, sys

if len(sys.argv) < 2:
    print "usage: %s GIT_DIR" % sys.argv[0]
    exit(1)

GIT_DIR=os.path.abspath(sys.argv[1])

FILE_LIST={}

for f in (
        "cp2", "cprsync", "ddwatch", "em", "firefox", "fsimg", "randomgen", "randompass",
        "run_with_aufs_ram_cache", "run_with_ram_cache", "tmpclean.sh", "tmpfs_compressed.py",
        "tmpmnt_archivemount", "umountlist", "xclips"):
    FILE_LIST["/usr/local/bin/%s" % f] = "scripts/bin/%s" % f


for f in ("kvm_shared_fs.sh", "kvm_aufs_root.sh", "kvm_fsimg.sh"):
    FILE_LIST["/usr/local/bin/%s" % f] = "scripts/virtualization/%s" % f

FILE_LIST["/usr/local/bin/run_docker.sh"] = "containers/docker/scripts/run_docker.sh"

FILE_LIST["/usr/local/lib/taner/fsimg.py"] = "scripts/lib/fsimg.py"
FILE_LIST["/usr/local/lib/taner/util.py"] = "scripts/lib/util.py"
FILE_LIST["/usr/local/lib/taner/ipcsh.py"] = "python-ipcsh/ipcsh.py"


if __name__ == '__main__':
    for k,v in FILE_LIST.iteritems():
        v = "%s/%s" % (GIT_DIR, v)
        if not os.path.isfile(k):
            print "[NOT_INSTALLED] %s -> %s" % (k, v)
        elif not os.path.isfile(v):
            print "[NOT_FOUND] %s -> %s" % (k, v)
        elif open(k).read() != open(v).read():
            print "[DIFFERENT] %s -> %s" % (k, v)

