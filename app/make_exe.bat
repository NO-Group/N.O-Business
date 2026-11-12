@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
rem Read build_env.txt ONLY if you made one (optional override). Nothing is required.
if exist build_env.txt (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("build_env.txt") do set "%%A=%%B"
)
where flutter >nul 2>nul || (echo Flutter is not on PATH - install Flutter SDK first. & pause & exit /b 1)
rem The windows/ platform folder ships committed in this repo, so this only
rem runs if it's ever missing (e.g. a partial download).
if not exist windows (
  echo One-time setup: creating the Windows platform...
  call flutter create --platforms=windows .
)
echo Building the Windows EXE (release)... this takes a few minutes.
set D=
if defined SUPABASE_URL set D=%D% --dart-define=SUPABASE_URL=!SUPABASE_URL!
if defined SUPABASE_ANON_KEY set D=%D% --dart-define=SUPABASE_ANON_KEY=!SUPABASE_ANON_KEY!
if defined MILS_API_BASE set D=%D% --dart-define=MILS_API_BASE=!MILS_API_BASE!
call flutter build windows --release !D!
if errorlevel 1 (echo. & echo BUILD FAILED - read the red errors above. & pause & exit /b 1)
set OUT=build\windows\x64\runner\Release
copy /y "%OUT%\mtek_inventory.exe" "%OUT%\MFSL Office.exe" >nul
powershell -NoProfile -Command "Compress-Archive -Path '%OUT%\*' -DestinationPath 'MFSL Office.zip' -Force"

echo.
echo Building the Windows Installer (MSIX)... this makes a real Setup wizard
echo showing Publisher: N.O Group. The first time, Windows may ask you to
echo confirm installing a self-signed developer certificate - click Yes.
call flutter pub get
call dart run msix:create
if errorlevel 1 (
  echo.
  echo MSIX packaging failed, but the plain EXE build above still succeeded.
  echo You can still run the app from: app\%OUT%\MFSL Office.exe
  pause
  exit /b 0
)
copy /y "%OUT%\MFSL-Office-Setup.msix" "%OUT%\MFSL Office Setup.msix" >nul

echo.
echo DONE.
echo Installer (recommended, double-click to install): app\%OUT%\MFSL Office Setup.msix
echo   Shows Publisher: N.O Group in the install wizard.
echo Portable EXE (needs the whole folder next to it, not standalone):
echo   app\%OUT%\MFSL Office.exe   (folder: app\%OUT%\)
echo Zipped copy of that folder: app\MFSL Office.zip
pause
