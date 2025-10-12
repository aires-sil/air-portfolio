@echo off
set "INFILE=C:\Users\Arest\Desktop\MOVIES\RAW\The.Nun.2018.m2ts"
set "OUTFILE=C:\Users\Arest\Desktop\MOVIES\ENCODED\The.Nun.2018.mkv"

:: English audio in your BDMV is stream #4 (check ffprobe to confirm)
ffmpeg -i "%INFILE%" -map 0:v:0 -map 0:a:4 -c copy "%OUTFILE%"

echo Done. Output: "%OUTFILE%"
pause
