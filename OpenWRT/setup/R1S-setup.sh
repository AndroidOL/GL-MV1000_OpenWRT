#!/bin/sh

NEED_RESTART_SERVICE=0

setup_ssid()
{
    local r=$1

    if ! uci show wireless.${r} >/dev/null 2>&1; then
        return
    fi

    logger "${TAG}: setup $1's ssid"
    wlan_path=/sys/devices/`uci get wireless.${r}.path`
    wlan_path=`find ${wlan_path} -name wlan* | tail -n 1`
    local mac=`cat ${wlan_path}/address`
    
    local wifimac=`echo ${mac}|awk -F ":" '{print $4""$5""$6 }'|tr A-Z a-z|cut -c4-`
    
    local dev_path=/sys/devices/`uci get wireless.${r}.path`

    if [ -e "${dev_path}/../idVendor" -a -e "${dev_path}/../idProduct" ]; then
        idVendor=`cat ${dev_path}/../idVendor`
        idProduct=`cat ${dev_path}/../idProduct`

        # onboard wifi
        # t4: 0x02d0:0x4356
        # r2: 0x02d0:0xa9bf
        if [ "x${idVendor}:${idProduct}" = "x0x02d0:0x4356" ] \
                || [ "x${idVendor}:${idProduct}" = "x0x02d0:0xa9bf" ]; then
                uci set wireless.${r}.hwmode='11a'
                uci set wireless.${r}.channel='149'
                uci set wireless.${r}.country = '00'
        fi
    fi

    uci set wireless.${r}.disabled=0
    # uci set wireless.${r}.country=CN
    
    uci set wireless.default_${r}.ssid=CheeseWRT-${wifimac}
    uci set wireless.default_${r}.encryption=none
	# uci set wireless.default_${r}.channel=149
	# uci set wireless.default_${r}.key=goodlife
    uci commit
}

TAG=CheeseWRT
logger "${TAG}: /root/setup.sh running"

uci set system.@system[0].hostname='CheeseWRT'
uci commit

# update /etc/config/network
# WAN_IF=`uci get network.wan.ifname`
# if [ "x${WAN_IF}" = "xeth0" ]; then
#   uci set network.wan.dns=8.8.8.8
#   uci commit
# fi

WIFI_NUM=`find /sys/class/net/ -name wlan* | wc -l`
if [ ${WIFI_NUM} -gt 0 ]; then

    # make sure lan interface exist
    if [ -z "`uci get network.lan`" ]; then
        uci batch <<EOF
set network.lan='interface'
set network.lan.type='bridge'
set network.lan.proto='static'
set network.lan.ipaddr='192.168.8.1'
set network.lan.netmask='255.255.255.0'
set network.lan.ip6assign='60'
EOF
    fi

    # update /etc/config/wireless
    for i in `seq 0 ${WIFI_NUM}`; do
        setup_ssid radio${i}
    done
    NEED_RESTART_SERVICE=1
fi

uci set network.lan.ipaddr='192.168.8.1'
uci set mwan3.wan.enabled='0'
uci set flowoffload.@flow[0].bbr='1'
uci commit
# R1S H5
# opkg install /root/wget-r1sh5.ipk

/etc/init.d/led restart
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/flowoffload restart
/etc/init.d/mwan3 restart
/etc/init.d/system restart

logger "{TAG}: done"

# rc.local
rm /etc/rc.local
mv /root/rc.local.ori /etc/rc.local

# R1S H5
# rm /root/wget-r1sh5.ipk
rm /root/setup.sh
