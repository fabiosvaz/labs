# Overview

This lab will guide you on how to use Vagrant to create virtual machines.

Vagrant is a tool for building and managing virtual machine environments in a single workflow. With an easy-to-use workflow and focus on automation, Vagrant lowers development environment setup time, increases production parity, and makes the "works on my machine" excuse a relic of the past.

This lab will be using VirtualBox as provider.

Following are base information that will allow us to work with Vagrant. For more details and advanced configurations, please refer to official documents:

- https://www.vagrantup.com/docs/

# Getting Started

Once you have Vagrant and VirtualBox installed, you can open a shell prompt and create a Vagrantfile by running the following command.

```
vagrant init
```

This will place a Vagrantfile in the current directory.

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "base"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
```

From now on, you can open the Vagrantfile created and customize it.

## Box

Vagrant has multiple boxes in the cloud repository, you can search for a desired box by accessing.

```
https://app.vagrantup.com/boxes/search
```

To set for example an Ubuntu box, open the Vagrantfile and change the contents to the following:

```
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
end
```

## Network

In order to access the Vagrant environment created, Vagrant exposes some high-level networking options for things such as forwarded ports, connecting to a public network, or creating a private network.

One option is to use port forwarding. Port forwarding allows you to specify ports on the guest machine to share via a port on the host machine. This allows you to access a port on your own machine, but actually have all the network traffic forwarded to a specific port on the guest machine.

```
Vagrant.configure("2") do |config|
  # ...
  config.vm.network "forwarded_port", guest: 80, host: 8080
end
```

Vagrant private networks allow you to access your guest machine by some address that is not publicly accessible from the global internet

The easiest way to use a private network is to allow the IP to be assigned via DHCP.

```
Vagrant.configure("2") do |config|
  config.vm.network "private_network", type: "dhcp"
end
```

This will automatically assign an IP address from the reserved address space. The IP address can be determined by using vagrant ssh to SSH into the machine and using the appropriate command line tool to find the IP, such as ifconfig.

You can also specify a static IP address for the machine. This lets you access the Vagrant managed machine using a static, known IP. The Vagrantfile for a static IP looks like this:

```
Vagrant.configure("2") do |config|
  config.vm.network "private_network", ip: "192.168.50.4"
end
```

It is up to the users to make sure that the static IP does not collide with any other machines on the same network.

You can specify a static IP via IPv6. DHCP for IPv6 is not supported. To use IPv6, just specify an IPv6 address as the IP:

```
Vagrant.configure("2") do |config|
  config.vm.network "private_network", ip: "fde4:8dba:82e1::c4"
end
```

This will assign that IP to the machine. The entire /64 subnet will be reserved. Please make sure to use the reserved local addresses approved for IPv6.

You can also modify the prefix length by changing the netmask option (defaults to 64):

```
Vagrant.configure("2") do |config|
  config.vm.network "private_network",
    ip: "fde4:8dba:82e1::c4",
    netmask: "96"
end
```

IPv6 supports for private networks was added in Vagrant 1.7.5 and may not work with every provider.

## Provider Configurations

Provider-specific configuration can be specified to fine-tune the VM that will be created. Example for VirtualBox.

```
config.vm.provider "virtualbox" do |vb|
  # Display the VirtualBox GUI when booting the machine
  vb.gui = true

  # Customize the amount of memory on the VM:
  vb.memory = "1024"
  vb.cpus = 2
end
```

## Provision

Vagrant has built-in support for automated provisioning. Using this feature, Vagrant will automatically install software when you start a VM so that the guest machine can be repeatably created and ready-to-use.

we can configure Vagrant to run a shell script when setting up our machine. We do this by editing the Vagrantfile.

```
Vagrant.configure("2") do |config|
  config.vm.provision :shell, path: "bootstrap.sh"
end
```

The "provision" line tells Vagrant to use the shell provisioner to setup the machine, with the bootstrap.sh file. The file path is relative to the location of the project root (where the Vagrantfile is).

We can also have the provisioning commands inline.

```
Vagrant.configure("2") do |config|
  config.vm.provision "shell",
    inline: "echo Hello, World"
end
```

There are multiple ways to provision a VM. Vagrant also allow us to use Ansible, Chef, Puppet and Salt. And recently, we can provision a VM with docker by just running.

```
Vagrant.configure("2") do |config|
  config.vm.provision :docker
end
```

The Vagrant Docker provisioner can automatically install Docker, pull Docker containers, and configure certain containers to run on boot.