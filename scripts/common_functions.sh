#!/bin/bash

# Подключаем .conf (путь к нему должен быть в $CONFIG_FILE)
if [ -z "$CONFIG_FILE" ]; then
    echo "ERROR: CONFIG_FILE not set." >&2
    exit 1
fi
source "$CONFIG_FILE"

# Функция проверки и инициализации TTY
check_and_init_device() {
    if [ ! -c "$TTY" ]; then
        echo "Device $TTY not found, loading modules..." | tee $LOGFILE

        modprobe usbserial
        modprobe option

        echo "0e8d 7126" > /sys/bus/usb-serial/drivers/option1/new_id
        echo "0e8d 7127" > /sys/bus/usb-serial/drivers/option1/new_id

        sleep 2

        if [ ! -c "$TTY" ]; then
            echo "ERROR: Device $TTY still not found!" | tee -a $LOGFILE
            return 1 # Используем код возврата вместо exit
        fi

        echo "Device $TTY successfully initialized" | tee -a $LOGFILE
    else
        echo "Device $TTY found" | tee $LOGFILE
    fi
    return 0
}