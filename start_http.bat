@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Keep this launcher ASCII-only so cmd.exe can parse it reliably.
rem The Python server itself prints the detailed Chinese startup banner.
chcp 65001 >nul
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "PY_CMD="
where py >nul 2>nul && set "PY_CMD=py -3"
if not defined PY_CMD (
  where python >nul 2>nul && set "PY_CMD=python"
)
if not defined PY_CMD (
  where python3 >nul 2>nul && set "PY_CMD=python3"
)

if not defined PY_CMD (
  call :say "6ZSZ6K+v77ya5pyq5om+5YiwIFB5dGhvbiAz77yM6K+35YWI5a6J6KOFIFB5dGhvbiAz44CC"
  if not defined START_HTTP_NO_PAUSE pause
  exit /b 1
)

call :say "5q2j5Zyo5ZCv5YqoIEhUVFAg5paH5Lu25pyN5YqhLi4u"
call :say_env "55uu5b2V77ya" SCRIPT_DIR
call :say "6buY6K6k56uv5Y+j77yaNzg3OA=="
call :say "6K+05piO77ya5aaC5p6c56uv5Y+j6KKr5Y2g55So77yM56iL5bqP5Lya6Ieq5Yqo5YiH5o2i5Yiw5LiL5LiA5Liq5Y+v55So56uv5Y+j44CC"
call :say "5o+Q56S677ya5oyJIEN0cmwrQyDlj6/ku6XlgZzmraLmnI3liqHjgII="
echo.

call %PY_CMD% "%SCRIPT_DIR%http_server.py" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  call :say_env "5pyN5Yqh5ZCv5Yqo5aSx6LSl77yM6ZSZ6K+v56CB77ya" EXIT_CODE
  if not defined START_HTTP_NO_PAUSE pause
)

exit /b %EXIT_CODE%

:say
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%~1')); [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::WriteLine($s)"
exit /b 0

:say_env
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%~1')); [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::WriteLine($p + [Environment]::GetEnvironmentVariable('%~2'))"
exit /b 0
