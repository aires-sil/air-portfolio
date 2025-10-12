#!/bin/bash
# Daily SMART short test and logging for Pi5

LOG_DIR="/mnt/nvme/health-logs"
mkdir -p "$LOG_DIR"
DATE=$(date +%F)
LOG_FILE="$LOG_DIR/smart_daily_${DATE}.log"

echo "=== SMART Daily Check: $DATE ===" > "$LOG_FILE"

# Drives to monitor
DEVICES=("/dev/nvme0n1" "/dev/sda")

for DEV in "${DEVICES[@]}"; do
    echo "Checking $DEV ..." >> "$LOG_FILE"

    if smartctl -i "$DEV" 2>&1 | grep -q "SMART support is: Available"; then
        smartctl -H "$DEV" >> "$LOG_FILE" 2>&1
        smartctl -A "$DEV" >> "$LOG_FILE" 2>&1
        smartctl -t short "$DEV" >> "$LOG_FILE" 2>&1
    else
        echo "SMART not supported on $DEV" >> "$LOG_FILE"
    fi
done

echo "Daily SMART check completed." >> "$LOG_FILE"
