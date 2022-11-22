@echo off
setlocal

set MSYS2_PATH_TYPE=inherit
set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit

msys2 -here -c zsh