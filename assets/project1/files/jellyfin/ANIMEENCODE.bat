@echo off
setlocal enabledelayedexpansion

:: === USER CONFIGURABLE VARIABLES ===
set "RAW=C:\Users\Arest\Desktop\MOVIES\RAW"          :: Input folder
set "ENCODED=C:\Users\Arest\Desktop\MOVIES\ENCODED"  :: Output folder
set "RESOLUTION=1920:1080"                            :: Resolution scale
set "CQ=18"                                           :: NVENC quality: lower=better quality/larger file
set "NVENC_PRESET=slow"                               :: NVENC preset (slow, hq, medium)
set "PIX_FMT=yuv420p10le"                             :: Pixel format (p010le for HDR10, yuv420p10le for SDR)
set "DENISE_STRENGTH=1:1:4:4"                         :: HQDN3D denoise: luma/cb/cr temporal/spatial
set "DEBAND_STRENGTH=3"                               :: Gradfun debanding
set "TONEMAP_FILTER=hable"                            :: HDR->SDR tonemap filter

:: === PROCESS FILES RECURSIVELY ===
for /r "%RAW%" %%f in (*.mkv) do (
    set "FNAME=%%~nf"
    set "INFILE=%%f"

    :: === Mirror subfolder structure in ENCODED folder ===
    set "RELPATH=%%~pf"
    set "RELPATH=!RELPATH:%RAW%\=!"
    set "OUTDIR=%ENCODED%\!RELPATH!"
    if not exist "!OUTDIR!" mkdir "!OUTDIR!"

    set "OUTFILE=!OUTDIR!!FNAME!_1080p_HEVC.mkv"

    echo Processing "!INFILE!" → "!OUTFILE!"

    :: === Auto-select first English audio track ===
    set "AUDIO_INDEX="
    for /f "tokens=1,2 delims=," %%a in ('ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!INFILE!"') do (
        set "IDX=%%a"
        set "LANG=%%b"

        echo !LANG! | findstr /i "^eng$" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"

        echo !LANG! | findstr /i "^Eng$" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"

        echo !LANG! | findstr /i "^English$" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"

        echo !LANG! | findstr /i "^Original$" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"

        echo !LANG! | findstr /i "^english$" >nul
        if !errorlevel! EQU 0 if not defined AUDIO_INDEX set "AUDIO_INDEX=!IDX!"
    )

    :: fallback to first track if nothing matched
    if not defined AUDIO_INDEX set "AUDIO_INDEX=0"
    echo Using audio track index !AUDIO_INDEX!

    :: === Detect HDR10 (PQ / HLG) vs SDR ===
    set "COLOR_INFO="
    for /f "tokens=1,2 delims=|" %%h in ('ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries:stream=transfer_characteristics -of default=nw=1:nk=1 "!INFILE!"') do (
        set "COLOR_INFO=%%h|%%i"
    )

    if /i "!COLOR_INFO!"=="bt2020|smpte2084" (
        echo Detected HDR10 PQ → applying tonemap
        set "FILTERS=format=p010le,tonemap=%TONEMAP_FILTER%,scale=%RESOLUTION%:flags=lanczos,hqdn3d=%DENISE_STRENGTH%,gradfun=%DEBAND_STRENGTH%,fps=24000/1001"
    ) else if /i "!COLOR_INFO!"=="bt2020|arib-std-b67" (
        echo Detected HDR10 HLG → applying tonemap
        set "FILTERS=format=p010le,tonemap=%TONEMAP_FILTER%,scale=%RESOLUTION%:flags=lanczos,hqdn3d=%DENISE_STRENGTH%,gradfun=%DEBAND_STRENGTH%,fps=24000/1001"
    ) else (
        echo Detected SDR → skipping tonemap
        set "FILTERS=scale=%RESOLUTION%:flags=lanczos,hqdn3d=%DENISE_STRENGTH%,gradfun=%DEBAND_STRENGTH%,fps=24000/1001"
    )

    :: === Run FFmpeg encode ===
    ffmpeg -y -i "!INFILE!" ^
        -map 0:v:0 ^
        -vf "!FILTERS!" ^
        -map 0:a:!AUDIO_INDEX! -c:a copy ^
        -c:v hevc_nvenc -preset %NVENC_PRESET% -rc vbr -tune hq -multipass 2 -cq %CQ% -pix_fmt %PIX_FMT% ^
        "!OUTFILE!"
)

pause
