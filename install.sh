#!/bin/sh

################################################
# Author: SG Langer 12/11/2018
#
# Purpose: a scalable Vagrant install script for creating 
#	different kinds of VMs (Dev, dbase, webserver, etc)
#
# good ref
# https://www.tecmint.com/things-to-do-after-minimal-rhel-centos-7-installation/
#
# NOte: people may ask why this and not a Makefile? Or why not a Makefile +
#	a provisioner like Puppet or ANsible? Becuase I can do
#  more in Bash then in Make, and going from  N frameworks to N - 1 (or 2) 
#  reduces the moving parts and external dependencies
##################################################


####################  base tools
####################  The parts below get installed on the base VM

base() {
######################################
# Purpose: base utils for every VM
#	
#
###################################
	echo "installing base utils"
	sudo yum install -y epel-release
	sudo yum install -y wget
	sudo yum install -y curl
	sudo yum install -y nmap
	sudo yum install -y nano
	sudo yum install -y unzip
	sudo yum install -y net-tools
	sudo yum install -y ftp
	sudo yum install -y e2fsprogs
	sudo yum install -y nss-pam-ldapd

	# need to Cron the below via "rkhunter --check"
	#sudo yum install -y rkhunter	

	# setup - rebuild it like it was under RHEL 6
	sudo yum install -y setuptool
	sudo yum install -y system-config-securitylevel-tui
	sudo yum install -y authconfig
	sudo yum install -y ntsysv
	sudo yum install -y NetworkManager-tui

	# from here down we are in /home/vagrant
	# fetch zip of custom config files
	#wget https://github.com/sglanger/dev-vagrant/raw/master/files.tar
	cp /vagrant/files.tar /home/vagrant
	tar xvf files.tar

	# update sshd.conf to enable passwd
	sudo mv /etc/ssh/sshd_config /etc/ssh/sshd_config.ori
	sudo cp /home/vagrant/files/sshd_config /etc/ssh/sshd_config
	sudo systemctl restart sshd

	# fix setup menu
	sudo mv /etc/setuptool.d/99system-config-network-tui /etc/setuptool.d/99system-config-network-tui.ori
	sudo cp /home/vagrant/files/99system-config-network-tui /etc/setuptool.d
}

disk() {
######################################
# Purpose: find the /data disk, format
#	and mount it
# 	https://gist.github.com/leifg/4713995
###################################
	mkdir /mnt/data

	parted /dev/sdb mklabel msdos
	parted /dev/sdb mkpart primary 512 100%
	/usr/sbin/mkfs.ext4 /dev/sdb1

	echo `blkid /dev/sdb1 | awk '{print$2}' | sed -e 's/"//g'` /mnt/data   ext4   noatime,nobarrier   0   0 >> /etc/fstab
	mount -t ext4 /dev/sdb1 /mnt/data
}


################# build tools
#################

docker() {
######################################
# Purpose: for a Build VM, want tools to fetch
#	from git and be able to build Docker apps
#
###################################
	echo "installing build tools"
	sudo yum install -y git
	#sudo yum install -y docker
	# https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-centos-7
	sudo curl -fsSL https://get.docker.com/ | sh

	sudo systemctl enable docker
	sudo systemctl start docker
}




#################### databases
####################

postgres() {
######################################
# Purpose: install, create and start
#	default postgres
#
# https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-cento
###################################

	echo "installing postgres"
	sudo yum install -y postgresql-server postgresql-contrib
	sudo postgresql-setup initdb
	# if /data disk exists use it for tables
	if [ -d '/mnt/data' ] ; then
		echo 'moving dbase store'
		sudo mv /var/lib/pgsql/data/base /mnt/data/
 		sudo su postgres -c 'ln -s /mnt/data/base /var/lib/pgsql/data/base '
	fi
 
	sudo systemctl enable postgresql

	# update the below files to enable remote postgres connections
	sudo mv /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.ori
	sudo mv /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.ori
	sudo cp /home/vagrant/files/postgres/postgresql.conf  /var/lib/pgsql/data/
	sudo cp /home/vagrant/files/postgres/pg_hba.conf /var/lib/pgsql/data/
	sudo systemctl start 	postgresql

	# and setup detault user passwd
	echo "postgres" | sudo passwd --stdin postgres 
}


################################### dev tools9
###################################

dev() {
######################################
# Purpose: for a development VM want some 
#		languages and maybe IDE's
#
###################################
	echo "installing languages"

	# java, c, python,  and eclipse
	sudo yum install -y java-1.8.0-openjdk
	sudo yum install -y java-1.8.0-openjdk-devel
	sudo yum install -y centos-release-scl
	sudo yum install -y devtoolset-4
	sudo yum install -y python python-lxml python-devel
	
	# gradle https://www.vultr.com/docs/how-to-install-gradle-on-centos-7
	wget https://services.gradle.org/distributions/gradle-3.4.1-bin.zip
	sudo mkdir /opt/gradle
	sudo unzip -d /opt/gradle gradle-3.4.1-bin.zip
	sudo PATH=$PATH:/opt/gradle/gradle-3.4.1/bin
}



##############################  GUI and/or IDEs
##############################


GUI() {
######################################
# Purpose: VNC running via X, then xRDP on VNC
#
#	in-progress
#
###################################
	echo "installing GUI"
	# https://www.centos.org/forums/viewtopic.php?t=52900
	sudo yum groupinstall "GNOME Desktop"
	sudo yum install -y tigervnc-server9
	sudo wget http://dl.fedoraproject.org/pub/epel/testing/6/x86_64/Packages/x/xrdp-0.6.1-5.el6.x86_64.rpm
	sudo yum install -y xrdp-0.6.1-5.el6.x86_64.rpm
	sudo service xrdp start
	sudo /sbin/chkconfig xrdp on
	sudo /sbin/chkconfig vncserver on
}


####################### Top level appliance DOckers from here down
####################### These, if installed, are pulled from DOckerhub as self-contained apps and extend the
####################### base VM w/out altering it, but rely on base functions (storage, dbase)



mirth_hl7() {
############################
# Purpose:
#
#
##########################

	
	# To make a persistent mirth dbase with postgres, first make a stub dbase 
	sudo /usr/bin/createdb -U postgres mirthdb
	sudo /usr/bin/psql -U postgres -d mirthdb < /home/vagrant/files/mirth_hl7/mirthdb.sql

	# create and define the RSNAdb for the handling of HL7 data
	sudo /usr/bin/createdb -U postgres rsnadb
	sudo /usr/bin/psql -U postgres -d rsnadb < /home/vagrant/files/mirth_hl7/rsnadb.sql
	
	# and now get mirth DOcker
	sudo docker pull brandonstevens/mirth-connect

	# -1- and start it (using default Derby dbase)
	#sudo docker run --name mirth-hl7  -p 8080:8080 -p 8443:8443 --rm brandonstevens/mirth-connect &

	# -1a-  start it pointing to persistent Posgres
	sudo docker run --name mirth-hl7  -p 8080:8080 -p 8443:8443 --rm -v /home/vagrant/files/mirth_hl7/my_mirth.properties:/opt/mirth-connect/conf/mirth.properties:ro  brandonstevens/mirth-connect &
}


orthanc() {
############################
# Purpose: lay down the dependencies 
#	Orthanc needs to run and then
#	install Sebastian's Orthanc DOcker
##############################

	# To make a persistent Orthanc dbase with postgres, first make a stub dbase 
	sudo /usr/bin/createdb -U postgres orthanc
	sudo /usr/bin/psql -U postgres -d orthanc < /home/vagrant/files/orthanc/orthanc.sql
	
	# Now get the DOcker image https://book.orthanc-server.com/users/docker.html
	sudo docker pull jodogne/orthanc-plugins
	
	# -2- this runs Orthanc on SQLlite which goes poof when DOcker shuts down
	#sudo docker run  --name orthanc -p 4242:4242 -p 8042:8042 --rm jodogne/orthanc-plugins 

	# -2a- this starts Orthanc with a new conf file that point to Postgres
	# from https://book.orthanc-server.com
    sudo docker run --name orthanc -p 4242:4242 -p 8042:8042 --rm -v /home/vagrant/files/orthanc/orthanc.json:/etc/orthanc/orthanc.json:ro jodogne/orthanc-plugins 
}


ohif_dev() {
############################
# Purpose: this builds OHIF from source, 
#	good for wrting new Modules
# https://yarnpkg.com/en/docs/install#centos-stable
# https://docs.ohif.org/essentials/getting-started.html
#########################

	# https://computingforgeeks.com/installing-node-js-10-lts-on-centos-7-fedora-29-fedora-28/
	curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
	sudo yum clean all && sudo yum makecache fast
	sudo yum install -y gcc-c++ make
  	sudo yum install -y node.js
	#sudo yum install -y npm
	curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
	sudo yum install -y yarn

	# now get ohif source
	sudo yum install -y git
	git clone https://github.com/OHIF/Viewers.git
	cd Viewers
	yarn config set workspaces-experimental true
	sudo yarn install
	sudo yarn run dev

}


ohif() {
############################
# Purpose: this launches canned 
#	OHIF docker for quick demo
##########################

	docker

	# from https://github.com/OHIF/Viewers/issues/360 
	# abd https://hub.docker.com/r/ohif/viewer
	sudo docker pull ohif/viewer:latest
	#sudo docker run -p 3000:3000 --name ohif ohif/viewer:latest
	cd /home/vagrant/files/ohif/run_dock.sh build
	cd -
}


############################
# Main
# Purpose: provisioner
# Caller: parent Vagrantfile
#
# 
#############################
	clear
	# base is always called
	base

	# now check if /data disk exists, if yes handle it
	if [ ! -f /dev/sdb ] ; then 			
		disk
	fi


	# then depending on role we call one or more Docker apps
	#ohif_dev
	ohif
	
	exit
	

