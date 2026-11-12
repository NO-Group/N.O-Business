@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
rem Read build_env.txt ONLY if you made one (optional override). Nothing is required.
if exist build_env.txt (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("build_env.txt") do set "%%A=%%B"
)
where flutter >nul 2>nul || (echo Flutter is not on PATH - install Flutter SDK first. & pause & exit /b 1)
rem The android/ platform folder ships committed in this repo, so this only
rem runs if it's ever missing (e.g. a partial download).
if not exist android (
  echo One-time setup: creating the Android platform...
  call flutter create --platforms=android .
)
echo Building the Android APK (release)... this takes a few minutes.
set D=
if defined SUPABASE_URL set D=%D% --dart-define=SUPABASE_URL=!SUPABASE_URL!
if defined SUPABASE_ANON_KEY set D=%D% --dart-define=SUPABASE_ANON_KEY=!SUPABASE_ANON_KEY!
if defined MILS_API_BASE set D=%D% --dart-define=MILS_API_BASE=!MILS_API_BASE!
call flutter build apk --release !D!
if errorlevel 1 (echo. & echo BUILD FAILED - read the red errors above. & pause & exit /b 1)
copy /y "build\app\outputs\flutter-apk\app-release.apk" "MFSL Office.apk" >nul
echo.
echo DONE. Your APK: app\MFSL Office.apk
echo Copy it to the phone and install it.
pause
