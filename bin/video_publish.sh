#!/bin/bash

# recompress the video to a smaller resolution and compress it better than whatever shitty program made it
ffmpeg -y -i "$1" -vf scale=800:-2 compressed.mp4