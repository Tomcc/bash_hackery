#!/bin/bash

OLDPWD=`pwd`
cd handheld/project/VS2015/project_builder
python make_vs_project.py

cd $OLDPWD
tools/generate_unity/update.bat none