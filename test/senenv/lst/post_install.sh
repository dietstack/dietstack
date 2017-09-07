#!/bin/sh

# Customized post_install.h for sen

logger "Running post_install.sh"

HTTP_PROXY="http_proxy=http://172.27.10.114:3128"
HTTPS_PROXY="https_proxy=http://172.27.10.114:3128"
NO_PROXY="no_proxy=localhost,127.0.0.1,172.28.1.10,172.27.10.10,10.233.130.190,.t-systems.sk,172.27.8.1,.sen,172.27.19.1,172.27.9.130,gitlab,localhost,127.0.0.1,fore-master.domain,192.168.0.0/16,10.233.130.190,10.233.97.166,.t-systems.sk,172.27.0.0/16,172.28.0.0/16,.telekom.de"

HTTP_PROXY_OK="`grep $HTTP_PROXY /etc/environment`"

if [ -z $HTTP_PROXY_OK ]; then
  echo "$HTTP_PROXY" >> /etc/environment
fi

HTTPS_PROXY_OK="`grep $HTTPS_PROXY /etc/environment`"

if [ -z $HTTPS_PROXY_OK ]; then
  echo "$HTTPS_PROXY" >> /etc/environment
fi

NO_PROXY_OK="`grep $NO_PROXY /etc/environment`"

if [ -z $NO_PROXY_OK ]; then
  echo "$NO_PROXY" >> /etc/environment
fi

SSHDNS="UseDNS no"
USEDNS_OK="`grep "$SSHDNS" /etc/ssh/sshd_config`"

if [ -z $USEDNS_OK ]; then
  echo "$SSHDNS" >> /etc/ssh/sshd_config
fi

#sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="net.ifnames=1"' /etc/default/grub
#update-grub2

# setup br-ex network configuration for control node
HNAME=`cat /etc/hostname`
EXP_HNAME='control'
if [ "${HNAME#*$EXP_HNAME}" != "$HNAME" ]; then
    mv /etc/network/interfaces /etc/network/interfaces.orig
    FIRST_INT=ens3
    grep Debian /etc/issue | grep -q 8 && FIRST_INT=eth0
    cp /opt/copy_in/interfaces-$FIRST_INT /etc/network/interfaces
fi

OCTET=$(grep address /etc/network/interfaces | head -n 1 | awk '{ print $2}' | cut -d'.' -f 4)

OS_INT=ens4
grep Debian /etc/issue | grep -q 8 && OS_INT=eth1

# Configure openstack network interface
cat >>/etc/network/interfaces <<EOF
auto $OS_INT
iface $OS_INT inet static
address 192.168.0.$OCTET
netmask 255.255.255.0
EOF

