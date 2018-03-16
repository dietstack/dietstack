# Dietstack (Beta)

Minimalistic private cloud based on OpenStack.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system. 

### Prerequisites

You need at least 8GB of RAM if you install all services (controller and compute) directly on your machine, but the more the better. 

Dietstack is tested in Debian 8/9 and on Ubuntu 16.04 so one of these systems is required.

You can also install it to Vagrant environment with libvirt provider.

You need to have installed Docker as all services are packaged to Docker images and KVM. This is covered by `ds_install_reqs.sh` script.

### Installing

A step by step series of examples that tell you have to get Dietstack running on your local machine

Clone the dietstack repository:

```
git clone ...
```

Install requirements

```
cd dietstack
./ds_install_reqs.sh 
```

Run dietstack
```
./ds.sh
```

End with an example of getting some data out of the system or using it for a little demo

## Running the tests

Explain how to run the automated tests for this system

### Break down into end to end tests

Explain what these tests test and why

```
Give an example
```

### And coding style tests

Explain what these tests test and why

```
Give an example
```

## Deployment

Add additional notes about how to deploy this on a live system

## Built With

* [Dropwizard](http://www.dropwizard.io/1.0.2/docs/) - The web framework used
* [Maven](https://maven.apache.org/) - Dependency Management
* [ROME](https://rometools.github.io/rome/) - Used to generate RSS Feeds

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc
