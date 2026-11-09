@echo off
setlocal
cd /d "%~dp0"
where matlab >nul 2>&1
if errorlevel 1 (
  echo MATLAB was not found on PATH. Open MATLAB, browse to this directory and run:
  echo Start_UnitOps_Lab
  pause
  exit /b 1
)
start "UnitOps MATLAB Instructor" matlab -nosplash -r "cd('%~dp0'); Start_UnitOps_Lab;"
exit /b 0
