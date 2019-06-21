#!/bin/bash

nuget_hack.bat

./handheld/project/build/packaging/NuGet.exe restore ./handheld/project/VS2015/Minecraft/Minecraft.Client/packages.config -configFile ./handheld/project/VS2015/NuGet.Config -solutiondirectory ./handheld/project/VS2015/