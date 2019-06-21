@ECHO OFF

MKDIR "..\nuget_packages"

RMDIR /S /Q "handheld\project\VS2015\packages" 

MKLINK /J "handheld\project\VS2015\packages" "..\nuget_packages"