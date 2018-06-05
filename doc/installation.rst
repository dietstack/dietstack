.. _installation:

Instalation
===========

Architecture
------------
Unlike other OpenStack distributions DietStack supports only one configuration.
There is a Control-Node, where Mysql, Rabbitmq and all OpenStack server components are
running. In most basic installation, you can deploy everything on one node so
Control-Node is also Compute-Node. This way you can run DietStack locally on your
notebook or desktop for development, testing or training purposes.

Networking in DietStack projects
--------------------------------
Each instance is connected to one or more private networks which are not directly accessible from
outside of a cloud.
Instances that are not on same private network cannot communicate together without router.
It is very similar to the way how pysical networking is working in real world.
There is a concept of Floating IP, which are public routable IPs and these can be
optionally assigned to private IPs of VM and have access to VM from outside of a cloud.
DietStack does not implement Ditributed Virtual Router (DVR) technology which makes
networking more robust, but makes physical networking more complex.
                                                                                                    
How to connect DietStack to your physical network
-------------------------------------------------
As written in previous topic, Floating IPs needs to be externaly routable in order to users are
able to connect to instances created by DietStack.
It means that you need to choose physical network, where you need to have a pool of IP addresses
which are dedicated for that purpose - will be assigne by Neutron and not by your DHCP server).
Floating IP rabge can be then specified during creation of external network during DietStack 
initial configuration (see ``first_vm.sh`` script in container invoked by ``dscli.sh``)


1. Local Installation
---------------------
All containers will run on your local computer.

Requirements
^^^^^^^^^^^^

1. At least 8GB RAM
2. At least 10GB of free space
3. Debian 9 or Ubuntu 16.04 on your computer
4. ``root`` privileges or ability to get then with ``sudo``

.. code-block:: bash

    git clone https://github.com/dietstack/dietstack.git --recursive
    cd dietstack
    sudo ./ds.sh

Now you can connect to Horizon Dashboard :) - http://192.168.99.1:8082

You can also run OpenStack client to manage OpenStack cloud from cli::

    ./dscli.sh

2. DietStack in Vagrant                                                                             
-----------------------                                                                             
DietStack runs in two and more VMs conrolled by Vagrant.                                           

Requirements
^^^^^^^^^^^^

1. At least 8GB RAM
2. At least 10GB of free space
3. kvm enabled and Vagrant with ``vagrant-libvirt`` plugin installed

Then you can run::                                                                               
                                                                                                    
    git clone https://github.com/dietstack/dietstack.git --recursive
    cd dietstack/vagrant
    vagrant up
                                                                                                    
You can connect to Horizon Dasboard on http://192.168.99.2:8082

You can also run OpenStack client to manage OpenStack cloud from cli::
                                                                                                    
    vagrant ssh control.dietstack
    sudo su -
    cd /root/dietstack
    ./dscli.sh

3. Multi-Node Installation                                                                          
--------------------------                                                                          

This is installation you will need to use when you would like to use DietStack for the real
purposes.

Requirements
^^^^^^^^^^^^

1. Debian 9, Ubuntu 16.04 or Ubuntu 18.04 already installed on all nodes
2. At least 8GB RAM on Control-Node
3. At least two ethernet interfaces on Control-Node (one for external connectivity and one for 
   DS network)
4. At least one ethernet interface on each Compute-Node (DS Network)
5. One switch (1G/10G) to connect all nodes (DS Network)
6. Couple of ethernet cables to connect nodes with a switch
7. Dedicated block device (mirrored if possible) for Cinder volumes (optional)
8. Dedicated block device for Mysql backups (optional)
9. ``root`` privileges or ability to get then with ``sudo`` on all nodes


Network diagram
^^^^^^^^^^^^^^^

.. image:: images/dietstack_net_1.svg
   :align: center

Control node
~~~~~~~~~~~~

First and most complex step is to prepare networking, interface for external connectivity and
interface for DS network.


For external connectivity you need setup ``br-ex`` interface. It is a ``linux bridge`` and if
we want to have connectivity for the endusers, we need to add physical interface into it.
Let's say interface `ens3` is connected to switch to
your network and will be used by users to access VMs. Your external network has subnet
10.0.0.0/16, IP address on ens3 interface is 10.0.0.2 and default gw is 10.0.0.1.

Create file called ``/etc/network/interfaces.d/br-ex`` with following
content::

	auto ens3
	iface ens3 inet manual

	# Bridge setup
	auto br-ex
	iface br-ex inet static
		bridge_ports ens3
		address 10.0.0.2
		netmask 255.255.0.0

Remove ``ens3`` lines from ``/etc/network/interfaces`` and install ``bridge-utils`` package::

    apt-get install -y bridge-utils

Now you can setup your DS network interface. DS network is used for communication between
openstack services on all nodes, for vxlans tunnels and for nfs mounts, and it has to be separated
from external network. Do not use DHCP in DS network, but use static assignment. Let's say name of
your DS interface is ``ens4``. You can freely choose same subnet as we did (192.168.1.0/24), so
``192.168.1.1`` for you control node is OK.

Create file ``/etc/network/interfaces.d/ds-net`` with following content::

    auto ens4
    iface ens4 inet static
        address 192.168.1.1
        netmask 255.255.255.0

Now you can reboot your node. After the reboot, ensure that your ``br-ex`` interface is up and have
ip address assigned (``ip a s``). Do the same for your DS network interface.

If everything is correct, you can install Dietstack on control node::

    sudo su -
    git clone https://github.com/dietstack/dietstack.git --recursive
    cd dietstack
    EXTERNAL_IP='10.0.0.2/16' DS_INTERFACE=ens4 ./ds.sh

- DS_INTERFACE=ens4 - ``ens4`` is interface physicaly connected to DS switch
- EXTERNAL_IP='10.0.0.2/16' - needs to be set in order to horizon spice console works (same as on control node)

Block storage for Cinder service
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Control node is also storage node in DietStack installation. It means that when you create volume
in Horizon interface writes will go over NFS to control node and to block device we will configure
here. Block device needs to be mounted to ``/srv/dietstack/cindervols``.


Compute nodes
~~~~~~~~~~~~~

Installation of compute node is much easier than installation of control node. You just need to
clone the repository and run the ``ds.sh`` with correct parameters::

    sudo su -
    git clone https://github.com/dietstack/dietstack.git --recursive
    cd dietstack

    COMPUTE_NODE=true EXTERNAL_IP='10.0.0.2/16' DS_INTERFACE=ens4 CONTROL_NODE_DS_IP=192.168.1.1 ./ds.sh

So you basically need to set 4 variables:

- COMPUTE_NODE=true - we are installing compute node
- DS_INTERFACE=ens4 - ``ens4`` is interface physicaly connected to DS switch
- CONTROL_NODE_DS_IP=192.168.1.1 - tells to DietStack where to find control node in DS network
- EXTERNAL_IP='10.0.0.2/16' - needs to be set in order to horizon spice console works (same as on control node)

Continue to :ref:`user-guide`
