#!/bin/sh
pstree -ap | grep -B 100000 "$@"
