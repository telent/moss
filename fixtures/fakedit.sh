#!/usr/bin/env sh
echo -en "fakedit-magic\0"
echo -en "$1\0"
cat $1
