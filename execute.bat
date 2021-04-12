@echo off

rem UTF-8
chcp 65001

pushd %~dp0

rem execute powershell
powershell -NoProfile -ExecutionPolicy Unrestricted ..\exportJsonDataForImport\execute.ps1 %cd%

popd