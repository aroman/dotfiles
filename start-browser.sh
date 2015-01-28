#!/bin/bash

SERVICE="opera"

if ps ax | grep -v grep | grep $SERVICE > /dev/null
then
    exec opera --new-window
else
    exec opera
fi
