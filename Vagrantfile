# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure("2") do |config|
 
  # sgl adds, see
  # https://cloud.centos.org/centos/7/vagrant/x86_64/images/
  config.vm.box = "ohif-vagrant"
  config.vm.box_url = "https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-1809_01.VirtualBox.box"

  # make a second hard disk https://gist.github.com/leifg/4713995
  # https://realworlditblog.wordpress.com/2016/09/23/vagrant-tricks-add-extra-disk-to-box/
  file_to_disk = './data.vmdk'
  config.vm.provider :virtualbox do | vb |
    unless File.exist?(file_to_disk)
    	vb.customize ['createhd', '--filename', file_to_disk, '--size', 50 * 1024]
  	end
  		vb.customize ['storageattach', :id, '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
  end


  # Port forwarding - uncomment the items below you will actually use
  # (as dictated by what is selected to install in the install.sh )
  # ssh port - not needed,  Vagrant does by default
  config.vm.network "forwarded_port", guest: 22, host: 2223

  # host ip = 10.0.2.2
  # first guest ip = 10.0.2.15
  # for ohif
  #config.vm.network "forwarded_port", guest: 8042, host: 8042
  #config.vm.network "forwarded_port", guest: 4242, host: 4242
 
  #for RDP session -
  #config.vm.network "forwarded_port", guest: 3389, host: 2179
  #config.vm.provider :virtualbox do |vb|
  #	vb.gui = true
  #end

  config.vm.provider "vmware" do |vb|
	# stub for now 
  end

  
  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  config.vm.provision "shell", path: "install.sh"

end
