#!/bin/bash

set -e

sudo ./ds.sh

docker run --rm --net=host \
           -v ~/.ssh:/root/.ssh \
           -it osadmin bash -c ". /app/adminrc; openstack user list"

docker run --rm --net=host \
           -v ~/.ssh:/root/.ssh \
           -it osadmin bash -c ". /app/adminrc; openstack service list"

sudo ./destroy-ds.sh
