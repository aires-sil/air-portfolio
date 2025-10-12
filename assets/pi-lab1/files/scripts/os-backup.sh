#!/bin/bash
BACKUP_DIR="/mnt/nvme/share/usb-backup"
USB_DEVICE="/dev/sda"
DATE=$(date +%F)

mkdir -p "$BACKUP_DIR"

# Backup with PiShrink to save space
sudo /usr/local/bin/pishrink.sh -z "$USB_DEVICE" "$BACKUP_DIR/backup_$DATE.img"

# Delete backups older than 2 days
find "$BACKUP_DIR" -name "backup_*.img" -mtime +2 -delete
