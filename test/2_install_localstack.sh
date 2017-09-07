#!/bin/bash
. 0_settings.sh

###################
#Preparation of VMs
###################

# distribute current docker-localstack project
scp ${SSH_AUTO_OPT} -r ${MYHOME}/../../docker-localstack root@${CONTROL_IP}:/root/
scp ${SSH_AUTO_OPT} -r ${MYHOME}/../../docker-localstack root@${COMPUTE_IP}:/root/

# install control node
${CONTROL_CMD} bash -c "/root/docker-localstack/install_requirements.sh"
${CONTROL_CMD} "EXTERNAL_IP=192.168.12.2/24 OVERLAY_INTERFACE=eth1 bash -x /root/docker-localstack/run-os.sh"
${CONTROL_CMD} 'docker run --rm --net=host osadmin bash -c "FLOATING_IP_SUBNET=192.168.12.0/24 EXTERNAL_IP=192.168.12.2 /app/first_vm.sh"'

# install compute1
${COMPUTE_CMD} bash -c "/root/docker-localstack/install_requirements.sh"
${COMPUTE_CMD} "CONTROL_NODE=false OVERLAY_INTERFACE=eth1  EXTERNAL_BRIDGE= EXTERNAL_INTERFACE= CONTROL_NODE_IP=192.168.0.2 bash -x /root/docker-localstack/run-os.sh"

