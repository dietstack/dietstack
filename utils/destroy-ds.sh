#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "$0 must be run as root"
   exit 1
fi

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e -n "\e[91m"
read -p "!!! This will destroy your DietStack cloud. Do you want to continue? " -n 1 -r
echo -e "\e[0m"                                                                                       
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

NAME_SUFFIX='ds'

echo "Stopping and removing DietStack containers ..."

docker stop sqldb.${NAME_SUFFIX} > /dev/null 2>&1
docker stop memcached.${NAME_SUFFIX} > /dev/null 2>&1
docker stop rabbitmq.${NAME_SUFFIX} > /dev/null 2>&1
docker stop keystone.${NAME_SUFFIX} > /dev/null 2>&1
docker stop glance.${NAME_SUFFIX} > /dev/null 2>&1
docker stop nova-controller.${NAME_SUFFIX} > /dev/null 2>&1
docker stop nova-compute.${NAME_SUFFIX} > /dev/null 2>&1
docker stop neutron-controller.${NAME_SUFFIX} > /dev/null 2>&1
docker stop neutron-agent.${NAME_SUFFIX} > /dev/null 2>&1
docker stop cinder.${NAME_SUFFIX} > /dev/null 2>&1
docker stop heat.${NAME_SUFFIX} > /dev/null 2>&1
docker stop horizon.${NAME_SUFFIX} > /dev/null 2>&1
docker stop magnum.${NAME_SUFFIX} > /dev/null 2>&1
docker stop nfs.${NAME_SUFFIX} > /dev/null 2>&1
docker stop discovery.${NAME_SUFFIX} > /dev/null 2>&1

docker rm sqldb.${NAME_SUFFIX} > /dev/null 2>&1
docker rm memcached.${NAME_SUFFIX} > /dev/null 2>&1
docker rm rabbitmq.${NAME_SUFFIX} > /dev/null 2>&1
docker rm keystone.${NAME_SUFFIX} > /dev/null 2>&1
docker rm glance.${NAME_SUFFIX} > /dev/null 2>&1
docker rm nova-controller.${NAME_SUFFIX} > /dev/null 2>&1
docker rm nova-compute.${NAME_SUFFIX} > /dev/null 2>&1
docker rm neutron-controller.${NAME_SUFFIX} > /dev/null 2>&1
docker rm neutron-agent.${NAME_SUFFIX} > /dev/null 2>&1
docker rm cinder.${NAME_SUFFIX} > /dev/null 2>&1
docker rm heat.${NAME_SUFFIX} > /dev/null 2>&1
docker rm magnum.${NAME_SUFFIX} > /dev/null 2>&1
docker rm horizon.${NAME_SUFFIX} > /dev/null 2>&1
docker rm nfs.${NAME_SUFFIX} > /dev/null 2>&1
docker rm discovery.${NAME_SUFFIX} > /dev/null 2>&1

# network/vms cleanup
$ABSOLUTE_PATH/clean-ds.sh

# database data deletion
echo "Deleting SQL data ..."
rm -rf /srv/dietstack/sql
echo "Done"
