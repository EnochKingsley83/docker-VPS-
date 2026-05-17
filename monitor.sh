#!/bin/bash
# monitor.sh
# 流量监控 + Telegram告警 + 可选自动关机

# 环境变量可选，设置默认值
MODE=${MODE:-total}                   # in / out / total
QUOTA_GB=${QUOTA_GB:-180}            # 可选，默认180GB
WARNING_PERCENT=${WARNING_PERCENT:-80}# 可选，默认80%
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHATID=${TELEGRAM_CHATID}
INTERFACE=${INTERFACE:-eth0}          # 默认eth0

# 如果 QUOTA_GB 未设置，则不启用关机功能
if [ -z "$QUOTA_GB" ]; then
    SHUTDOWN_ENABLED=false
else
    SHUTDOWN_ENABLED=true
fi

# GB -> MB
QUOTA_MB=$((QUOTA_GB*1024))
WARNING_MB=$((QUOTA_MB*WARNING_PERCENT/100))

# 初始化 vnStat 数据库
vnstat -u -i $INTERFACE
vnstat -u
vnstat --update

while true; do
    sleep 60
    # 获取日流量 MB
    if [ "$MODE" = "in" ]; then
        USAGE=$(vnstat -i $INTERFACE --oneline b | awk -F';' '{print $3}')
    elif [ "$MODE" = "out" ]; then
        USAGE=$(vnstat -i $INTERFACE --oneline b | awk -F';' '{print $4}')
    else
        USAGE=$(vnstat -i $INTERFACE --oneline b | awk -F';' '{print $3+$4}')
    fi

    # 超过警告阈值
    if (( $(echo "$USAGE >= $WARNING_MB" | bc -l) )); then
        if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHATID" ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                 -d chat_id="$TELEGRAM_CHATID" \
                 -d text="⚠️ 流量已达到 $WARNING_PERCENT% ($USAGE MB / ${QUOTA_MB:-?} MB)"
        fi
    fi

    # 超额关机（仅当 QUOTA_GB 设置时）
    if [ "$SHUTDOWN_ENABLED" = true ] && (( $(echo "$USAGE >= $QUOTA_MB" | bc -l) )); then
        if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHATID" ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                 -d chat_id="$TELEGRAM_CHATID" \
                 -d text="🚨 流量已超额 ($USAGE MB / $QUOTA_MB MB)，即将关机！"
        fi
        sudo shutdown -h now
    fi
done
