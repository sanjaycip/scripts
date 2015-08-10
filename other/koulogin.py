#!/usr/bin/env python2
import sys
import requests
from BeautifulSoup import BeautifulSoup

#https://auth.kocaeli.edu.tr:1003/keepalive?050605000110a0b7

def login(no, pwd):
    c = requests.session()

    # get login page
    r1 = c.get('http://8.8.8.8', verify=False)
    soup = BeautifulSoup(r1.text)
    magic = soup.find('input', {'name':'magic'}).get('value')

    values = {
        'magic' : magic,
        'username' : no,
        'password' : pwd,
        '4Tredir' : ""
    }

    # login
    r2 = c.post('https://auth.kocaeli.edu.tr:1003', data=values, verify=False)
    soup = BeautifulSoup(r2.text)
    for x in soup.findAll('a'):
        logout_url = x.get('href')
        session_id = url[url.rfind('?')+1:]
        keep_alive_url = "https://auth.kocaeli.edu.tr:1003/keepalive?%s" % session_id
        print "logout url: ", logout_url
        print "keepalive url: ", keep_alive_url

if __name__ == '__main__':
    login(sys.argv[1], sys.argv[2])
