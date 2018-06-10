.. _user-guide:

User guide
==========

Post installation notes
-----------------------

After installation of Control node, you can will have empty private cloud running. You have no
external network defined, no flavors, no images, no volumes, no ssh keys. So you cannot run any 
instance at the moment. In this stage you have a chance to learn how to get
Openstack cloud into usable state. You can do that in Horizon interface or in CLI utilizing
Openstack client, but DietStack has prepared bash script ``first-vm.sh`` in administration 
container called ``osadmin``.

Settings file
-------------
On each node, where you run ``ds.sh`` you will find file ``/srv/dietstack/settings.sh`` where
DietStack stores all important variables. DietStack will use that file for all subsequent
executions.

If you would like to change settings of existing installation you can change variables in
``settings.sh`` and rerun ``ds.sh``.

Administration container
------------------------

In order to manage your DietStack installation with Openstack client there is a container called
``osadmin``. To get to DietStack cli, just run ./dscli.sh script on Control Node and you will
get to container where you can find many useful utilities. One of most important is ``Openstack
client``.

If you want to manage OpenStack cloud, you need to authenticate against it. In osadmin container
you can find two rc files:

- ``adminrc`` -> will make you administrator of a cloud
- ``demorc`` -> demo user in demo project 

For instance, if you would like to list all users you have to be admin user, and use openstack
client to see all the users::

    $ . adminrc
    $ openstack user list


First Instance
--------------

Once you are in the administration container, you can prepare the cloud for running your first
instance with helper script::

    $ ./first_vm.sh

If script finishes succesfully there are several things configured:

- Created external network called ``external_network``
- Created m1.nano flavor (64MB RAM, 1GB disk)
- Created ``internal_network`` in ``demo`` project (192.168.35.0/24)
- Keypair mykey is added into ``demo`` project
- Instance ``first-vm`` is started
- Floating IP to ``first-vm`` is assigned

Log files
---------

Each DietStack docker container logs internally into container and log directory from container
is accessible on host in directory ``/srv/dietstack/logs/``

Stopping DietStack
------------------

Run as root from dietstack directory::

    sudo ./utils/destroy-ds.sh

.. warning:: This will destroy all data in database on control node
