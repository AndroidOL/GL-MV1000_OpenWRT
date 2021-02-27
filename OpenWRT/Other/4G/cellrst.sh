#!/bin/sh
# 自动检查线路是否正常，5次ping不正常就使用AT命令重置模块
# 脚本时间:2019-08-06

PING=`ping -c 5 223.5.5.5|grep -v grep|grep '64 bytes' |wc -l`

if [ ${PING} -ne 0 ];then
	exit 0
else
#	/etc/init.d/network restart
  echo -e "AT+CFUN=1,1\r\n" >/dev/ttyUSB2
fi
exit 1
