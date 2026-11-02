@echo off
setlocal
set "FLORIST_GODOT=%GODOT_BIN%"
if not defined FLORIST_GODOT set "FLORIST_GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%FLORIST_GODOT%" (
  echo Open project.godot in Godot 4.7.2 and press F5.
  echo Or set GODOT_BIN to the full path of your Godot executable.
  pause
  exit /b 1
)
"%FLORIST_GODOT%" --headless --path "%~dp0." --editor --import --quit
if errorlevel 1 exit /b 1
start "Magic Florist" "%FLORIST_GODOT%" --path "%~dp0."
