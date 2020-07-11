#!/bin/bash

echo "Make sure that your Quest is not sleeping"

echo "Restarting ADB to make sure, wait 10s..."
adb tcpip 5555

sleep 10

QUEST_IP=`adb shell ip route | awk '{print $9}'`

echo "Connecting to Quest at $QUEST_IP"

# connect to your quest
adb connect $QUEST_IP:5555
scrcpy