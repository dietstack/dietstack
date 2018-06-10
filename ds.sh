#!/bin/bash

set -e

log_info() {
    local msg=$1
    echo -e "\e[33m[ $msg ]\e[0m"
}

log_error() {
    local msg=$1
    echo -e "\e[91m$msg\e[0m"
}


print_help() {
cat <<-END
Usage:
------
   -h | --help
     Display this help

Behaviour of script is driven by environment variables. Here are most important ones:

CONTROL_NODE (true/false) - If true, control node containers will be executed. There could be only one control node. True is default.
COMPUTE_NODE (true/false) - If true, comptue node containers will be executed. Compute node containers can be run also on control node. True is default.
DS_INTERFACE - interface name where dietstack service will use for communication. lo is default.
EXTERNAL_IP - external ip address in format ip.add.re.ss/netmask. Default is 192.168.99.1/24. Mandatory on control node.

CONTROL_NODE_DS_IP - IP address of control node in DS network. Mandatory on compute node.

Full documentation: https://readthedocs.org/projects/dietstack/

Example of deployment:
======================

Control node:
  EXTERNAL_IP='192.168.99.2/24' DS_INTERFACE=eth2 /root/dietstack/ds.sh

Compute node:
   CONTROL_NODE=false DS_INTERFACE=eth2 CONTROL_NODE_DS_IP=192.168.23.2 EXTERNAL_IP='192.168.99.2/24' /root/dietstack/ds.sh
END
}

while getopts h option
do
 case "${option}" in
   h) print_help
      exit;;
 esac
done

if [[ $EUID -ne 0 ]]; then
   log_error "Diestack must be run as root!"
   exit 1
fi

readonly MYHOME=$(dirname $(readlink -e $0) )

. ${MYHOME}/lib/functions.sh

NAME_SUFFIX=ds
DS_DIR=/srv/dietstack
LOG_DIR=$DS_DIR/log
CONF_FILE=$DS_DIR/settings.sh

if [[ -f $CONF_FILE ]]; then
    log_info "Loading configuration file $CONF_FILE ..."
    . $CONF_FILE
fi

# DOCKER_PROJ_NAME needs to be set due to create_db_osadmin lib function
export DOCKER_PROJ_NAME=dietstack/

# load containers version
# VERSIONS Format: Serial number
VERSIONS=${VERSIONS-2}
if [[ -z ${VERSIONS} ]]; then
    log_info "Using latest versions!"
    SQLDB_VER=${SQLDB_VER:-latest}
    RABBITMQ_VER=${RABBITMQ_VER:-latest}
    KEYSTONE_VER=${KEYSTONE_VER:-latest}
    NOVA_VER=${NOVA_VER:-latest}
    GLANCE_VER=${GLANCE_VER:-latest}
    NEUTRON_VER=${NEUTRON_VER:-latest}
    CINDER_VER=${CINDER_VER:-latest}
    HEAT_VER=${HEAT_VER:-latest}
    HORIZON_VER=${HORIZON_VER:-latest}
    OSADMIN_VER=${OSADMIN_VER:-latest}
else
    if [[ ! -f ${MYHOME}/versions/${VERSIONS} ]]; then
        log_error "Version file versions/${VERSIONS} not found!"
        exit 1
    fi
    . ${MYHOME}/versions/${VERSIONS}
fi

# what to install (at least one needs to be set to true. Both set to false will cause that no container will run)
CONTROL_NODE=${CONTROL_NODE:-true}
COMPUTE_NODE=${COMPUTE_NODE:-true}
CONTROL_NODE_DS_IP=${CONTROL_NODE_DS_IP:-""}

# if we are installing compute node, we need to set CONTROL_NODE_DS_IP
if [[ $CONTROL_NODE != true && $COMPUTE_NODE == true && $CONTROL_NODE_DS_IP == "" ]]; then
    log_error "IP of control node missing (please set variable $CONTROL_NODE_DS_IP)!"
    exit 1
fi

# if restart is true and containers are stopped just start the container instead of new run
RESTART=${RESTART:-true}
PASSWORDS=${PASSWORDS:-veryS3cr3t}
RABBITMQ_USER=openstack
BRANCH=${BRANCH:-master}
HORIZON_PORT=${HORIZON_PORT:-8082}
EXTERNAL_BRIDGE=${EXTERNAL_BRIDGE-'br-ex'} # br-ex will be default only if variable is unset.
                                           # If set to "" it will stay set to "" and no external network
                                           # will be configured. It is important on compute node because we need
                                           # to tell the script that we are not going to use EXTERNAL_BRIDGE.
EXTERNAL_INTERFACE=${EXTERNAL_INTERFACE:-'eth0'} # if EXTERNAL_BRIDGE is set, this var is not used
                                                 # so to use it set EXTERNAL_BRIDGE='' (Compute node)
EXTERNAL_IP=${EXTERNAL_IP:-192.168.99.1/24} # doesn't need to be set. If it is empty, EXTERNAL_BRIDGE
                                            # floating IPs won't be reacheable from localhost.
                                            # On Compute node needs to be set even EXTERNAL_INTERFACE is set to ''.
                                            # otherwise spice console in horizon wont work.
DS_INTERFACE=${DS_INTERFACE:-lo}            # Interface for vxlans, storage, apis, infra services

DS_INTERFACE_IP=$(ip addr | grep inet | grep -w $DS_INTERFACE | awk -F" " '{print $2}'| sed -e 's/\/.*$//')

cleanup() {
    local CONTROL=$1
    local COMPUTE=$2
    echo "Clean up ..."
    if [[ $CONTROL == true ]]; then
        docker stop sqldb.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop memcached.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop rabbitmq.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop keystone.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop glance.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop nova-controller.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop neutron-controller.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop cinder.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop heat.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop horizon.${NAME_SUFFIX} > /dev/null 2>&1 || true

        docker rm sqldb.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm memcached.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm rabbitmq.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm keystone.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm glance.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm nova-controller.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm neutron-controller.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm cinder.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm heat.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm horizon.${NAME_SUFFIX} > /dev/null 2>&1 || true
    fi
    if [[ $COMPUTE == true ]]; then
        docker stop nova-compute.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker stop neutron-agent.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm nova-compute.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm neutron-agent.${NAME_SUFFIX} > /dev/null 2>&1 || true
    fi
}

if [[ "$INSTALL_REQS" != "false" ]]; then
    export DEBIAN_FRONTEND=noninteractive

    log_info "Install requirements ..."
    . ${MYHOME}/utils/install-reqs-ds.sh
    set +e
    requirements
    reqs=$?
    if [[ $reqs != 0 ]]; then
       log_error "Unsupported OS version!"
       exit 1
    fi
    set -e
fi

log_info "Starting DietStack version $VERSIONS ..."

##### clean existing containers
if [[ "$RESTART" != "true" ]]; then
    cleanup $CONTROL_NODE $COMPUTE_NODE
fi

if [[ $CONTROL_NODE == true ]]; then
#    log_info "Pulling osadmin container..."
#    docker pull ${OSADMIN_VER}

    # Configure host network
    log_info "Configure External Networking ..."
    ip a s | grep -q $EXTERNAL_BRIDGE || { brctl addbr $EXTERNAL_BRIDGE && ip link set dev $EXTERNAL_BRIDGE up; }
    if [[ ! -z $EXTERNAL_IP ]]; then
        EXTERNAL_NET=$(docker run --rm -e EXTERNAL_IP="$EXTERNAL_IP" ${OSADMIN_VER} \
                       python -c 'import os,ipaddress; print(str(ipaddress.IPv4Interface(os.environ["EXTERNAL_IP"]).network))' | tail -n 1)
        if [[ ! `ip addr | awk '/inet/ && /'"$EXTERNAL_BRIDGE"'/{print $2}' | grep "$EXTERNAL_IP"` ]]; then
            ip addr add $EXTERNAL_IP dev $EXTERNAL_BRIDGE
            if [[ ! `ip r | grep -w "$EXTERNAL_NET"` ]]; then
                ip route add $EXTERNAL_NET dev $EXTERNAL_BRIDGE
            fi
        fi
        # Docker from version 1.13 started to set FORWARD chain policy to DROP for security reasons,
        # so we need to add rule which allows us access  of floating IPs from outside of host
        # More: https://github.com/docker/docker/issues/14041
        if [[ ! `iptables -L FORWARD -n | grep ACCEPT | grep $EXTERNAL_NET` ]]; then
            iptables -A FORWARD -p all -d $EXTERNAL_NET -j ACCEPT -m comment --comment "DietStack"
            iptables -A FORWARD -p all -s $EXTERNAL_NET -j ACCEPT -m comment --comment "DietStack"
        fi

        JUST_EXTERNAL_IP=$(echo $EXTERNAL_IP | cut -d"/" -f 1)
    else
        JUST_EXTERNAL_IP=127.0.0.1
    fi

    ##### Controller Containers

    log_info "Starting NFS container for cinder ..."
    mkdir -p ${DS_DIR}/cindervols
    if [[ `docker ps -a | grep -w nfs.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start nfs.${NAME_SUFFIX}
    else
        docker run --net=host -d --privileged --name nfs.${NAME_SUFFIX} \
                   --restart unless-stopped \
                   -v ${DS_DIR}/cindervols:/cindervols \
                   -e SHARED_DIRECTORY=/cindervols \
                   ${NFS_VER}
    fi

    log_info "Starting sqldb container ..."
    mkdir -p ${DS_DIR}/sql
    if [[ `docker ps -a | grep -w sqldb.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start sqldb.${NAME_SUFFIX}
    else
        docker run -d --net=host -e MYSQL_ROOT_PASSWORD=$PASSWORDS \
                   -v ${DS_DIR}/sql:/var/lib/mysql \
                   --name sqldb.${NAME_SUFFIX} ${SQLDB_VER} --max-connections=300
    fi

    echo "Wait till sqldb is running ."
    wait_for_port 3306 120

    log_info "Starting Memcached node (tokens caching) ..."
    if [[ `docker ps -a | grep -w memcached.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start memcached.${NAME_SUFFIX}
    else
        docker run -d --net=host -e DEBUG= --name memcached.${NAME_SUFFIX} \
                   --restart unless-stopped \
                   memcached
    fi

    log_info "Starting RabbitMQ container ..."
    if [[ `docker ps -a | grep -w rabbitmq.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start rabbitmq.${NAME_SUFFIX}
    else
        docker run -d --net=host -e DEBUG= --name rabbitmq.${NAME_SUFFIX} \
                   --restart unless-stopped \
                   ${RABBITMQ_VER}
    fi

    wait_for_port 5672 120

    # create openstack user in rabbitmq
    if [[ ! `docker exec rabbitmq.${NAME_SUFFIX} rabbitmqctl list_users | grep openstack` ]]; then
        docker exec rabbitmq.${NAME_SUFFIX} rabbitmqctl add_user $RABBITMQ_USER $PASSWORDS
        docker exec rabbitmq.${NAME_SUFFIX} rabbitmqctl set_permissions $RABBITMQ_USER '.*' '.*' '.*'
    fi

    log_info "Starting keystone container ..."
    if [[ `docker ps -a | grep -w keystone.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start keystone.${NAME_SUFFIX}
    else
        create_db_osadmin keystone keystone $PASSWORDS $PASSWORDS
        docker run -d --net=host \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -v $LOG_DIR/keystone:/var/log/supervisord \
                   --name keystone.${NAME_SUFFIX} ${KEYSTONE_VER}
    fi

    echo "Wait till keystone is running ."

    wait_for_port 5000 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 5000 (Keystone) not bounded!"
        exit $ret
    fi

    wait_for_port 35357 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 35357 (Keystone Admin) not bounded!"
        exit $ret
    fi

    log_info "Starting glance container ..."
    if [[ `docker ps -a | grep -w glance.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start glance.${NAME_SUFFIX}
    else
        create_db_osadmin glance glance $PASSWORDS $PASSWORDS
        mkdir -p ${DS_DIR}/glance-images-osadmin
        docker run -d --net=host \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e LOAD_META="true" \
                   -v $LOG_DIR/glance:/var/log/supervisord \
                   --name glance.${NAME_SUFFIX} ${GLANCE_VER}
    fi

    wait_for_port 9191 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 9191 (Glance Registry) not bounded!"
        exit $ret
    fi

    wait_for_port 9292 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 9292 (Glance API) not bounded!"
        exit $ret
    fi

    log_info "Starting nova-controller container ..."
    if [[ `docker ps -a | grep -w nova-controller.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start nova-controller.${NAME_SUFFIX}
    else
        create_db_osadmin nova nova $PASSWORDS $PASSWORDS
        create_db_osadmin nova_api nova $PASSWORDS $PASSWORDS || true
        create_db_osadmin nova_cell0 nova $PASSWORDS $PASSWORDS || true

        docker run -d --net=host --privileged \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e NOVA_CONTROLLER="true" \
                   -e SPICE_HOST="$JUST_EXTERNAL_IP" \
                   -v $LOG_DIR/nova-controller:/var/log/supervisord \
                   --name nova-controller.${NAME_SUFFIX} \
                   ${NOVA_VER}
    fi

    wait_for_port 8774 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8774 (Nova-Api) not bounded!"
        exit $ret
    fi

    wait_for_port 8775 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8775 (Metadata) not bounded!"
        exit $ret
    fi

    wait_for_port 6082 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 6082 (spice html5proxy) not bounded!"
        exit $ret
    fi

    log_info "Starting neutron-controller container ..."
    if [[ `docker ps -a | grep -w neutron-controller.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start neutron-controller.${NAME_SUFFIX}
    else
        create_db_osadmin neutron neutron $PASSWORDS $PASSWORDS
        docker run -d --net=host --privileged \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e NEUTRON_CONTROLLER="true" \
                   -e EXTERNAL_BRIDGE="$EXTERNAL_BRIDGE" \
                   -e EXTERNAL_IP="$EXTERNAL_IP" \
                   -e OVERLAY_INTERFACE=${DS_INTERFACE} \
                   -v /run/netns:/run/netns:shared \
                   -v /lib/modules:/lib/modules \
                   -v $LOG_DIR/neutron-controller:/var/log/supervisord \
                   --name neutron-controller.${NAME_SUFFIX} \
                   ${NEUTRON_VER}
    fi

    wait_for_port 9696 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 9696 (neutron server) not bounded!"
        exit $ret
    fi

    log_info "Starting cinder container ..."
    if [[ `docker ps -a | grep -w cinder.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start cinder.${NAME_SUFFIX}
    else
        create_db_osadmin cinder cinder $PASSWORDS $PASSWORDS
        docker run -d --net=host --privileged \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e NAS_HOST=$DS_INTERFACE_IP \
                   -v $LOG_DIR/cinder:/var/log/supervisord \
                   --name cinder.${NAME_SUFFIX} \
                   ${CINDER_VER}
    fi

    wait_for_port 8776 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8776 (cinder services) not bounded!"
        exit $ret
    fi


    log_info "Starting heat container ..."
    if [[ `docker ps -a | grep -w heat.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start heat.${NAME_SUFFIX}
    else
        create_db_osadmin heat heat $PASSWORDS $PASSWORDS
        docker run -d --net=host \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -v $LOG_DIR/heat:/var/log/supervisord \
                   --name heat.${NAME_SUFFIX} \
                   ${HEAT_VER}
    fi

    wait_for_port 8004 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8004 (Heat API) not bounded!"
        exit $ret
    fi

   if [[ $DS_EXPERIMENTAL == true ]]; then
       log_info "Starting magnum container ..."
        if [[ `docker ps -a | grep -w magnum.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
            docker start magnum.${NAME_SUFFIX}
        else
            create_db_osadmin magnum magnum $PASSWORDS $PASSWORDS
            docker run -d --net=host \
                       --restart unless-stopped \
                       -e DEBUG="true" \
                       -e DB_SYNC="true" \
                       -e KEYSTONE_HOST="$JUST_EXTERNAL_IP" \
                       -v $LOG_DIR/magnum:/var/log/supervisord \
                       --name magnum.${NAME_SUFFIX} \
                       ${MAGNUM_VER}
        fi
    fi

    wait_for_port 8004 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8004 (magnum) not bounded!"
        exit $ret
    fi


    log_info "Starting horizon container ..."
    if [[ `docker ps -a | grep -w horizon.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start horizon.${NAME_SUFFIX}
    else
        docker run -d --net=host \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e HORIZON_HTTP_PORT="$HORIZON_PORT" \
                   -e JUST_EXTERNAL_IP="$JUST_EXTERNAL_IP" \
                   -v $LOG_DIR/horizon:/var/log/supervisord \
                   -v $LOG_DIR/horizon/nginx:/var/log/nginx/horizon \
                   --name horizon.${NAME_SUFFIX} \
                   ${HORIZON_VER}
    fi

    wait_for_port $HORIZON_PORT 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port $HORIZON_PORT (Horizon) not bounded!"
        exit $ret
    fi

    log_info "Starting discovery container ..."
    if [[ `docker ps -a | grep -w discovery.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start discovery.${NAME_SUFFIX}
    else
        docker run -d --net=host -e DS_INTERFACE=${DS_INTERFACE} --name=discovery.ds dietstack/osadmin:latest  \
                    bash -c "socat UDP4-RECVFROM:62699,broadcast,fork EXEC:'python -c \"import os,netifaces; print(netifaces.ifaddresses(os.environ['DS_INTERFACE']))[netifaces.AF_INET][0]['addr']\"'"
    fi

   wait_for_port 62699 360

    log_info "Bootstrapping keystone ..."
    # bootstrap openstack settings and upload image to glance
    set +e
    docker run --rm --net=host --name keystone-bootstrap.${NAME_SUFFIX} ${KEYSTONE_VER} \
            bash -c "keystone-manage bootstrap \
                     --bootstrap-password $PASSWORDS \
                     --bootstrap-username admin \
                     --bootstrap-project-name admin \
                     --bootstrap-role-name admin \
                     --bootstrap-service-name keystone \
                     --bootstrap-region-id RegionOne \
                     --bootstrap-admin-url http://$JUST_EXTERNAL_IP:35357 \
                     --bootstrap-public-url http://$JUST_EXTERNAL_IP:5000 \
                     --bootstrap-internal-url http://$JUST_EXTERNAL_IP:5000"

    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Keystone bootstrap error ${ret}!"
        exit $ret
    fi

    docker run --rm --net=host ${OSADMIN_VER} /bin/bash -c ". /app/adminrc; \
                                              ADMIN_IP="$JUST_EXTERNAL_IP" \
                                              INTERNAL_IP="$JUST_EXTERNAL_IP" \
                                              PUBLIC_IP="$JUST_EXTERNAL_IP" \
                                              PASSWORD="$PASSWORDS" \
                                              bash -x /app/bootstrap.sh"
    ret=$?
    if [ $ret -ne 0 ] && [ $ret -ne 128 ]; then
        echo "Error: Services/Endpoints bootstrap error ${ret}!"
        exit $ret
    fi
    set -e

fi

##### Compute containers

if [[ $COMPUTE_NODE == true ]]; then
    log_info "Searching for public IP..."
    # sed will extract ip/hostname from string "http://192.168.99.2:5000" so we get 192.168.99.2
    set -o pipefail
    JUST_EXTERNAL_IP=$(docker run --rm --net=host \
                       -e RC_ADMIN_PASSWORD="$PASSWORDS" \
                       -e RC_ADMIN_OS_AUTH_URL="http://${CONTROL_NODE_DS_IP}:5000/v3" \
                       ${OSADMIN_VER} /bin/bash -e -o pipefail -c ". /app/adminrc; openstack endpoint list \
                       --format csv | grep -E 'identity.*public' | cut -d',' -f 7 | \
                       sed -rn 's_.*\/\/(.*)\:.*_\1_p'" | tail -n 1)
    set +o pipefail

    log_info "Starting nova-compute container ..."
    if [[ `docker ps -a | grep -w nova-compute.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start nova-compute.${NAME_SUFFIX}
    else
        # thanks to clayton.oneil@charter.com
        # source: https://www.openstack.org/videos/video/dockerizing-the-hard-services-neutron-and-nova
        # mounting of cinder volumes done by nova-compute inside container needs to be visible
        # for libvirt running outside container
        mkdir -p /var/lib/nova/mnt
        mount --bind /var/lib/nova/mnt /var/lib/nova/mnt
        mount --make-shared /var/lib/nova/mnt

        docker run -d --net=host  --privileged \
                   --restart unless-stopped \
                   -e DEBUG="true" \
                   -e NOVA_CONTROLLER="false" \
                   -e SPICE_HOST=${JUST_EXTERNAL_IP} \
                   -e SPICE_PROXY_HOST=${DS_INTERFACE_IP} \
                   -e DB_HOST=${CONTROL_NODE_DS_IP} \
                   -e KEYSTONE_HOST=${CONTROL_NODE_DS_IP} \
                   -e MEMCACHED_SERVERS=${CONTROL_NODE_DS_IP} \
                   -e GLANCE_HOST=${CONTROL_NODE_DS_IP} \
                   -e NEUTRON_HOST=${CONTROL_NODE_DS_IP} \
                   -e RABBITMQ_HOST=${CONTROL_NODE_DS_IP} \
                   -v /sys/fs/cgroup:/sys/fs/cgroup \
                   -v /var/lib/nova:/var/lib/nova \
                   -v /var/lib/nova/mnt:/var/lib/nova/mnt:shared \
                   -v /var/lib/libvirt:/var/lib/libvirt \
                   -v /run:/run \
                   -v $LOG_DIR/nova-compute:/var/log/supervisord \
                   --name nova-compute.${NAME_SUFFIX} \
                   ${NOVA_VER}
        if [[ $CONTROL_NODE == true ]]; then
            # if running compute on same host as controller discover compute node by nova
            sleep 5
            docker exec nova-controller.${NAME_SUFFIX} nova-manage cell_v2 discover_hosts
        fi
    fi
fi

log_info "Starting neutron-agent container ..."
if [[ `docker ps -a | grep -w neutron-agent.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
    docker start neutron-agent.${NAME_SUFFIX}
else
    if [[ $CONTROL_NODE != true ]]; then
        # EXTERNAL_BRIDGE is empty on COMPUTE_NODE as DVR is not implemented yet
        EXTERNAL_BRIDGE=''
    fi
    docker run -d --net=host --privileged \
	           --restart unless-stopped \
	           -e DEBUG="true" \
	           -e NEUTRON_CONTROLLER="false" \
	           -e EXTERNAL_BRIDGE=${EXTERNAL_BRIDGE} \
	           -e OVERLAY_INTERFACE=${DS_INTERFACE} \
	           -e DB_HOST=${CONTROL_NODE_DS_IP} \
	           -e KEYSTONE_HOST=${CONTROL_NODE_DS_IP} \
	           -e MEMCACHED_SERVERS=${CONTROL_NODE_DS_IP} \
	           -e RABBITMQ_HOST=${CONTROL_NODE_DS_IP} \
	           -v /run/netns:/run/netns:shared \
	           -v /lib/modules:/lib/modules \
	           -v $LOG_DIR/neutron-agent:/var/log/supervisord \
	           --name neutron-agent.${NAME_SUFFIX} \
	           ${NEUTRON_VER}
fi

## Save configuration of current cloud for later use in destroy or upgrade phases
> $CONF_FILE
echo "export INSTALL_REQS=false" >> $CONF_FILE
echo "export VERSIONS=$VERSIONS" >> $CONF_FILE
echo "export CONTROL_NODE=$CONTROL_NODE" >> $CONF_FILE
echo "export COMPUTE_NODE=$COMPUTE_NODE" >> $CONF_FILE
echo "export EXTERNAL_IP=$EXTERNAL_IP" >> $CONF_FILE
echo "export EXTERNAL_NET=$EXTERNAL_NET" >> $CONF_FILE
echo "export DS_INTERFACE=$DS_INTERFACE" >> $CONF_FILE
echo "export EXTERNAL_BRIDGE=$EXTERNAL_BRIDGE" >> $CONF_FILE
echo "export CONTROL_NODE_DS_IP=$CONTROL_NODE_DS_IP" >> $CONF_FILE

if [[ $CONTROL_NODE == true ]]; then
    echo ""
    echo -e "\e[92m============================ SUCCESS ================================\e[0m"
    echo -e ""
    echo -e "To access horizon navigate your browser to http://$JUST_EXTERNAL_IP:$HORIZON_PORT"
    echo -e "Admin credentials - User: admin, Password: $PASSWORDS"
    echo -e "Demo project creadentials - User: demo, Password: $PASSWORDS"
    echo -e ""
    echo -e "For managing the cloud with OpenStack client, run"
    echo -e "'\e[93msudo ./dscli.sh\e[0m' (it'll run osadmin container)"
    echo -e ""
    echo -e "You can use \e[93mfirst_vm.sh\e[0m script in osadmin container"
    echo -e "to build your first VM in demo project and you can use it"
    echo -e "as a crash course for setting up OpenStack cloud."
    echo -e ""
    echo -e "Source code: https://github.com/dietstack/dietstack"
    echo -e "Documentation: http://dietstack.readthedocs.io/"
    echo -e "Report a bug: https://github.com/dietstack/dietstack/issues"
    echo -e ""
    echo -e "\e[92m===================== DietStack by kmadac 2018 ======================\e[0m"
    echo -e ""
elif [[ $COMPUTE_NODE == true ]]; then
    echo ""
    echo -e "\e[92m============================ SUCCESS ================================\e[0m"
    echo -e ""
    echo -e "Compute node installed"
    echo -e ""
    echo -e "\e[92m==================== DietStack by kmadac 2018  ======================\e[0m"
    echo -e ""
else
    echo 'Neither $CONTROL_NODE or $COMPUTE_NODE variable is specified!'
fi
