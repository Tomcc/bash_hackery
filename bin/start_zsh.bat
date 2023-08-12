@echo off
setlocal

set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit

@REM To share "HOME" with windows, set `db_home: windows` in /etc/nsswitch.conf within msys2

%USERPROFILE%/scoop\apps\msys2\current\msys2_shell.cmd -mingw64 -no-start -defterm -c zsh 