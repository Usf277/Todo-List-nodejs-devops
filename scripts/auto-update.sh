#!/bin/bash

set -e

LOG="/home/ubuntu/auto-update.log"
cd /home/ubuntu/app || exit 1

echo "[$(date)] Checking for image updates..." >> $LOG

docker compose pull >> $LOG 2>&1
docker compose up -d >> $LOG 2>&1

echo "[$(date)] Cleaning unused Docker resources..." >> $LOG
docker system prune -af --volumes >> $LOG 2>&1
