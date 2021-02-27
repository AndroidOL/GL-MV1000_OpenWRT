#!/bin/sh

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
    uci set wireless.${r}.disabled=0
    uci set wireless.${r}.country=CN
    # uci set wireless.${r}.channel=149
    uci set wireless.default_${r}.ssid=CheeseWRT-${wifimac}
    uci set wireless.default_${r}.encryption='psk2'
    uci set wireless.default_${r}.key='goodlife'
    uci commit
}

TAG=CheeseWRT
logger "${TAG}: /root/setup.sh running"

uci set system.@system[0].hostname='CheeseWRT'
uci commit

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
fi

uci set network.lan.ipaddr='192.168.8.1'
uci commit

uci set network.trm_wwan=interface
uci set network.trm_wwan.proto='dhcp'
uci set network.trm_wwan._orig_ifname='wlan0-1'
uci set network.trm_wwan._orig_bridge='false'

uci set firewall.@zone[1].network='wan wan6 trm_wwan'

uci set travelmate.global.trm_enabled='1'
uci set travelmate.global.trm_iface='trm_wwan'
uci commit

/etc/init.d/led restart
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/system restart
/etc/init.d/firewall restart
/etc/init.d/travelmate restart

logger "{TAG}: done"

# rc.local
rm /etc/rc.local
mv /etc/rc.local.ori /etc/rc.local
rm /root/setup.sh
