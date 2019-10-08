#!/bin/bash

echo "tommo_`date '+%y%m%d'``cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 2 | head -n 1`"