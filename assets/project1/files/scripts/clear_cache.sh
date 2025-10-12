#!/bin/bash
# Delete all files older than 7 days in /var/cache

find /var/cache -type f -mtime +7 -exec rm -f {} \;
