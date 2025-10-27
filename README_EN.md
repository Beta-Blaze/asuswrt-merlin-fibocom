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
