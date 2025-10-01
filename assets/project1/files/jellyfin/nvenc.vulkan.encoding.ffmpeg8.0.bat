@echo off
setlocal enabledelayedexpansion

:: === USER CONFIGURABLE VARIABLES ===
set "RAW=C:\Users\Arest\Desktop\MOVIES\RAW"
set "ENCODED=C:\Users\Arest\Desktop\MOVIES\ENCODED"
set "RESOLUTION=1920:1080"
set "CQ=18"
set "NVENC_PRESET=p5"
set "PIX_FMT=nv12"
set "DENISE_STRENGTH=0.3"
set "DEBAND_STRENGTH=3"
set "TONEMAP_FILTER=hable"

:: === PROCESS FILES RECURSIVELY ===
for /r "%RAW%" %%F in (*.mkv) do (
    set "INFILE=%%F"
    set "FNAME=%%~nF"

    set "RELPATH=%%~pF"
    set "RELPATH=!RELPATH:%RAW:~2%=!"
    set "OUTDIR=%ENCODED%!RELPATH!"
    if not exist "!OUTDIR!" mkdir "!OUTDIR!"

    set "OUTFILE=!OUTDIR!!FNAME!_1080p_HEVC.mkv"
    echo Processing "!INFILE!" → "!OUTFILE!"

:: === Audio selection ===
set "AUDIO_INDEX="

:: --- 1️⃣ Check language tag
for /f "tokens=1,2 delims=," %%a in (
    'ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!INFILE!"'
) do (
    set "IDX=%%a"
    set "LANG=%%b"
    if defined LANG (
        echo !LANG! | findstr /i /c:"Original" /c:"English" /c:"Eng" /c:"original" /c:"english" /c:"eng" /c:"[English]" /c:"[Original]" /c:"[Eng]" /c:"[english]" /c:"[original]" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"
    )
)

: : --- 2️⃣ Check track title if language failed
if not defined AUDIO_INDEX (
    for /f "tokens=1,* delims=," %%a in (
        'ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=title -of csv=p=0 "!INFILE!"'
    ) do (
        set "IDX=%%a"
        set "TITLE=%%b"
        if defined TITLE (
            echo !TITLE! | findstr /i /c:"Original" /c:"English" /c:"Eng" /c:"original" /c:"english" /c:"eng" /c:"[English]" /c:"[Original]" /c:"[Eng]" /c:"[english]" /c:"[original]" >nul
            if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"
        )
    )
)

: : --- 3️⃣ Fallback to first track
if not defined AUDIO_INDEX set "AUDIO_INDEX=0"

echo Using audio track index !AUDIO_INDEX!

:: === Detect HDR ===
    set "CP="
    set "TC="
    for /f "tokens=1,2 delims=|" %%h in ('ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries:stream=transfer_characteristics -of default=nw=1:nk=1 "!INFILE!"') do (
        set "CP=%%h"
        set "TC=%%i"
    )
    set "COLOR_INFO=!CP!|!TC!"

    if /i "!COLOR_INFO!"=="bt2020|smpte2084" (
        echo HDR10 PQ → Vulkan tonemap
        set "FILTERS=hwupload=derive_device=vulkan,scale_vulkan=%RESOLUTION%,tonemap_vulkan=tonemap=%TONEMAP_FILTER%:format=nv12,deband_vulkan=strength=%DEBAND_STRENGTH%,denoise_vulkan=percent_spatial=%DENISE_STRENGTH%,hwdownload,format=nv12"
    ) else if /i "!COLOR_INFO!"=="bt2020|arib-std-b67" (
        echo HDR10 HLG → Vulkan tonemap
        set "FILTERS=hwupload=derive_device=vulkan,scale_vulkan=%RESOLUTION%,tonemap_vulkan=tonemap=%TONEMAP_FILTER%:format=nv12,deband_vulkan=strength=%DEBAND_STRENGTH%,denoise_vulkan=percent_spatial=%DENISE_STRENGTH%,hwdownload,format=nv12"
    ) else (
        echo SDR → Vulkan filters only
        set "FILTERS=hwupload=derive_device=vulkan,scale_vulkan=%RESOLUTION%,deband_vulkan=strength=%DEBAND_STRENGTH%,denoise_vulkan=percent_spatial=%DENISE_STRENGTH%,hwdownload,format=nv12"
    )

    :: === Encode ===
    ffmpeg -y -init_hw_device vulkan -filter_hw_device vulkan -i "!INFILE!" ^
        -map 0:v:0 ^
        -vf "!FILTERS!" ^
        -map 0:a:!AUDIO_INDEX! -c:a copy ^
        -c:v hevc_nvenc -preset %NVENC_PRESET% -rc vbr -cq %CQ% -pix_fmt %PIX_FMT% ^
        "!OUTFILE!" || (
            echo Vulkan failed → fallback CPU filters...
            ffmpeg -y -i "!INFILE!" ^
                -map 0:v:0 ^
                -vf "scale=%RESOLUTION%:flags=lanczos,hqdn3d=%DENISE_STRENGTH%,gradfun=%DEBAND_STRENGTH%" ^
                -map 0:a:!AUDIO_INDEX! -c:a copy ^
                -c:v hevc_nvenc -preset %NVENC_PRESET% -rc vbr -cq %CQ% -pix_fmt %PIX_FMT% ^
                "!OUTFILE!"
        )
)

pause