import std/os

let argc = paramCount();

if argc == 0:
    echo "please provide an input file for the driver"
    quit(1)

let path = paramStr(1)

if not fileExists(path):
    echo "file doesn't exist"
    quit(1)

let content = readFile(path)
echo "successfully read filme"