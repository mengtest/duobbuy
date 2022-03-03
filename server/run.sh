#!/bin/bash
sh shutdown_server.sh
sleep 1
./skynet7 config_frontend &
sleep 1
./skynet7 config_log &
./skynet7 config_db &
sleep 1
./skynet7 config_agent &
./skynet7 config_catch_fish &
./skynet7 config_social &