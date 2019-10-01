#!/bin/bash

###############################################
# Author: SG Langer Nov. 2018
# Purpose:put all the Vagrant commands to build/run 
#	this VM in one easy place
#	Follows same syntax as the Docker version
############################################

clear


case "$1" in

	build)
		# force a rebuild from scratch - costly
		vagrant destroy
		$0 start
		# vagrant reload
	;;

	start)
		# first time build from scratch, or restarts a paused VM
		vagrant up
	;;

	conn_r)
		vagrant rdp &
	;;

	conn)
		# every rebuild changes the RSA key, so ....
		ssh -Y -p 2222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@localhost
	;;
	
	status)
		vagrant status
	;;

	stop)
		vagrant suspend

	;;
		
	*)
		echo "invalid option"
		echo "valid options: build/conn/start/stop/status/"
		exit
	;;
esac
