#!/bin/bash
# Installs software needed by DietStack on host
# Currently supports Debian 8,9 and Ubuntu 16.04 (xenial)

KERNEL_PKG=""
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
DVERSION=$(lsb_release -cs | tr '[:upper:]' '[:lower:]')

if [[ $DVERSION == "jessie" || $DVERSION == "stretch" || $DVERSION == "xenial" ]]; then
    LIBVIRT_PKG=libvirt-bin
    if  [[ $DVERSION == "stretch" ]]; then
        LIBVIRT_PKG="libvirt-daemon libvirt-daemon-system libvirt-clients"
    fi
    apt-get update
    apt-get install --no-install-recommends -y curl git bridge-utils qemu-kvm $LIBVIRT_PKG

    docker >/dev/null 2>&1
    if [[ $? != 0  ]]; then
        echo "Docker is not installed. Let's install it ..."
        apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                software-properties-common

        curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | apt-key add -

        add-apt-repository \
            "deb [arch=amd64] http://download.docker.com/linux/$DISTRO \
            $(lsb_release -cs) \
            stable"


        echo "Configure docker to use /etc/environment file -> http_proxy ..."
        if [[ ! -d /etc/systemd/system/docker.service.d ]]; then
            mkdir -p /etc/systemd/system/docker.service.d
            cat <<EOF > /etc/systemd/system/docker.service.d/environment.conf
[Service]
EnvironmentFile=/etc/environment
EOF
            mkdir -p /etc/docker    
            cat <<EOF > /etc/docker/daemon.json
{
    "iptables": false
}
EOF
            apt-get update && apt-get -y install docker-ce
            systemctl daemon-reload && systemctl restart docker.service
        fi
    fi
fi

