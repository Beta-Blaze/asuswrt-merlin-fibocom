#!/bin/bash

# Подключаем .conf
if [ -z "$CONFIG_FILE" ]; then
    echo "ERROR: CONFIG_FILE not set." >&2
    exit 1
fi
source "$CONFIG_FILE"

echo "=== Disable mode: Rollback of multi-WAN configuration ===" | tee $LOGFILE

# 1. Восстанавливаем маршрут по умолчанию только на eth0
echo "1. Restore default route to $ETH0_GATEWAY (eth0)..." | tee -a $LOGFILE
ip route replace default via $ETH0_GATEWAY dev eth0

# 2. Сбрасываем кеш маршрутизации
echo "2. Cache reset..." | tee -a $LOGFILE
ip route flush cache

echo "=== Multi-WAN is disabled. ===" | tee -a $LOGFILE
exit 0