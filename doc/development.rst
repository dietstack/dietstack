.. _development: 

Development
===========

Whole development is done in `GitHub DietStack organization <https://github.com/dietstack>`_.

Each openstack service has own git repository (docker-service_name) and is automatically built 
and tested on `Buildbot server <http://127.0.0.1:8081>`_. If test of container succesfuly passes,
container is pushed to `DockerHub <https://hub.docker.com/u/dietstack/>`_

We are working on bigger integration nightly testing with a
`tempest <https://docs.openstack.org/tempest/latest/>`_ openstack project.

