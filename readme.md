
-----

# Скрипт управления модемом (ASUSWRT-Merlin)

Простой набор скриптов для управления USB-модемом Fibicom (FM350-GL) в режиме multi-WAN на роутерах ASUS с прошивкой (Asuswrt-Merlin). Позволяет настраивать, отключать и отслеживать состояние модема через AT-команды.

-----

## 🔧 Установка

Скрипт имеет одну зависимость: `socat`. Рекомендуемый путь установки — через `opkg` (который ставится из `amtm`).

1.  **Установите amtm**
    Если у вас его еще нет, установите [amtm (The Asuswrt-Merlin Terminal Menu)](https://github.com/decoderman/amtm).

    ```bash
    /usr/sbin/curl -Ls https://raw.githubusercontent.com/decoderman/amtm/master/amtm -o /jffs/scripts/amtm && chmod 755 /jffs/scripts/amtm && /jffs/scripts/amtm
    ```

2.  **Установите opkg**
    Запустите `amtm`, выберите `i` (Install), а затем `ep`

3.  **Установите socat**
    Теперь у вас есть менеджер пакетов `opkg`. Установите `socat`:

    ```bash
    opkg install socat
    ```

4.  **Скопируйте скрипты**
    Рекомендуется размещать пользовательские скрипты в `/jffs/addons`:

    ```bash
    mkdir -p /jffs/addons/modem
    ```

    Скопируйте все файлы (`modem_main.sh`, `modem.conf` и папку `scripts`) в эту директорию.

5.  **Дайте права на выполнение**

    ```bash
    chmod +x /jffs/addons/modem/modem_main.sh
    ```

-----

## 🚀 Использование

### Быстрый запуск (рекомендуется)

Чтобы не вводить каждый раз полный путь, создайте символическую ссылку в `/opt/bin/` (эта папка находится в вашем `$PATH`):

```bash
ln -sf /jffs/addons/modem/modem_main.sh /opt/bin/modem
```

Теперь вы можете запускать скрипт из любого места, просто по имени `modem`.

### Режимы работы

#### 1\. Интерактивное меню

Просто запустите скрипт без флагов:

```bash
modem
```

Вы увидите меню:

```
=================================
      Modem Control Menu
=================================
 1. Enable Multi-WAN (Full Config)
 2. Enable Multi-WAN (Routing Only)
 3. Disable Multi-WAN
 4. Show Modem Info (Monitor)
 0. Exit
=================================
```

#### 2\. Запуск с флагами

Вы можете запускать скрипты напрямую, передавая флаг:

  * `modem enable` (или `default`): Полная инициализация модема и настройка multi-WAN.
  * `modem route`: Пропускает AT-команды инициализации, сразу получает IP и настраивает роутинг.
  * `modem disable`: Откатывает роутинг, возвращая `eth0` (основной WAN) как шлюз по умолчанию.
  * `modem info`: Запускает циклический мониторинг (RSRP, SINR, Cell Info и т.д.).

-----

## ⚙️ Конфигурация (`modem.conf`)

Все пользовательские настройки вынесены в `modem.conf` для легкого редактирования.

  * `TTY`
    **Описание:** Путь к TTY-устройству вашего модема, через которое отправляются AT-команды.
    **Пример:** `/dev/ttyUSB4`

  * `LOGFILE`
    **Описание:** Имя файла, в который будут записываться ответы модема и логи работы скриптов.
    **Пример:** `modem_output.log`

  * `ETH0_GATEWAY`
    **Описание:** IP-адрес шлюза вашего основного провайдера (например, `eth0`). Используется для восстановления маршрута по умолчанию при запуске `modem disable`.
    **Пример:** `192.168.0.1`

  * `MODEM_APN`
    **Описание:** APN (Access Point Name) вашего мобильного оператора.
    **Пример:** `internet.megafon.ru`

  * `MODEM_GTACT_PARAMS`
    **Описание:** Специфичные параметры для AT-команды `+GTACT`. Не меняйте, если не уверены.
    **Пример:** `20,6,3,0`

-----

## 📁 Структура файлов

  * `modem_main.sh`
    **Главный скрипт.** Он является "входной точкой". Его задачи:

    1.  Обработать флаги (`info`, `disable` и т.д.).
    2.  Показать меню, если флагов нет.
    3.  Запустить соответствующий дочерний скрипт из папки `scripts/`.

  * `modem.conf`
    **Файл конфигурации.** Хранит ваши персональные настройки (порт, APN и т.д.).

  * `scripts/common_functions.sh`
    **Общие функции.** Содержит код, который нужен нескольким скриптам (например, функция проверки TTY-устройства `check_and_init_device`).

  * `scripts/enable_wan.sh`
    **Скрипт включения.** Содержит основную логику: отправку AT-команд для инициализации, получение IP-адреса и настройку правил `ip rule`, `ip route` и `iptables` для multi-WAN.

  * `scripts/disable_wan.sh`
    **Скрипт отключения.** "Откатывает" изменения `enable_wan.sh`, возвращая весь трафик на основной шлюз (`ETH0_GATEWAY`).

  * `scripts/monitor_modem.sh`
    **Скрипт мониторинга.** Содержит логику для режима `info`. В цикле опрашивает модем (команды `+CSQ`, `+CESQ`, `+GTCCINFO` и т.д.) и выводит на экран читаемую информацию о качестве сигнала и соте.

-----

## 🆘 Поддержка

Если у вас возникли проблемы, что-то не работает или есть предложения по улучшению — пожалуйста, **создайте Issue** в этом GitHub репозитории.


----------
----------


# Modem Control Script (ASUSWRT-Merlin)

A simple set of scripts for managing a Fibicom (FM350-GL) USB modem in a multi-WAN setup on ASUS routers running Asuswrt-Merlin firmware. It allows you to configure, disable, and monitor the modem's status via AT commands.

----------

## 🔧 Installation

The script has one dependency: `socat`. The recommended installation method is via `opkg` (which can be installed using `amtm`).

1.  Install amtm
    
    If you don't already have it, install amtm (The Asuswrt-Merlin Terminal Menu).
    
    Bash
    
    ```
    /usr/sbin/curl -Ls https://raw.githubusercontent.com/decoderman/amtm/master/amtm -o /jffs/scripts/amtm && chmod 755 /jffs/scripts/amtm && /jffs/scripts/amtm
    
    ```
    
2.  Install opkg
    
    Run amtm, select i (Install), and then ep.
    
3.  Install socat
    
    Now you have the opkg package manager. Install socat:
    
    Bash
    
    ```
    opkg install socat
    
    ```
    
4.  Copy the Scripts
    
    It's recommended to place custom scripts in /jffs/addons:
    
    Bash
    
    ```
    mkdir -p /jffs/addons/modem
    
    ```
    
    Copy all files (`modem_main.sh`, `modem.conf`, and the `scripts` folder) into this directory.
    
5.  **Set execute permissions**
    
    Bash
    
    ```
    chmod +x /jffs/addons/modem/modem_main.sh
    
    ```
    

----------

## 🚀 Usage

### Quick Launch (Recommended)

To avoid typing the full path every time, create a symbolic link in `/opt/bin/` (this folder is in your `$PATH`):

Bash

```
ln -sf /jffs/addons/modem/modem_main.sh /opt/bin/modem

```

Now you can run the script from anywhere just by typing `modem`.

### Operating Modes

#### 1. Interactive Menu

Simply run the script without any flags:

Bash

```
modem

```

You will see the menu:

```
=================================
      Modem Control Menu
=================================
 1. Enable Multi-WAN (Full Config)
 2. Enable Multi-WAN (Routing Only)
 3. Disable Multi-WAN
 4. Show Modem Info (Monitor)
 0. Exit
=================================

```

#### 2. Running with Flags

You can run the scripts directly by passing a flag:

-   `modem enable` (or `default`): Full modem initialization and multi-WAN setup.
    
-   `modem route`: Skips initialization AT commands, gets an IP immediately, and configures routing.
    
-   `modem disable`: Rolls back the routing, restoring `eth0` (primary WAN) as the default gateway.
    
-   `modem info`: Starts a continuous monitor (RSRP, SINR, Cell Info, etc.).
    

----------

## ⚙️ Configuration (`modem.conf`)

All user settings are located in `modem.conf` for easy editing.

-   TTY
    
    Description: The path to your modem's TTY device used for sending AT commands.
    
    Example: /dev/ttyUSB4
    
-   LOGFILE
    
    Description: The name of the file where modem responses and script logs will be written.
    
    Example: modem_output.log
    
-   ETH0_GATEWAY
    
    Description: The gateway IP address of your primary ISP (e.g., eth0). Used to restore the default route when running modem disable.
    
    Example: 192.168.0.1
    
-   MODEM_APN
    
    Description: The APN (Access Point Name) of your mobile carrier.
    
    Example: internet.megafon.ru
    
-   MODEM_GTACT_PARAMS
    
    Description: Specific parameters for the +GTACT AT command. Do not change unless you are sure.
    
    Example: 20,6,3,0
    

----------

## 📁 File Structure

-   modem_main.sh
    
    Main Script. This is the "entry point". Its tasks:
    
    1.  Parse flags (`info`, `disable`, etc.).
        
    2.  Show the menu if no flags are provided.
        
    3.  Execute the corresponding sub-script from the `scripts/` folder.
        
-   modem.conf
    
    Configuration File. Stores your personal settings (port, APN, etc.).
    
-   scripts/common_functions.sh
    
    Common Functions. Contains code needed by multiple scripts (e.g., the TTY device check function check_and_init_device).
    
-   scripts/enable_wan.sh
    
    Enable Script. Contains the core logic: sending AT commands for initialization, obtaining an IP address, and setting up ip rule, ip route, and iptables rules for multi-WAN.
    
-   scripts/disable_wan.sh
    
    Disable Script. "Rolls back" the changes from enable_wan.sh, returning all traffic to the primary gateway (ETH0_GATEWAY).
    
-   scripts/monitor_modem.sh
    
    Monitor Script. Contains the logic for the info mode. It polls the modem in a loop (using +CSQ, +CESQ, +GTCCINFO, etc.) and displays human-readable signal quality and cell information.
    

----------

## 🆘 Support

If you encounter any problems, something isn't working, or you have suggestions for improvement—please **create an Issue** in this GitHub repository.

----------