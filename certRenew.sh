#!/bin/bash

# Variables
certHost="device.dattobackup.com"
certDir="/etc/datto/dla/certs"
certCheckFile="$certDir/server.pem"
backupCertDir="$certDir/old"

# Functions
checkRoot(){
	# This function checks that the current user is root
	if [[ $EUID != 0 ]]; then
		echo "Must run as root user."
		exit 1
	fi
}

checkConnectivity(){
	# This function checks connectivity to $certHost
	echo "Performing $certHost connectivity check."
	if ping -c 1 -W 1 $certHost &> /dev/null; then 
		echo Connectivity check succeeded.
	else
		echo "Connectivity check failed, cert renewal may fail."
	fi 
}

backupCerts(){
	# This function moves the current certs to the $backupCertDir
	echo "Storing current certificates before attempting renewal."
	if ! [[ -d $backupCertDir ]]; then
		mkdir $backupCertDir &> /dev/null
	fi

	# Move certs to $backupCertDir
	mv $certDir/* $backupCertDir &> /dev/null
}

removeBackupCerts(){
	# This function removes the backed up certs
	echo "Cleaning up."
	rm -rf $backupCertDir &> /dev/null
}

restoreBackupCerts() {
	# This function restores the backed up certs to their original location
	echo "Starting DattoBackupAgent Service with old certificates due to renewal failure."
	mv $backupCertDir/* $certDir &> /dev/null
}

stopDlaService(){
	# This function stops the DLA service
	if which systemctl &> /dev/null; then
		# systemd available
		systemctl stop dlad &> /dev/null
	else
		# no systemd available, use init script
		service stop restart &> /dev/null
	fi
}

startDlaService(){
	# This function starts the DLA service
	if which systemctl &> /dev/null; then
		# systemd available
		systemctl start dlad &> /dev/null
	else
		# no systemd available, use init script
		service start restart &> /dev/null
	fi
}

checkCertRenewalSuccess(){
	# This function checks that the cert renewal was successful
	if [[ -s $certCheckFile ]]; then
		echo "Certificate renewal completed successfully."
		return 0
	else
	    return 1
	fi
}

# Script
checkRoot
checkConnectivity
stopDlaService
backupCerts
startDlaService

if ! checkCertRenewalSuccess; then
	restoreBackupCerts
	startDlaService
	removeBackupCerts
else
	removeBackupCerts
fi
