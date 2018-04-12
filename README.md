# Dietstack (Beta)

[![RTD](https://readthedocs.org/projects/dietstack/badge/?version=latest)](https://dietstack.readthedocs.io/) [![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/dietstack/)

Lightweight private cloud based on OpenStack.

There are many OpenStack distributions which tries to be very universal and to cover all use cases.
This makes them too complex, tough to install and maintain. On the contrary DietStack is focused
on simplicity of installation, maintenance, upgrade, backup and restore. 

Only requirements are Linux, Docker and Git to clone DietStack.
All OpenStack services are running in docker containers and all docker images are also built with
minimal size in mind.

Documentation can be found on [readthedocs](http://dietstack.readthedocs.io/en/latest/).
You can find us also on [gitter](https://gitter.im/dietstack/).

DietStack is designed for small businesses, schools, training centers and for anyone who would
like to use on-premise private cloud without high operational costs.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for
development and testing purposes. Best way how to try it is to use Virtual Machine. You can also
use our vagrant environment, but it is two-node installation by default.

### Prerequisites

You need at least 8GB of RAM and 10GB of disk space if you install all services
(controller and compute) on one machine.

Dietstack is tested on Debian 8/9, on Ubuntu 16.04 and 18.04, so one of these systems is required.

You can also install it to Vagrant environment with libvirt provider.

You need to have installed Docker as all services are packaged to Docker images and KVM enabled. 
Installation of requirements is  covered by `requirements` function in `utils/install-reqs-ds.sh`
script.

### Installing

Please check [documentation](http://dietstack.readthedocs.io/en/latest/installation.html#) and
choose one of the 3 ways how to install DietStack.

## Running the tests

Each docker service has simple smoke test called `test.sh` in root directory of service repository. 
This test is run during each build and if test is finished with exit code 0, build is
considered succesful. 
Before each push, you should run the `test.sh` on your local machine to save CI system resources.

Integration tests with [Tempest](https://docs.openstack.org/tempest/latest/) are not ready yet,
but it is already on our issue list - https://github.com/dietstack/dietstack/issues/2.
Though you shold still do manual testing of your deployment.

## Test Deployment

Deployment on live systems is decribed in official
[documentation](http://dietstack.readthedocs.io/en/latest/), but testing deployment should consist
of following steps:

1. Build locally docker services which you modified with `build.sh` script
2. Create new version in dietstack/version dir (for example dev-newversion)
3. run `VERSIONS=dev-newversion ./ds.sh`
4. run `first_vm.sh` in `dscli.sh` container 

## Contributing

Please read [development](http://dietstack.readthedocs.io/en/latest/development.html) for the
process for submitting pull requests.

## Versioning

We use very simple versioning scheme. Version 1.x is OpenStack Newton, 2.x is OpenStack Pike.
Version of OpenStack for 3.x is not chosen yet.
Currently we are using dev branch for development of 2.x version of DietStack.

# Authors

* **Kamil Madac** - *Initial work* - [kmadac](https://github.com/kmadac)
* **Marek Ruzicka** - *Containerization* - [marekruzicka](https://github.com/marekruzicka)

See also the list of [contributors](https://github.com/dietstack/diestack/contributors) who 
participated in this project.

## License

This project is licensed under the Apache License 2.0 see the [LICENSE](LICENSE) file for
details

