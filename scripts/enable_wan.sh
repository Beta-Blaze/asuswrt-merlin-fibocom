#!/bin/bash

# Подключаем .conf и общие функции
if [ -z "$CONFIG_FILE" ]; then
    echo "ERROR: CONFIG_FILE not set." >&2
    exit 1
fi
source "$CONFIG_FILE"
source "$(dirname "$0")/common_functions.sh"

# Внутренний режим: "full" (по умолчанию) или "route"
INTERNAL_MODE=$1

# --- Сначала проверяем есть ли модем ---
if ! check_and_init_device; then
    echo "Exiting configuration due to device error." | tee -a $LOGFILE
    exit 1
fi

echo "=== Starting modem configuration ===" | tee -a $LOGFILE
echo "Time: $(date)" | tee -a $LOGFILE
echo "Mode: ${INTERNAL_MODE:-full}" | tee -a $LOGFILE
echo "" | tee -a $LOGFILE

# Send commands with socat
send_at() {
    echo "Sending: $1" | tee -a $LOGFILE
    
    # -T1.0 = Таймаут 1 сек. Гарантирует, что socat не зависнет, если модем молчит.
    # b115200,raw,echo=0 = Параметры TTY, которые ты только что успешно проверил.
    
    echo "$1" | socat -T5.0 - $TTY,crnl,b115200,raw,echo=0 2>&1 | grep -v '^[[:space:]]*$' | tee -a $LOGFILE
    usleep 300000
}

# --- Конфигурация модема ---
if [ "$INTERNAL_MODE" != "route" ]; then
    echo "Performing FULL modem configuration..." | tee -a $LOGFILE

    send_at "AT+CFUN=1"
    send_at "AT+CGPIAF=1,0,0,0"
    send_at "AT+CREG=0"
    send_at "AT+CGREG=0"
    send_at "AT+CEREG=0"
    send_at "AT+CGATT=0"
    sleep 1

    send_at "AT+COPS=2"
    sleep 2
    send_at "AT+COPS=3,0"
    sleep 1
    send_at "AT+CGDCONT=0,\"IPV4V6\""
    sleep 2
    send_at "AT+CGDCONT=1,\"IPV4V6\",\"$MODEM_APN\""
    sleep 3
    send_at "AT+GTACT=$MODEM_GTACT_PARAMS"
    sleep 1
    send_at "AT+COPS=0"
    send_at "AT+CGATT=1"
    send_at "AT+CGACT=1,1"
    sleep 2
else
    echo "Mode 'route' detected. SKIPPING modem configuration, proceeding to get IP." | tee -a $LOGFILE
fi

# --- Получение IP и настройка сети ---
echo "Getting IP address..." | tee -a $LOGFILE
RESULT=$(echo "AT+CGPADDR=1; +GTDNS=1" | socat -T5.0 - $TTY,crnl,b115200,raw,echo=0 2>&1)
echo "$RESULT" | tee -a $LOGFILE

# Extract IP address from CGPADDR response
ip=$(echo "$RESULT" | grep -oP '\+CGPADDR: 1,"\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

# Check if IP was extracted
if [ -z "$ip" ]; then
    echo "ERROR: Failed to get IP address from modem!" | tee -a $LOGFILE
    exit 1
fi

echo "IP address: $ip" | tee -a $LOGFILE

# Извлечение префикса (первые три октета)
prefix=${ip%.*}

# Формируем mask и gateway
mask="${prefix}.0"
gateway="${prefix}.1"

echo "IP: $ip" | tee -a $LOGFILE
echo "Mask: $mask" | tee -a $LOGFILE
echo "Gateway: $gateway" | tee -a $LOGFILE

echo "" | tee -a $LOGFILE

# Настройка интерфейса eth7
ip address add $ip/24 dev eth7
ip link set eth7 up

# Маршрутизация через таблицу wan1
ip route change $mask/24 dev eth7 src $ip table 200
ip route change default via $gateway dev eth7 table 200

# Правила политики маршрутизации
ip rule add from $ip lookup 200 prio 100
ip rule add oif eth7 lookup 200 prio 101

# Отключение проверки обратного пути
echo 0 > /proc/sys/net/ipv4/conf/eth7/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/eth0/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

# NAT
iptables -t nat -I POSTROUTING 1 -o eth7 -j MASQUERADE

# Балансировка нагрузки на выходы
ip route change default scope global \
  nexthop via 192.168.0.1 dev eth0 weight 2 \
  nexthop via $gateway dev eth7 weight 1

# Роутинг по L4 
echo 1 > /proc/sys/net/ipv4/fib_multipath_hash_policy

# Сброс кеша, для перестоения хеша
ip route flush cache

# Загрушка для интерфейса
nvram set wan1_state_t="2"
nvram set wan1_realip_state="2"
nvram set wan1_sbstate_t="0"
nvram commit

echo "=== Configuration completed ===" | tee -a $LOGFILE
echo "Log saved to $LOGFILE"