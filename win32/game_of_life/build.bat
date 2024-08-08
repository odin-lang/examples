@echo off
set odin_cmd=build
set odin_opt=-resource:game_of_life.rc
if "%1" NEQ "" set odin_cmd=%1
if "%2" NEQ "" set odin_opt=%odin_opt% %2
rem select code page with utf-8 support CP_UTF8
chcp 65001
rem setup VC needed for -resource
if "%VSCMD_ARG_TGT_ARCH%"=="" call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
pushd %~dp0
@echo on
odin %odin_cmd% . %odin_opt%
@echo off
popd
