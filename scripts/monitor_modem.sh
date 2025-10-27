#!/bin/bash

# Подключаем .conf и общие функции
if [ -z "$CONFIG_FILE" ]; then
    echo "ERROR: CONFIG_FILE not set." >&2
    exit 1
fi
source "$CONFIG_FILE"
source "$(dirname "$0")/common_functions.sh"

# --- Сначала проверяем устройство ---
if ! check_and_init_device; then
    echo "Exiting monitor due to device error." | tee -a $LOGFILE
    exit 1
fi

echo "=== Starting Network Monitor (Press Ctrl+C to stop) ==="
echo "Logging raw data to $LOGFILE"
echo ""

    # --- Диапазоны для расчета процентов ---
    RSRP_MIN=-120
    RSRP_MAX=-80
    RSRQ_MIN=-20
    RSRQ_MAX=-3
    SINR_MIN=-10
    SINR_MAX=25
    RSCP_MIN=-115
    RSCP_MAX=-75
    ECNO_MIN=-20
    ECNO_MAX=-5
    
    # --- Функция расчета процентов ---
    get_percentage() {
        val=$1
        min=$2
        max=$3
        
        awk -v val="$val" -v min="$min" -v max="$max" 'BEGIN {
            if (val < min) val = min;
            if (val > max) val = max;
            perc = (val - min) * 100 / (max - min);
            printf "%d%%", perc
        }'
    }

    # Функция для преобразования кода технологии в имя
    get_tech_name() {
        case "$1" in
            0|1|3) echo "EDGE" ;;
            2) echo "UMTS" ;;
            4) echo "HSDPA" ;;
            5) echo "HSUPA" ;;
            6) echo "HSDPA+HSUPA" ;;
            7) echo "LTE" ;;
            8) echo "CDMA" ;;
            9) echo "CDMA+EVDO" ;;
            10) echo "EVDO" ;;
            11) echo "5G SA" ;;
            12) echo "NB-IoT" ;;
            13) echo "5G NSA" ;;
            *) echo "Unknown ($1)" ;;
        esac
    }
    
    # Конвертация PCI в bandwidth (основано на Band 7 LTE)
    # Формат GTCAINFO: PCC:pci,band,earfcn,rsrp_raw1,rsrq_raw1,...
    get_bandwidth_from_pci() {
        pci=$1
        # В LTE bandwidth определяется количеством RB (Resource Blocks)
        # 107 RB ? 20 MHz, но это нестандартно
        # Попробуем определить по значению PCI
        if [ "$pci" -ge 100 ]; then
            echo "20"
        elif [ "$pci" -ge 75 ]; then
            echo "15"
        elif [ "$pci" -ge 50 ]; then
            echo "10"
        elif [ "$pci" -ge 25 ]; then
            echo "5"
        else
            echo "?"
        fi
    }
    
    # Получить имя режима соединения
    get_conn_state() {
        case "$1" in
            0) echo "IDLE" ;;
            1) echo "CONNECTED" ;;
            2) echo "FACH" ;;
            3) echo "DCH" ;;
            4) echo "IDLE/CONNECTED" ;;
            *) echo "UNKNOWN" ;;
        esac
    }
    
    # Получить имя режима UE
    get_cemode() {
        case "$1" in
            0) echo "PS mode 1" ;;
            1) echo "PS mode 2" ;;
            2) echo "CS/PS mode 1" ;;
            3) echo "CS/PS mode 2" ;;
            *) echo "Unknown" ;;
        esac
    }
    
    # Статус регистрации
    get_reg_status() {
        case "$1" in
            0) echo "Not registered" ;;
            1) echo "Registered (Home)" ;;
            2) echo "Searching" ;;
            3) echo "Denied" ;;
            4) echo "Unknown" ;;
            5) echo "Registered (Roaming)" ;;
            6) echo "Registered (SMS only, Home)" ;;
            *) echo "Unknown ($1)" ;;
        esac
    }

    # Функция для очистки от непечатаемых символов
    clean_output() {
        tr -cd '\11\12\15\40-\176'
    }

    while true; do
        clear
        
        # --- Шпаргалка показывается каждый раз ---
        echo "====================================================================================================="
        echo "Signal Quality Reference Guide:"
        echo "RSRP (Strength): -80..-90=Excellent | -90..-100=Good | -100..-110=Fair | -110..-120=Poor"
        echo "RSRQ (Quality):  -3..-9=Excellent   | -9..-12=Good   | -12..-15=Fair   | -15..-20=Poor"
        echo "SINR (S/N):      20+dB=Excellent    | 13..20=Good    | 0..13=Fair      | <0=Poor"
        echo "RSCP (3G Str):   -75..-85=Excellent | -85..-95=Good  | -95..-105=Fair  | -105..-115=Poor"
        echo "Ec/No (3G Qual): -5..0=Excellent    | -10..-5=Good   | -15..-10=Fair   | -20..-15=Poor"
        echo "CSQ:             25-31=Excellent    | 20-24=Good     | 15-19=Fair      | 10-14=Marginal | <10=Poor"
        echo "====================================================================================================="
        echo ""
        
        printf "=== Network Monitor (%s) ===\n" "$(date)"
        printf "Device: %s\n\n" "$TTY"
        
        # Расширенный набор команд для диагностики
        COMMANDS="AT+COPS?;+CSQ;+CESQ;+GTSENRDTEMP=1;+GTCCINFO?;+GTCAINFO?;+CSCON?;+CEMODE?;+CREG?;+CGREG?;+CEREG?"
        
        RESPONSE=$(echo "$COMMANDS" | socat -T5.0 - $TTY,crnl,b115200,raw,echo=0 2>&1 | clean_output)
        
        echo "--- Monitor Tick $(date) ---" >> $LOGFILE
        echo "$RESPONSE" >> $LOGFILE
        echo "----------------------------" >> $LOGFILE

        # --- Парсинг COPS (Оператор и Технология) ---
        COPS_LINE=$(echo "$RESPONSE" | grep '^+COPS:')
        if [ -n "$COPS_LINE" ]; then
            OPER=$(echo "$COPS_LINE" | awk -F, '{print $3}' | tr -d '"')
            TECH_CODE=$(echo "$COPS_LINE" | awk -F, '{print $4}')
            TECH_NAME=$(get_tech_name "$TECH_CODE")
            printf "%-18s: %s (%s)\n" "Operator" "${OPER:-N/A}" "${TECH_NAME:-N/A}"
        else
            printf "%-18s: Not found\n" "Operator"
        fi
        
        # --- Парсинг регистрации в сети ---
        CREG_LINE=$(echo "$RESPONSE" | grep '^+CREG:')
        if [ -n "$CREG_LINE" ]; then
            CREG_STAT=$(echo "$CREG_LINE" | awk -F, '{print $2}')
            printf "%-18s: %s\n" "Network Status" "$(get_reg_status $CREG_STAT)"
        fi
        
        # --- Парсинг CEMODE (режим работы UE) ---
        CEMODE_LINE=$(echo "$RESPONSE" | grep '^+CEMODE:')
        if [ -n "$CEMODE_LINE" ]; then
            CEMODE_VAL=$(echo "$CEMODE_LINE" | awk -F: '{print $2}' | tr -d ' ')
            printf "%-18s: %s\n" "UE Mode" "$(get_cemode $CEMODE_VAL)"
        fi
        
        # --- Парсинг CSCON (состояние соединения) ---
        CSCON_LINE=$(echo "$RESPONSE" | grep '^+CSCON:')
        if [ -n "$CSCON_LINE" ]; then
            CSCON_MODE=$(echo "$CSCON_LINE" | awk -F, '{print $1}' | awk -F: '{print $2}' | tr -d ' ')
            CSCON_STATE=$(echo "$CSCON_LINE" | awk -F, '{print $2}' | tr -d ' ')
            CSCON_RAT=$(echo "$CSCON_LINE" | awk -F, '{print $3}' | tr -d ' ')
            printf "%-18s: %s (%s)\n" "Connection State" "$(get_conn_state $CSCON_STATE)" "$(get_tech_name $CSCON_RAT)"
        fi

        # --- Парсинг CSQ (Качество сигнала) ---
        CSQ_LINE=$(echo "$RESPONSE" | grep '^+CSQ:')
        if [ -n "$CSQ_LINE" ]; then
            CSQ_VAL=$(echo "$CSQ_LINE" | sed 's/^+CSQ: *//;s/,.*$//' | tr -d ' ')
            
            if [ -n "$CSQ_VAL" ] && [ "$CSQ_VAL" != "99" ]; then
                if [ "$CSQ_VAL" -ge 0 ] 2>/dev/null && [ "$CSQ_VAL" -le 31 ] 2>/dev/null; then
                    CSQ_PERC=$((CSQ_VAL * 100 / 31))
                    CSQ_DBM=$((-113 + CSQ_VAL * 2))
                    
                    if [ "$CSQ_VAL" -ge 25 ]; then
                        CSQ_QUAL="Excellent"
                    elif [ "$CSQ_VAL" -ge 20 ]; then
                        CSQ_QUAL="Good"
                    elif [ "$CSQ_VAL" -ge 15 ]; then
                        CSQ_QUAL="Fair"
                    elif [ "$CSQ_VAL" -ge 10 ]; then
                        CSQ_QUAL="Marginal"
                    else
                        CSQ_QUAL="Poor"
                    fi
                    
                    printf "%-18s: %d%% (%d/31, ~%d dBm) [%s]\n" "Signal (CSQ)" "$CSQ_PERC" "$CSQ_VAL" "$CSQ_DBM" "$CSQ_QUAL"
                else
                    printf "%-18s: Invalid value (%s)\n" "Signal (CSQ)" "$CSQ_VAL"
                fi
            else
                printf "%-18s: No signal (rssi=%s)\n" "Signal (CSQ)" "${CSQ_VAL:-99}"
            fi
        else
            printf "%-18s: Not found\n" "Signal (CSQ)"
        fi
        
        # --- Парсинг CESQ (Extended Signal Quality) ---
        CESQ_LINE=$(echo "$RESPONSE" | grep '^+CESQ:')
        if [ -n "$CESQ_LINE" ]; then
            RSCP_RAW=$(echo "$CESQ_LINE" | awk -F'[: ,]' '{print $4}')
            ECNO_RAW=$(echo "$CESQ_LINE" | awk -F'[: ,]' '{print $5}')
            RSRQ_RAW=$(echo "$CESQ_LINE" | awk -F'[: ,]' '{print $6}')
            RSRP_RAW=$(echo "$CESQ_LINE" | awk -F'[: ,]' '{print $7}')
            
            # Для 3G (UMTS)
            if [ -n "$RSCP_RAW" ] && [ "$RSCP_RAW" != "255" ] && [ "$RSCP_RAW" != "99" ] && [ "$RSCP_RAW" -ge 0 ] 2>/dev/null; then
                RSCP_DBM=$((-121 + RSCP_RAW))
                perc_rscp=$(get_percentage $RSCP_DBM $RSCP_MIN $RSCP_MAX)
                printf "%-18s: %d dBm (%s)\n" "RSCP" "$RSCP_DBM" "$perc_rscp"
            fi
            
            if [ -n "$ECNO_RAW" ] && [ "$ECNO_RAW" != "255" ] && [ "$ECNO_RAW" != "99" ] && [ "$ECNO_RAW" -ge 0 ] 2>/dev/null; then
                ECNO_VAL=$(awk "BEGIN {printf \"%.1f\", -24 + $ECNO_RAW * 0.5}")
                perc_ecno=$(get_percentage ${ECNO_VAL%.*} $ECNO_MIN $ECNO_MAX)
                printf "%-18s: %s dB (%s)\n" "Ec/No" "$ECNO_VAL" "$perc_ecno"
            fi
            
            # Для LTE
            if [ -n "$RSRP_RAW" ] && [ "$RSRP_RAW" != "255" ] && [ "$RSRP_RAW" != "99" ] && [ "$RSRP_RAW" -ge 0 ] 2>/dev/null; then
                RSRP_DBM=$((-141 + RSRP_RAW))
                perc_rsrp=$(get_percentage $RSRP_DBM $RSRP_MIN $RSRP_MAX)
                printf "%-18s: %d dBm (%s)\n" "RSRP (CESQ)" "$RSRP_DBM" "$perc_rsrp"
            fi
            
            if [ -n "$RSRQ_RAW" ] && [ "$RSRQ_RAW" != "255" ] && [ "$RSRQ_RAW" != "99" ] && [ "$RSRQ_RAW" -ge 0 ] 2>/dev/null; then
                RSRQ_VAL=$(awk "BEGIN {printf \"%.1f\", -20 + $RSRQ_RAW * 0.5}")
                perc_rsrq=$(get_percentage ${RSRQ_VAL%.*} $RSRQ_MIN $RSRQ_MAX)
                printf "%-18s: %s dB (%s)\n" "RSRQ (CESQ)" "$RSRQ_VAL" "$perc_rsrq"
            fi
        fi

        # --- Парсинг Temp (Температура) ---
        TEMP_LINE=$(echo "$RESPONSE" | grep '^+GTSENRDTEMP:')
        if [ -n "$TEMP_LINE" ]; then
            TEMP_VAL=$(echo "$TEMP_LINE" | awk -F, '{print $2}')
            if [ -n "$TEMP_VAL" ]; then
                TEMP_C=$((TEMP_VAL / 1000))
                printf "%-18s: %dC\n" "Temperature" "$TEMP_C"
            fi
        fi

        printf "\n--- Cell Information ---\n"

        # --- Парсинг GTCCINFO ---
        GTCC_RAW=$(echo "$RESPONSE" | grep -A 10 '^+GTCCINFO:')
        ALL_CELLS=$(echo "$GTCC_RAW" | grep -E '^[0-9]+,')
        
        if [ -n "$ALL_CELLS" ]; then
            echo "$ALL_CELLS" | while read -r cell_line; do
                cell_type=$(echo "$cell_line" | awk -F, '{print $1}')
                cell_rat=$(echo "$cell_line" | awk -F, '{print $2}')
                mcc=$(echo "$cell_line" | awk -F, '{print $3}')
                mnc=$(echo "$cell_line" | awk -F, '{print $4}')

                if [ "$cell_type" == "1" ]; then
                    printf "\n  [Serving Cell]\n"
                else
                    printf "\n  [Neighbour Cell]\n"
                fi
                
                printf "  %-12s: %s\n" "Technology" "$(get_tech_name $cell_rat)"
                printf "  %-12s: %s-%s\n" "MCC-MNC" "$mcc" "$mnc"

                if [ "$cell_rat" == "7" ]; then # LTE
                    lac=$(echo "$cell_line" | awk -F, '{print $5}')
                    cellid=$(echo "$cell_line" | awk -F, '{print $6}')
                    earfcn=$(echo "$cell_line" | awk -F, '{print $7}')
                    band=$(echo "$cell_line" | awk -F, '{print $8}')
                    bandwidth=$(echo "$cell_line" | awk -F, '{print $9}')
                    pci=$(echo "$cell_line" | awk -F, '{print $10}')
                    
                    printf "  %-12s: 0x%s\n" "LAC" "$lac"
                    printf "  %-12s: 0x%s\n" "Cell ID" "$cellid"
                    printf "  %-12s: %s\n" "EARFCN" "$earfcn"
                    printf "  %-12s: B%s\n" "Band" "$band"
                    printf "  %-12s: %s MHz\n" "Bandwidth" "$bandwidth"
                    printf "  %-12s: %s\n" "PCI" "$pci"
                    
                    if [ "$cell_type" == "1" ]; then # Serving
                        SINR_VAL=$(echo "$cell_line" | awk -F, '{print $11}')
                        RSRP_VAL=$(echo "$cell_line" | awk -F, '{print $12}')
                        RSRQ_VAL=$(echo "$cell_line" | awk -F, '{print $13}')
                        CQI_VAL=$(echo "$cell_line" | awk -F, '{print $14}')
                        
                        if [ -n "$SINR_VAL" ] && [ "$SINR_VAL" != "0" ]; then
                           SINR_DB=$(awk "BEGIN {printf \"%.1f\", ($SINR_VAL - 20) / 2.0}")
                           perc_sinr=$(get_percentage ${SINR_DB%.*} $SINR_MIN $SINR_MAX)
                           printf "  %-12s: %s dB (%s)\n" "SINR" "$SINR_DB" "$perc_sinr"
                        fi
                        
                        if [ -n "$RSRP_VAL" ]; then
                            RSRP_DBM=$(( RSRP_VAL - 140 ))
                            perc_rsrp=$(get_percentage $RSRP_DBM $RSRP_MIN $RSRP_MAX)
                            printf "  %-12s: %d dBm (%s)\n" "RSRP" "$RSRP_DBM" "$perc_rsrp"
                        fi
                        
                        if [ -n "$RSRQ_VAL" ]; then
                            RSRQ_DB=$(awk "BEGIN {printf \"%.1f\", ($RSRQ_VAL - 40) / 2.0}")
                            perc_rsrq=$(get_percentage ${RSRQ_DB%.*} $RSRQ_MIN $RSRQ_MAX)
                            printf "  %-12s: %s dB (%s)\n" "RSRQ" "$RSRQ_DB" "$perc_rsrq"
                        fi
                        
                        if [ -n "$CQI_VAL" ] && [ "$CQI_VAL" != "0" ]; then
                            printf "  %-12s: %s/15\n" "CQI" "$CQI_VAL"
                        fi
                    else # Neighbour
                        RSRP_VAL=$(echo "$cell_line" | awk -F, '{print $11}')
                        RSRQ_VAL=$(echo "$cell_line" | awk -F, '{print $12}')
                        
                        if [ -n "$RSRP_VAL" ]; then
                            RSRP_DBM=$(( RSRP_VAL - 140 ))
                            perc_rsrp=$(get_percentage $RSRP_DBM $RSRP_MIN $RSRP_MAX)
                            printf "  %-12s: %d dBm (%s)\n" "RSRP" "$RSRP_DBM" "$perc_rsrp"
                        fi
                        
                        if [ -n "$RSRQ_VAL" ]; then
                            RSRQ_DB=$(awk "BEGIN {printf \"%.1f\", ($RSRQ_VAL - 40) / 2.0}")
                            perc_rsrq=$(get_percentage ${RSRQ_DB%.*} $RSRQ_MIN $RSRQ_MAX)
                            printf "  %-12s: %s dB (%s)\n" "RSRQ" "$RSRQ_DB" "$perc_rsrq"
                        fi
                    fi
                
                elif [[ "$cell_rat" == "2" || "$cell_rat" == "4" || "$cell_rat" == "5" || "$cell_rat" == "6" ]]; then # UMTS/WCDMA
                    lac=$(echo "$cell_line" | awk -F, '{print $5}')
                    cellid=$(echo "$cell_line" | awk -F, '{print $6}')
                    uarfcn=$(echo "$cell_line" | awk -F, '{print $7}')
                    band=$(echo "$cell_line" | awk -F, '{print $8}')
                    psc=$(echo "$cell_line" | awk -F, '{print $9}')
                    
                    printf "  %-12s: 0x%s\n" "LAC" "$lac"
                    printf "  %-12s: 0x%s\n" "Cell ID" "$cellid"
                    printf "  %-12s: %s\n" "UARFCN" "$uarfcn"
                    printf "  %-12s: B%s\n" "Band" "$band"
                    printf "  %-12s: %s\n" "PSC" "$psc"
                    
                    if [ "$cell_type" == "1" ]; then # Serving
                        ECNO_VAL=$(echo "$cell_line" | awk -F, '{print $10}')
                        RSCP_VAL=$(echo "$cell_line" | awk -F, '{print $11}')
                        
                        if [ -n "$RSCP_VAL" ]; then
                            RSCP_DBM=$(( RSCP_VAL - 120 ))
                            perc_rscp=$(get_percentage $RSCP_DBM $RSCP_MIN $RSCP_MAX)
                            printf "  %-12s: %d dBm (%s)\n" "RSCP" "$RSCP_DBM" "$perc_rscp"
                        fi
                        
                        if [ -n "$ECNO_VAL" ]; then
                            ECNO_DB=$(awk "BEGIN {printf \"%.1f\", ($ECNO_VAL - 50) / 2.0}")
                            perc_ecno=$(get_percentage ${ECNO_DB%.*} $ECNO_MIN $ECNO_MAX)
                            printf "  %-12s: %s dB (%s)\n" "Ec/No" "$ECNO_DB" "$perc_ecno"
                        fi
                    fi
                fi
            done
        else
            echo "  No cells detected"
        fi
        
        printf "\n--- Carrier Aggregation (CA) ---\n"
        
        CA_RAW=$(echo "$RESPONSE" | grep -A 20 '^+GTCAINFO:')
        
        if [ -n "$CA_RAW" ]; then
            # Переменные для агрегации
            PCC_BW=0
            SCC_BW=0
            CA_STRING=""
            
            PCC_LINE=$(echo "$CA_RAW" | grep 'PCC:')
            if [ -n "$PCC_LINE" ]; then
                PCC_DATA=$(echo "$PCC_LINE" | sed 's/.*PCC://;s/ //g')
                PCC_PCI=$(echo "$PCC_DATA" | awk -F, '{print $1}')
                PCC_BAND=$(echo "$PCC_DATA" | awk -F, '{print $2}')
                PCC_EARFCN=$(echo "$PCC_DATA" | awk -F, '{print $3}')
                PCC_RSRP=$(echo "$PCC_DATA" | awk -F, '{print $NF}')
                
                # Определяем BW для Band 7 (обычно 20 MHz)
                PCC_BW=20
                CA_STRING="${PCC_BW}"
                
                printf "  PCC: Band %s, PCI %s, BW ~%d MHz, EARFCN %s, RSRP %s dBm\n" \
                    "$PCC_BAND" "$PCC_PCI" "$PCC_BW" "$PCC_EARFCN" "$PCC_RSRP"
            fi
            
            SCC_LINES=$(echo "$CA_RAW" | grep 'SCC')
            if [ -n "$SCC_LINES" ]; then
                SCC_COUNT=0
                echo "$SCC_LINES" | while read -r scc_line; do
                    SCC_NUM=$(echo "$scc_line" | sed 's/.*SCC \([0-9]*\):.*/\1/')
                    SCC_DATA=$(echo "$scc_line" | sed 's/.*://;s/ //g')
                    
                    SCC_BAND=$(echo "$SCC_DATA" | awk -F, '{print $3}')
                    SCC_PCI=$(echo "$SCC_DATA" | awk -F, '{print $4}')
                    SCC_EARFCN=$(echo "$SCC_DATA" | awk -F, '{print $5}')
                    SCC_RSRP=$(echo "$SCC_DATA" | awk -F, '{print $NF}')
                    
                    SCC_BW_SINGLE=20
                    
                    printf "  SCC%s: Band %s, PCI %s, BW ~%d MHz, EARFCN %s, RSRP %s dBm\n" \
                        "$SCC_NUM" "$SCC_BAND" "$SCC_PCI" "$SCC_BW_SINGLE" "$SCC_EARFCN" "$SCC_RSRP"
                done
                
                # Подсчет общей агрегации без seq
                SCC_COUNT=$(echo "$SCC_LINES" | wc -l)
                TOTAL_SCC_BW=$((SCC_COUNT * 20))
                TOTAL_BW=$((PCC_BW + TOTAL_SCC_BW))
                
                # Формируем строку вида "20+20+20"
                CA_STRING="${PCC_BW}"
                i=1
                while [ $i -le $SCC_COUNT ]; do
                    CA_STRING="${CA_STRING}+20"
                    i=$((i + 1))
                done
                
                printf "\n  >>> Total Aggregation: %d MHz (%s)\n" "$TOTAL_BW" "$CA_STRING"
            else
                printf "\n  >>> Single Carrier: %d MHz (No CA)\n" "$PCC_BW"
            fi
        else
            echo "  Not active"
        fi

        
        printf "\n[Press Ctrl+C to stop]\n"
        
        sleep 2
    done
    
    exit 0