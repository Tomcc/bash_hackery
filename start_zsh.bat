@echo off
setlocal

set MSYS2_PATH_TYPE=inherit
set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit

%USERPROFILE%/scoop\apps\msys2\current\msys2_shell.cmd -mingw64 -no-start -defterm -c zsh 