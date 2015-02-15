#!/bin/sh
find . \( -name "*~" -or -name "\#*#" \) -exec rm -f {} \;

