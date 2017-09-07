# Deployment scripts for local development

Scripts can deploy all OpenStack containers on local machine.
All containers use host networking (`--net host` parameter).

### Requirements

Even we deploy OpenStack in contatiners, your local computer still needs to fulfill couple of requirements.
The fact is that you cannot run VMs in container so libvirt has to run on host. 
Probably in the future we will containerize these component, but currently it is not top priority.

Steps to prepare your local machine:

1. Install Kvm and Libvirt daemon
2. Install Docker
3. Configure Docker Proxy

On Debian/Ubuntu there is script whichh installs all requirements:
```
  sudo bash ./install_requirements.sh
```

On CentOS - `Untested!`:
```
  sudo yum install kvm libvirt 
  systemctl start libvirtd 
  systemctl enable libvirtd
  # For installing docker, follow steps on official Docker page https://docs.docker.com/engine/installation/
    
```

#### Docker proxy configuration
Debian:
In file ,,/etc/defualt/docker"
 add proxy settings:
 HTTP_PROXY="http://172.16.3.3:3128/"
 HTTPS_PROXY="https://172.16.3.3:3128/"
 NO_PROXY="localhost,172.27.9.130,127.0.0.1,172.27.10.10,10.233.130.190,.t-systems.sk"

afterwards restart docker service with command "service docker restart"
check if proxy settings are loaded via command "docker info"
if not, add you proxy settings into /etc/environment, and add EnviromentFile configuration into "/etc/systemd/system/docker.service.d/environment.conf"

``` 
[Service]
EnvironmentFile=/etc/environment
```

restart docker service again and proxy setting should be loaded now

#### Usage

```
  cd docker-localstack; ./run-os.sh
```

This command will run openstack services in docker containers. 

#### Outside connectivity for Instances with NAT if running on local node

iptables -t nat -A POSTROUTING -p all -o `ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)'` -s 192.168.99.0/24 ! -d 192.168.99.0/24 -j MASQUERADE
