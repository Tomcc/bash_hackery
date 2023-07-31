#!/bin/bash

# dependencies: 
#   brew install scrcpy
#   brew cask install platform-tools-adb

echo "Make sure that your Quest is not sleeping"

echo "Restarting ADB to make sure, wait 10s..."
adb tcpip 5555

sleep 10

QUEST_IP=`adb shell ip route | awk '{print $9}'`

echo "Connecting to Quest at $QUEST_IP"

# connect to your quest
adb connect $QUEST_IP:5555

# trim the view to a single eye
scrcpy -c 1440:1600:0:0 -m 1600 -b 8M