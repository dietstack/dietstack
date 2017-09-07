#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Diestack must be run as root"
   exit 1
fi

readonly MYHOME=$(dirname $(readlink -e $0) )

. ${MYHOME}/lib/functions.sh

log_info() {
    local msg=$1
    echo -e "\e[33m[ $msg ]\e[0m"
}

NAME_SUFFIX='ds'
DS_DIR='/srv/dietstack'

# load containers version
# VERSIONS Format: Serial number
VERSIONS=${VERSIONS-1}
if [[ -z ${VERSIONS} ]]; then
    echo "Using latest versions!"
else
    if [[ ! -f ${MYHOME}/versions/${VERSIONS} ]]; then
        echo "Version file versions/${VERSIONS} not found !"
        exit 1
    fi
    . ${MYHOME}/versions/${VERSIONS}
fi

# what to install (at least one needs to be set to true. Both set to false will cause that no container will run)
CONTROL_NODE=${CONTROL_NODE:-true}
COMPUTE_NODE=${COMPUTE_NODE:-true}
CONTROL_NODE_IP=${CONTROL_NODE_IP:-""}

# if we are installing compute node, we need to set CONTROL_NODE_IP
if [[ $CONTROL_NODE != true && $COMPUTE_NODE == true && $CONTROL_NODE_IP == "" ]]; then
    echo 'IP of control node missing (please set variable $CONTROL_NODE_IP)'
    exit 1
fi

# if restart is true and containers are stopped just start the container instead of new run
RESTART=${RESTART:-true}
PASSWORDS=${PASSWORDS:-veryS3cr3t}
RABBITMQ_USER=openstack
BRANCH=${BRANCH:-master}
HORIZON_PORT=${HORIZON_PORT:-8082}
EXTERNAL_BRIDGE=${EXTERNAL_BRIDGE-'br-ex'} # br-ex will be default only if variable is unset.
                                           # If set to "" external it'll stay set to ""
                                           # Important in compute node because we need to tell the script that
                                           # we are not going to use EXTERNAL_BRIDGE
EXTERNAL_INTERFACE=${EXTERNAL_INTERFACE:-'eth0'} # if EXTERNAL_BRIDGE is set, this var is not used
                                                 # so to use it set EXTERNAL_BRIDGE=''
EXTERNAL_IP=${EXTERNAL_IP:-192.168.99.1/24} # doesn't need to be set. If so, EXTERNAL_BRIDGE
                                            # floating IPs won't be reacheable from localhost.
OVERLAY_INTERFACE=${OVERLAY_INTERFACE:-lo}

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
        docker stop neutron-compute.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm nova-compute.${NAME_SUFFIX} > /dev/null 2>&1 || true
        docker rm neutron-compute.${NAME_SUFFIX} > /dev/null 2>&1 || true
    fi
}

log_info "Starting DietStack version $VERSIONS ..."


##### clean existing containers
if [[ "$RESTART" != "true" ]]; then
    cleanup $CONTROL_NODE $COMPUTE_NODE
fi

if [[ $CONTROL_NODE == true ]]; then
    log_info "Pulling osadmin container..."
    docker pull ${OSADMIN_VER}

    # Configure host network
    log_info "Configure External Networking ..."
    ip a s | grep -q $EXTERNAL_BRIDGE || { brctl addbr $EXTERNAL_BRIDGE && ip link set dev $EXTERNAL_BRIDGE up; }
    if [[ ! -z $EXTERNAL_IP ]]; then
        EXTERN_NET=$(docker run --rm -e EXTERNAL_IP="$EXTERNAL_IP" ${OSADMIN_VER} \
                     python -c 'import os,ipaddress; print(str(ipaddress.IPv4Interface(os.environ["EXTERNAL_IP"]).network))' | tail -n 1)
        if [[ ! `ip addr | awk '/inet/ && /'"$EXTERNAL_BRIDGE"'/{print $2}' | grep "$EXTERNAL_IP"` ]]; then
            ip addr add $EXTERNAL_IP dev $EXTERNAL_BRIDGE
            if [[ ! `ip r | grep -w "$EXTERN_NET"` ]]; then
                ip route add $EXTERN_NET dev $EXTERNAL_BRIDGE
            fi
        fi
        # Docker from version 1.13 started to set FORWARD chain policy to DROP for security reasons,
        # so we need to add rule which allows us access  of floating IPs from outside of host
        # More: https://github.com/docker/docker/issues/14041
        if [[ ! `iptables -L FORWARD -n | grep ACCEPT | grep $EXTERN_NET` ]]; then
            iptables -A FORWARD -p all -d $EXTERN_NET -j ACCEPT -m comment --comment "DietStack"
            iptables -A FORWARD -p all -s $EXTERN_NET -j ACCEPT -m comment --comment "DietStack"
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
        docker run  --net=host -d --privileged --name nfs.${NAME_SUFFIX} \
                    -v ${DS_DIR}/cindervols:/cindervols -e SHARED_DIRECTORY=/cindervols \
                    ${NFS_VER}
    fi

    log_info "Starting sqldb container ..."
    if [[ `docker ps -a | grep -w sqldb.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start sqldb.${NAME_SUFFIX}
    else
        docker run -d --net=host -e MYSQL_ROOT_PASSWORD=$PASSWORDS \
                                 --name sqldb.${NAME_SUFFIX} ${SQLDB_VER}
    fi

    echo "Wait till sqldb is running ."
    wait_for_port 3306 120

    log_info "Starting Memcached node (tokens caching) ..."
    if [[ `docker ps -a | grep -w memcached.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start memcached.${NAME_SUFFIX}
    else
        docker run -d --net=host -e DEBUG= --name memcached.${NAME_SUFFIX} memcached
    fi

    log_info "Starting RabbitMQ container ..."
    if [[ `docker ps -a | grep -w rabbitmq.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start rabbitmq.${NAME_SUFFIX}
    else
        docker run -d --net=host -e DEBUG= --name rabbitmq.${NAME_SUFFIX} ${RABBITMQ_VER}
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
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
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
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e LOAD_META="true" \
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
        docker run -d --net=host --privileged \
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e NOVA_CONTROLLER="true" \
                   -e SPICE_HOST="$JUST_EXTERNAL_IP" \
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
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   -e NEUTRON_CONTROLLER="true" \
                   -e EXTERNAL_BRIDGE="$EXTERNAL_BRIDGE" \
                   -e EXTERNAL_IP="$EXTERNAL_IP" \
                   -e OVERLAY_INTERFACE=${OVERLAY_INTERFACE} \
                   -v /run/netns:/run/netns:shared \
                   -v /lib/modules:/lib/modules \
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
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
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
                   -e DEBUG="true" \
                   -e DB_SYNC="true" \
                   --name heat.${NAME_SUFFIX} \
                   ${HEAT_VER}
    fi

    wait_for_port 8004 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port 8004 (Heat API) not bounded!"
        exit $ret
    fi

    log_info "Starting horizon container ..."
    if [[ `docker ps -a | grep -w horizon.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start horizon.${NAME_SUFFIX}
    else
        docker run -d --net=host \
                   -e DEBUG="true" \
                   -e HORIZON_HTTP_PORT="$HORIZON_PORT" \
                   --name horizon.${NAME_SUFFIX} \
                   ${HORIZON_VER}
    fi

    wait_for_port $HORIZON_PORT 360
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Port $HORIZON_PORT (Horizon) not bounded!"
        exit $ret
    fi

    log_info "Bootstrapping keystone ..."
    # bootstrap openstack settings and upload image to glance
    set +e
    docker run --rm --net=host ${OSADMIN_VER} /bin/bash -c ". /app/tokenrc; \
                                              ADMIN_IP="$JUST_EXTERNAL_IP" \
                                              INTERNAL_IP="$JUST_EXTERNAL_IP" \
                                              PUBLIC_IP="$JUST_EXTERNAL_IP" \
                                              PASSWORD="$PASSWORDS" \
                                              bash -x /app/bootstrap.sh"
    ret=$?
    if [ $ret -ne 0 ] && [ $ret -ne 128 ]; then
        echo "Error: Keystone bootstrap error ${ret}!"
        exit $ret
    fi
    set -e

    docker run --rm --net=host ${OSADMIN_VER} /bin/bash -c ". /app/adminrc; openstack image list | grep -q cirros || \
                                                              openstack image create --container-format bare \
                                                              --disk-format qcow2 \
                                                              --file /app/cirros.img \
                                                              --public cirros"
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Error: Cirros image import error ${ret}!"
        exit $ret
    fi

    ## Save configuration of current cloud for later use in destroy or upgrade phases
    ## This is TODO
    CONF_DIR=~/.localstack
    mkdir -p $CONF_DIR
    > $CONF_DIR/settings.sh
    echo "JUST_EXTERNAL_IP=$JUST_EXTERNAL_IP" >> $CONF_DIR/settings.sh

fi

##### Compute containers

if [[ $COMPUTE_NODE == true ]]; then
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
                   -e DEBUG="true" \
                   -e NOVA_CONTROLLER="false" \
                   -e SPICE_HOST="$JUST_EXTERNAL_IP" \
                   -e DB_HOST=${CONTROL_NODE_IP} \
                   -e KEYSTONE_HOST=${CONTROL_NODE_IP} \
                   -e MEMCACHED_SERVERS=${CONTROL_NODE_IP} \
                   -e GLANCE_HOST=${CONTROL_NODE_IP} \
                   -e NEUTRON_HOST=${CONTROL_NODE_IP} \
                   -e RABBITMQ_HOST=${CONTROL_NODE_IP} \
                   -v /sys/fs/cgroup:/sys/fs/cgroup \
                   -v /var/lib/nova:/var/lib/nova \
                   -v /var/lib/nova/mnt:/var/lib/nova/mnt:shared \
                   -v /var/lib/libvirt:/var/lib/libvirt \
                   -v /run:/run \
                   --name nova-compute.${NAME_SUFFIX} \
                   ${NOVA_VER}
    fi

    log_info "Starting neutron-compute container ..."
    if [[ `docker ps -a | grep -w neutron-compute.${NAME_SUFFIX}` && "$RESTART" == "true" ]]; then
        docker start neutron-compute.${NAME_SUFFIX}
    else
        docker run -d --net=host --privileged \
                   -e DEBUG="true" \
                   -e NEUTRON_CONTROLLER="false" \
                   -e EXTERNAL_BRIDGE=${EXTERNAL_BRIDGE} \
                   -e OVERLAY_INTERFACE=${OVERLAY_INTERFACE} \
                   -e DB_HOST=${CONTROL_NODE_IP} \
                   -e KEYSTONE_HOST=${CONTROL_NODE_IP} \
                   -e MEMCACHED_SERVERS=${CONTROL_NODE_IP} \
                   -e RABBITMQ_HOST=${CONTROL_NODE_IP} \
                   -v /run/netns:/run/netns:shared \
                   -v /lib/modules:/lib/modules \
                   --name neutron-compute.${NAME_SUFFIX} \
                   ${NEUTRON_VER}
    fi
fi


if [[ $CONTROL_NODE == true ]]; then
    echo ""
    echo -e "\e[92m============================ SUCCESS ================================\e[0m"
    echo -e ""
    echo -e "To access horizon navigate your browser to http://$JUST_EXTERNAL_IP:$HORIZON_PORT"
    echo -e "Admin credentials - User: admin, Password: $PASSWORDS"
    echo -e "Demo project creadentials - User: demo, Password: $PASSWORDS"
    echo -e ""
    echo -e "For operating localstack with OpenStack client, run (it'll run osadmin container)"
    echo -e "'\e[93m./dscli.sh\e[0m'"
    echo -e ""
    echo -e "You can use \e[93mfirst_vm.sh\e[0m script in osadmin container"
    echo -e "to build your first VM in demo project and you can use it"
    echo -e "as a crash course to OpenStack."
    echo -e ""
    echo -e "\e[92m============= DietStack by Kamil Madac 2017 ===============\e[0m"
    echo -e ""
elif [[ $COMPUTE_NODE == true ]]; then
    echo ""
    echo -e "\e[92m============================ SUCCESS ================================\e[0m"
    echo -e ""
    echo -e "Compute node installed"
    echo -e ""
    echo -e "\e[92m============= DietStack by Kamil Madac 2017  ===============\e[0m"
    echo -e ""
else
    echo 'Neither $CONTROL_NODE or $COMPUTE_NODE variable is specified!'
fi
