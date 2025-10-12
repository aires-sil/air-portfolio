#!/bin/bash
# Cleanup logs older than 7 days in specified directories

# Directories to clean
LOG_DIRS=(
    "/mnt/nvme/log/system"
    "/mnt/nvme/log/samba"
    "/mnt/nvme/share/health-logs"
    "/mnt/nvme/log"
)

# Clear files older than 7 days
for dir in "${LOG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        find "$dir" -type f -mtime +7 -exec truncate -s 0 {} \;
    fi
done

# Docker container logs older than 7 days
DOCKER_LOGS="/var/lib/docker/containers"
if [ -d "$DOCKER_LOGS" ]; then
    find "$DOCKER_LOGS" -name "*-json.log" -mtime +7 -exec truncate -s 0 {} \;
fi

echo "Log cleanup complete at $(date '+%Y-%m-%d %H:%M:%S')"

# Clear systemd journal logs older than 7 days
journalctl --vacuum-time=7d

