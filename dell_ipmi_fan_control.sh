#!/bin/bash

DATE=$(date "+%Y-%m-%d %H:%M.%S")
echo "$DATE"

PID_FILE="/run/dell_ipmi_fan_control.pid"
IDRACIP="IP地址"
IDRACUSER="用户名"
IDRACPASSWORD="密码"
TEMPTHRESHOLD="55"


DIR=$(cd "$(dirname "$0")";pwd)
FILENAME=$(echo $0 | awk -F "/" '{print $NF}')
 
if [ -f /etc/os-release ]; then
    source /etc/os-release
    if [ "$ID" == "centos" ]; then
        grep $FILENAME /var/spool/cron/root
        if [ "$?" != "0" ]; then
            echo "*/1 * * * * /bin/bash $DIR"/"$FILENAME >> /tmp/dell_ipmi_fan_control.log" >> /var/spool/cron/root
        fi
    elif [ "$ID" == "ubuntu" ]; then
        grep $FILENAME /var/spool/cron/crontabs/root
        if [ "$?" != "0" ]; then
            echo "*/1 * * * * /bin/bash $DIR"/"$FILENAME >> /tmp/dell_ipmi_fan_control.log" >> /var/spool/cron/crontabs/root
        fi
    fi
else
    echo "系统版本过低"
    exit
fi

if [ "$ID" == "centos" ]; then
    if [ "$VERSION_ID" -ge "7" ]; then
        HAS_SYSTEMD=true
    fi
elif [ "$ID" == "ubuntu" ]; then
    if [ $(echo "$VERSION_ID >= "16.04"" | bc) -eq 1 ]; then
        HAS_SYSTEMD=true
    fi
fi

echo
if [ "$HAS_SYSTEMD" == true ]; then
    SERVICE_PATH="/etc/systemd/system/dell_ipmi_fan_control.service"

    if [ ! -f $SERVICE_PATH ]; then
        FIRST_RUN=true
        cat>$SERVICE_PATH<<EOF
[Unit]
Description= dell fan control with ipmi
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/run/dell_ipmi_fan_control.pid
ExecStart=$DIR"/"$FILENAME

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start dell_ipmi_fan_control.service
    systemctl enable dell_ipmi_fan_control.service

    fi
fi


if [ "$FIRST_RUN" == true ]; then
    exit
fi

if [ -s $PID_FILE ]; then
    PID=$(cat $PID_FILE)
    echo "服务运行，pid=$PID，退出"
    exit
else
    echo $$ > $PID_FILE
fi

while true; do
    T=$(ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type temperature | grep -E "^Temp" | cut -d"|" -f5 | cut -d" " -f2 | grep -v "Disabled")

    if [[ $T =~ ^\d* ]]; then
        echo "$IDRACIP: -- 当前温度为 $T度 --"

        if [[ $T > $TEMPTHRESHOLD ]]; then
            echo "--> 温度高于55度，启用自动风扇控制"
            ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x01
        else
            echo "--> 温度低于50度，启用手动风扇控制"
            ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x00
 
            if [[ $T > 45 ]]; then
                echo "--> 温度高于45度，设定风扇转速为16%"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x10
            else
                echo "--> 温度低于40度，设定风扇转速为 10%"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x0a
            fi 
        fi 
    else
        continue
    fi 
done
