#!/usr/bin/evn pyhon2
import sys

if __name__ == '__main__':
    conf_file = sys.argv[1]
    ca_cert, client_cert, client_key = None, None, None

    out=""

    for line in open(conf_file).readlines():
        if line.startswith("ca "):
            ca_cert = line[len("ca "):-1]
        elif line.startswith("cert "):
            client_cert = line[len("cert "):-1]
        elif line.startswith("key "):
            client_key = line[len("key "):-1]
        else:
            out += line


    if None in (ca_cert, client_key, client_key):
        print "ca, cert or key file not found"
        exit(1)

    out += "<ca>\n%s</ca>\n" % open(ca_cert).read()
    out += "<cert>\n%s</cert>\n" % open(client_cert).read()
    out += "<key>\n%s</key>\n" % open(client_key).read()

    print out
