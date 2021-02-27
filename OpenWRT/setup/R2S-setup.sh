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
                uci set wireless.${r}.country = 'CN'
        fi
    fi

    uci set wireless.${r}.disabled=0
    uci set wireless.${r}.country=CN
    
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

sed -i '1c root:$1$gmSsnVXV$Zki\/jua1bXJvnjLS9U3MQ.:16821:0:99999:7:::' /etc/shadow

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
uci set network.wan.ifname='eth0'
uci set network.wan6.ifname='eth0'
uci set network.lan.ifname='eth1 eth2'
uci set mwan3.wan.enabled='1'
uci set flowoffload.@flow[0].bbr='1'
uci set dhcp.lan.force='1'
uci delete dhcp.lan.dhcpv6
uci delete dhcp.lan.ra
uci set network.lan.delegate='0'

# LED
uci set system.led_wan.mode='link'
uci set system.led_wan.dev='eth0'
uci set system.led_lan.mode='link'
uci set system.led_lan.dev='eth1'

# CPU Performance
uci set cpufreq.cpufreq.maxfreq='1512000'
uci set cpufreq.cpufreq.governor='performance'

uci commit

/etc/init.d/led restart
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/flowoffload restart
/etc/init.d/mwan3 restart
/etc/init.d/system restart

# FAN control function
ln -s /etc/init.d/fa-rk3328-pwmfan /etc/rc.d/S96fa-rk3328-pwmfan
/etc/init.d/fa-rk3328-pwmfan start

logger "{TAG}: done"

# rc.local
rm /etc/rc.local
mv /etc/rc.local.ori /etc/rc.local

rm /root/setup.sh
