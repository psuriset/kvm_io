#!/usr/bin/env python3

import sys

x = open(sys.argv[1], 'r').read()
x = x.split('\n')
c = 0
arr = []
for i in x:
    if i != '': c+=1
    else: arr.append(c); c = 0

print(sum(arr)/len(arr))
