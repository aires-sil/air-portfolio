@echo off
setlocal enabledelayedexpansion

:: Directory containing MKVs
set "INPUT_DIR=C:\Users\Arest\Desktop\MOVIES\RAW"

:: Loop through all MKV files
for %%f in ("%INPUT_DIR%\*.mkv") do (
    echo =======================================
    echo File: %%~nxf
    ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language:stream_tags=title -of csv=p=0 "%%f"
)
pause