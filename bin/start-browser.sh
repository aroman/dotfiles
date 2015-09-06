#!/bin/bash
# copyright 2014 Avi Romanoff. You can use it too.

BROWSER="chromium --force-device-scale-factor=2" 

if ps aux | grep -v grep $BROWSER > /dev/null
then
    exec $BROWSER --new-window > /dev/null
else
    exec $BROWSER > /dev/null
fi
