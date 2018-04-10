# Dietstack (Beta)

Lightweight private cloud based on OpenStack.

There are many OpenStack distributions which tries to be very universal and to cover all use cases.
This makes them too complex, tough to install and maintain. On the contrary DietStack is focused
on simplicity of installation, maintenance, upgrade, backup and restore. 

Only requirements are Linux, Docker and Git to clone DietStack.
All OpenStack services are running in docker containers and all docker images are also built with
minimal size in mind.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for
development and testing purposes. Best way how to try it is to use Virtual Machine. You can also
use our vagrant environment, but it is two-node installation by default.

### Prerequisites

You need at least 8GB of RAM if you install all services (controller and compute) directly on
your machine, but the more the better. 

Dietstack is tested in Debian 8/9 and on Ubuntu 16.04 so one of these systems is required.

You can also install it to Vagrant environment with libvirt provider.

You need to have installed Docker as all services are packaged to Docker images and KVM enabled. 
Installation of requirements is  covered by `requirements` function in `utils/install-reqs-ds.sh`
script.

### Installing

Here is example that tell you have to get Dietstack running on your local machine.

```
git clone https://github.com/dietstack/dietstack.git --recursive
cd dietstack
sudo ./ds.sh
```

Now you see how containers are launched, databases are created and OpenStack is bootstrapped. Once
deployment processes is finished you can browse to http://192.168.99.1:8082/ or run `./dscli`
to get to administration container.

## Running the tests

Each docker service has simple smoke test called `test.sh` in root directory of service repository. 
This test is run during each build and if test is finished with other value than 0, build is
considered unsuccesful. 
Before each push, you should run the `test.sh` to save CI system resources.

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

This project is licensed under the Apache License 2.0- see the [LICENSE](LICENSE) file for
details

