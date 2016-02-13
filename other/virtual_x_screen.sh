#!/bin/sh

[ "$1" != "" ] || exit 1
[ "$2" != "" ] || exit 1
[ "$3" != "" ] || exit 1

NEW_DISPLAY=$1
PORT=$2
RESOLUTION=$3

ORIG_DISPLAY=$DISPLAY

Xvfb $NEW_DISPLAY -nolisten tcp -screen 0 ${RESOLUTION}x16 -ac &

sleep 0.1
x11vnc -rfbport $PORT -display $NEW_DISPLAY -localhost -forever -wait 33 -wait_ui 1.0 -ncache_cr &

sleep 0.1
DISPLAY=$NEW_DISPLAY openbox &

sleep 2
# ssvncviewer localhost:$PORT -compresslevel 0 -quality 9 &
DISPLAY=$ORIG_DISPLAY vncviewer localhost:$PORT -FullColor -ZlibLevel=0

wait `pidof runall`
