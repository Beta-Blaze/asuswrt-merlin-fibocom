#!/bin/bash

# Определяем абсолютный путь к скрипту и его директории
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Экспортируем переменные, чтобы дочерние скрипты их видели
export CONFIG_FILE="$SCRIPT_DIR/modem.conf"
export SUB_SCRIPT_DIR="$SCRIPT_DIR/scripts"

# Проверяем, существует ли файл конфигурации
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Проверяем, существует ли директория со скриптами
if [ ! -d "$SUB_SCRIPT_DIR" ]; then
    echo "ERROR: Scripts directory not found at $SUB_SCRIPT_DIR"
    exit 1
fi

# Функция для отображения меню
show_menu() {
    clear
    echo "================================="
    echo "      Modem Control Menu         "
    echo "================================="
    echo " 1. Enable Multi-WAN (Full Config)"
    echo " 2. Enable Multi-WAN (Routing Only)"
    echo " 3. Disable Multi-WAN"
    echo " 4. Show Modem Info (Monitor)"
    echo " 0. Exit"
    echo "================================="
    read -p "Enter your choice [0-4]: " choice
    echo ""
    
    case $choice in
        1)
            echo "Starting: Enable Multi-WAN (Full Config)..."
            bash "$SUB_SCRIPT_DIR/enable_wan.sh" "full"
            ;;
        2)
            echo "Starting: Enable Multi-WAN (Routing Only)..."
            bash "$SUB_SCRIPT_DIR/enable_wan.sh" "route"
            ;;
        3)
            echo "Starting: Disable Multi-WAN..."
            bash "$SUB_SCRIPT_DIR/disable_wan.sh"
            ;;
        4)
            echo "Starting: Modem Info Monitor..."
            bash "$SUB_SCRIPT_DIR/monitor_modem.sh"
            ;;
        0)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 2
            show_menu
            ;;
    esac
}

# --- Главная логика ---

# Если скрипт запущен без аргументов, показать меню
if [ -z "$1" ]; then
    show_menu
    exit 0
fi

# Если аргументы есть, обрабатываем их как флаги
MODE=$1
echo "Running in command-line mode: $MODE" | tee $LOGFILE

case $MODE in
    enable | default)
        bash "$SUB_SCRIPT_DIR/enable_wan.sh" "full"
        ;;
    route)
        bash "$SUB_SCRIPT_DIR/enable_wan.sh" "route"
        ;;
    disable)
        bash "$SUB_SCRIPT_DIR/disable_wan.sh"
        ;;
    info)
        bash "$SUB_SCRIPT_DIR/monitor_modem.sh"
        ;;
    *)
        echo "Unknown flag: $MODE"
        echo "Usage: $0 [enable|route|disable|info]"
        echo "Running without flags will show the menu."
        exit 1
        ;;
esac

exit 0