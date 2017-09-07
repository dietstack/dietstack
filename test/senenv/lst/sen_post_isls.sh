#!/bin/bash
# Hook script to setup networking for ref environment VMs

LOCAL_SUBNET=192.168.12
ACCESS_INT=adm

ip addr add $LOCAL_SUBNET.1/24 dev $ENAME.$ACCESS_INT &>/dev/null
ip link set dev $ENAME.$ACCESS_INT up

iptables -L -t nat | grep $LOCAL_SUBNET.0 | grep MASQUERADE >& /dev/null

if [[ $? -eq 1 ]]; then
	iptables -t nat -A POSTROUTING -p all -s $LOCAL_SUBNET.0/24 ! -d $LOCAL_SUBNET.0/24 -j MASQUERADE -m comment --comment "SEN $ENAME environment"
fi


