#!/bin/bash
# Badblocks-based backup for Pi5
# Usage: --usb | --nvme

# =========================
# CONFIG
# =========================
BACKUP_BASE="/mnt/nvme/share"
USB_DEVICE="/dev/sda"
NVME_DEVICE="/dev/nvme0n1"

USB_BACKUP_DIR="$BACKUP_BASE/usb-backup"
NVME_BACKUP_DIR="$BACKUP_BASE/nvme-backup"
LOG_DIR="$BACKUP_BASE/health-logs"
BADBLOCK_LOG_DIR="/mnt/nvme/health_check"

mkdir -p "$USB_BACKUP_DIR" "$NVME_BACKUP_DIR" "$LOG_DIR" "$BADBLOCK_LOG_DIR"

DATE=$(date +%F)
USB_BB_LOG="$BADBLOCK_LOG_DIR/usb_badblocks.log"
NVME_BB_LOG="$BADBLOCK_LOG_DIR/nvme_badblocks.log"
MAIN_LOG="$LOG_DIR/disk_health_${DATE}.log"

# =========================
# FUNCTIONS
# =========================
stop_containers() {
    echo "[$(date)] Stopping Minecraft and Jellyfin..." >> "$MAIN_LOG"
    docker stop minecraft-bedrock jellyfin
}

start_containers() {
    echo "[$(date)] Starting Minecraft and Jellyfin..." >> "$MAIN_LOG"
    docker start minecraft-bedrock jellyfin
}

check_badblocks() {
    local device="$1"
    # Run non-destructive test and count bad blocks
    sudo badblocks -nsv "$device" 2>&1 | grep -E "blocks out of" | awk '{print $1}' || echo 0
}

log_badblocks() {
    local device="$1"
    local current_count="$2"
    local log_file="$3"

    local last_count=0
    if [[ -f "$log_file" ]]; then
        last_count=$(tail -n1 "$log_file" | awk '{print $NF}')
    fi

    if (( current_count > last_count )); then
        echo "[$(date)] $device badblocks increased: $last_count -> $current_count" >> "$log_file"
        return 0  # backup should run
    else
        return 1  # no backup needed
    fi
}

backup_usb() {
    echo "[$(date)] Checking USB badblocks..." >> "$MAIN_LOG"
    bb_count=$(check_badblocks "$USB_DEVICE")
    if log_badblocks "USB" "$bb_count" "$USB_BB_LOG"; then
        RAW_IMG="$USB_BACKUP_DIR/backup_usb_${DATE}.img"
        SHRUNK_IMG="$USB_BACKUP_DIR/backup_usb_${DATE}_shrunk.img"

        echo "[$(date)] Starting USB backup..." >> "$MAIN_LOG"
        sync
        sudo dd if="$USB_DEVICE" bs=4M status=progress of="$RAW_IMG"
        sudo /usr/local/bin/pishrink.sh -z "$RAW_IMG" "$SHRUNK_IMG"
        rm "$RAW_IMG"
        echo "[$(date)] USB backup complete: $SHRUNK_IMG" >> "$MAIN_LOG"

        # Keep only last 3 backups
        ls -1tr "$USB_BACKUP_DIR"/backup_usb_*_shrunk.img | head -n -3 | xargs -d '\n' rm -f --
    else
        echo "[$(date)] USB badblocks unchanged. Skipping USB backup." >> "$MAIN_LOG"
    fi
}

backup_nvme() {
    echo "[$(date)] Checking NVMe badblocks..." >> "$MAIN_LOG"
    bb_count=$(check_badblocks "$NVME_DEVICE")
    if log_badblocks "NVMe" "$bb_count" "$NVME_BB_LOG"; then
        DEST_DIR="$NVME_BACKUP_DIR/$DATE"
        mkdir -p "$DEST_DIR"

        stop_containers

        echo "[$(date)] Starting NVMe backup (rsync)..." >> "$MAIN_LOG"
        rsync -aAXv --delete \
            --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/cache/*","/log/*","/swapfile","$NVME_BACKUP_DIR/*","$USB_BACKUP_DIR/*","$LOG_DIR/*"} \
            "/mnt/nvme/" "$DEST_DIR"/

        echo "[$(date)] NVMe backup complete: $DEST_DIR" >> "$MAIN_LOG"

        start_containers

        # Keep only last 3 NVMe backups
        ls -1tr "$NVME_BACKUP_DIR"/* | head -n -3 | xargs -d '\n' rm -rf --
    else
        echo "[$(date)] NVMe badblocks unchanged. Skipping NVMe backup." >> "$MAIN_LOG"
    fi
}

# =========================
# RUN BASED ON FLAG
# =========================
case "$1" in
    --usb)
        backup_usb
        ;;
    --nvme)
        backup_nvme
        ;;
    *)
        echo "Usage: $0 --usb|--nvme"
        exit 1
        ;;
esac

