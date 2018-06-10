.. _development: 

Development
===========

Whole development is done on `GitHub DietStack organization <https://github.com/dietstack>`_.

Each openstack service has its own git repository (docker-service_name) and is automatically built 
and tested on `Buildbot server <http://127.0.0.1:8081>`_ (not publicly available yet).
If test of container succesfuly passes, container is pushed to
`DockerHub <https://hub.docker.com/u/dietstack/>`_

We are working on bigger integration nightly testing with a
`tempest <https://docs.openstack.org/tempest/latest/>`_ openstack project.

Versioning
----------
TODO

Contribution
------------

Simply fork the repostiroy

DietStack consist of several git repositories. The main repository is
`dietstack/dietstack <https://github.com/dietstack/dietstack>`_ where main
deployment script ``ds.sh`` is located and then separate repositories for each openstack service.
If you want to contribute to any repository just simply
`fork it <https://help.github.com/articles/fork-a-repo/>_`, make changes, run the ``test.sh`` and
if test passes, create a `pull request <https://help.github.com/articles/fork-a-repo/>`_.

In order to test your changes to any project you need to have main dietstack repository cloned.
Then change the versions

Development environment
-----------------------
In order to contribute to development of DietStack you need to have Linux running on your machine.
I'm using Ubuntu, but I'm sure that any ditribution where Docker runs can be used for development.
Minimal configuration for development is at least 16 GB of ram. Then you
need to install following packages:

- `Docker <https://docs.docker.com/install/linux/docker-ce/ubuntu/>`_
- Vagrant with ``vagrant-libvirt`` plugin (sudo apt install vagrant; 
  vagrant plugin install vagrant-libvirt)
- libvirt-bin and qemu-kvm for virtualization in vagrant


Testing
-------

TODO
