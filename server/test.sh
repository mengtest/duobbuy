#!/bin/bash
ps -ef|grep "skynet config_test"|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1
sleep 1
./skynet config_test &
