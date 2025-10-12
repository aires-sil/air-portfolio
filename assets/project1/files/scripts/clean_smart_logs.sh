#!/bin/bash
# Clean SMART logs older than 30 days
LOG_DIR="/mnt/nvme/health-logs"
find "$LOG_DIR" -type f -name "smart_*.log" -mtime +30 -exec rm -f {} \;
