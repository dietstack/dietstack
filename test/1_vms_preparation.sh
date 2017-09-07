#!/bin/bash
. 0_settings.sh

###################
#Preparation of VMs
###################

# install sen to home dir if it is not installed (usable especially on ci runner)
if [[ ! -d "${SEN_DIR}" ]]; then
    git clone https://${gitlab}/gitlab/openstack/sen.git "${SEN_DIR}/"
else
    pushd "${SEN_DIR}" && git pull; popd
fi

# modify http_proxy on VMs in post_install script if local http_proxy is set and not equal to 127.0.0.1
# Testing 127.0.0.1 and localhost is added because I use local squid on my computer and these settings
# are not valid in sen VMs
if [[ ! $http_proxy =~ "127.0.0.1" && ! $http_proxy =~ "localhost" && ! -z $http_proxy ]]; then
    sed -i "/HTTP_PROXY=/ cHTTP_PROXY=\"http_proxy=$http_proxy\"" ${MYHOME}/senenv/${SEN_ENV}/post_install.sh
    sed -i "/HTTPS_PROXY=/ cHTTPS_PROXY=\"https_proxy=$http_proxy\"" ${MYHOME}/senenv/${SEN_ENV}/post_install.sh
    sed -i "/NO_PROXY=/ cNO_PROXY=\"no_proxy=$no_proxy\"" ${MYHOME}/senenv/${SEN_ENV}/post_install.sh
fi

pushd ~/sen
${SEN_DIR}/sen -e ${MYHOME}/senenv -d ${SEN_ENV}
${SEN_DIR}/sen -e ${MYHOME}/senenv -y ${SEN_ENV}
popd
