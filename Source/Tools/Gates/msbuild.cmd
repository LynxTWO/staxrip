@echo off
rem Locate MSBuild the same way on a contributor machine and on a CI runner, so
rem the approved gate commands in .agents/skills/anti-dark-code/calibration/gates.json
rem stay one implementation. Precedence: MSBUILD_PATH if set; the Build Tools path
rem the gates were approved against; otherwise vswhere's latest instance.
setlocal
set "MSB=%MSBUILD_PATH%"
if not defined MSB if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" set "MSB=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if not defined MSB (
  for /f "usebackq delims=" %%I in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSB=%%I"
)
if not defined MSB (
  echo msbuild.cmd: no MSBuild found. Set MSBUILD_PATH or install Visual Studio Build Tools. 1>&2
  exit /b 9009
)
"%MSB%" %*
exit /b %ERRORLEVEL%
