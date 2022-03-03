#!/bin/bash
ps -ef|grep "skynet7"|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1


