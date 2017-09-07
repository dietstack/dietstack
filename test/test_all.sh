#!/bin/bash
# Script will prepare and test virtual ansible-deployment environment
# Sen script is necessary to be installed in user home directory
set -e

./1_vms_preparation.sh
./2_install_localstack.sh
