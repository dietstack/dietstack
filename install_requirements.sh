#!/bin/bash

KERNEL_PKG=""
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [[ $(lsb_release -cs) == "jessie" || $(lsb_release -cs) == "xenial" ]]; then
    apt-get install --no-install-recommends -y curl git bridge-utils libvirt-bin qemu-kvm

    if [[ $(lsb_release -cs) == "jessie" ]]; then
        DISTRO=debian
    elif [[ $(lsb_release -cs) == "xenial" ]]; then
        DISTRO=ubuntu
    fi
    docker >/dev/null 2>&1
    if [[ $? != 0  ]]; then
        echo "Docker is not installed. Let's install it ..."
        apt install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common

        curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | apt-key add -

        add-apt-repository \
            "deb [arch=amd64] http://download.docker.com/linux/$DISTRO \
            $(lsb_release -cs) \
            stable"

        apt update && apt -y install docker-ce

        echo "Configure docker to use /etc/environment file -> http_proxy ..."
        if [[ ! -d /etc/systemd/system/docker.service.d ]]; then
            mkdir -p /etc/systemd/system/docker.service.d
            cat <<EOF > /etc/systemd/system/docker.service.d/environment.conf
[Service]
EnvironmentFile=/etc/environment
EOF

            systemctl daemon-reload && systemctl restart docker.service
        fi
    fi
fi
