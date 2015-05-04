#!/bin/sh
# IEC958 Muter!
amixer -D hw:0 set 'IEC958',1 mute > /dev/null &
amixer -D hw:0 set 'IEC958',2 mute > /dev/null &
amixer -D hw:0 set 'IEC958',16 mute > /dev/null &
