# Configuration settings which are sourced in other test scripts
set -e

readonly MYHOME=$(dirname $(readlink -e $0) )
CONTROL_IP=192.168.12.2
COMPUTE_IP=192.168.12.3

SEN_ENV=lst
SEN_DIR=~/sen
SSH_AUTO_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
CONTROL_CMD="ssh ${SSH_AUTO_OPT} root@${CONTROL_IP}"
COMPUTE_CMD="ssh ${SSH_AUTO_OPT} root@${COMPUTE_IP}"
gitlab=172.27.10.10

