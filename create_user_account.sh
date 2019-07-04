#!/bin/bash
# Author : Adrien FAVRE <adrien.favre@alterdomus.com>
# Created on 02/07/2019
# Description : Create unix account

RC_NOT_ROOT=2
RC_DUPLICATE_USERNAME=3

function p_err
{
	echo "$*" 1>&2 
}

function read_input
{
	read $1 LINE
	echo $LINE
}

if [ "$(whoami)" != "root" ]
then
	p_err "This script must be run as root"
	p_err "Exiting with status ${RC_NOT_ROOT}"
	exit ${RC_NOT_ROOT}
fi

VALID_USERNAME_REGEX="^\([a-z][-a-zA-Z0-9_]*\$\)"

VALID_USERNAME="KO"
while [ "${VALID_USERNAME}" != "OK" ] 
do
	echo -ne "Type the service account username: "
	SERVICE_USER=$(read_input)
	STATUS=$(echo ${SERVICE_USER} | grep ${VALID_USERNAME_REGEX})
	# Status is empty if regex does not match = requirements not matching
	# Based on POSIX.1-2017 03.437 - But we do not allow '.' char for obvious shell commands issues
	if [ "${STATUS}" != "" ] 
	then
		if [ "$(cat /etc/passwd | cut -f 1 -d ':' | grep ${SERVICE_USER})" = "${SERVICE_USER}" ]
		then
			# Account is already in file /etc/passwd = Duplicate account
			p_err "User account '${SERVICE_USER}' already exists !"
			continue
		fi
		VALID_USERNAME="OK"
	else
		echo "Username does not match POSIX requirements"
		echo "It should only contain lowercase chars with '-' or '_' but not at the first char"
		echo ""
	fi
done

CRACKLIB_PRESENT=$(which cracklib-check 2> /dev/null)
if [ $? -ne 0 ] 
then
	CRACKLIB_PRESENT="False"
fi

VALID_PASSWORD="ko"
while [ "${VALID_PASSWORD}" != "OK" ]
do
	echo -ne "Type the account password (min 8 chars): "
	SERVICE_PASSWD=$(read_input "-s")
	echo ""
	echo -ne "Type the account password again: "
	SERVICE_PASSWD_2=$(read_input "-s")
	if [ "${SERVICE_PASSWD}" != "${SERVICE_PASSWD_2}" ]
	then
		echo "Password does not match"
		echo ""
		continue
	fi
	if [ $(echo "${SERVICE_PASSWD}" | wc -c) -lt 8 ]
	then
		echo "Password is too short !"
		echo ""
		continue
	fi
	if [ "${CRACKLIB_PRESENT}" != "False" ]
	then
		PASSWD_STRENGTH=$(echo ${SERVICE_PASSWD} | cracklib-check | cut -f 2 -d ':')
		if [ "${PASSWD_STRENGTH}" != " OK" ]
		then 
			echo ""
			echo "Password issue :  ${PASSWD_STRENGTH}"
			continue
		fi
	fi
	VALID_PASSWORD="OK"
done

adduser ${SERVICE_USER} -d /home/svc_mdm -m -p $(echo "${SERVICE_PASSWD}" | openssl passwd -1 -stdin) -s /bin/sh
RC=$?
if [ ${RC} -ne 0 ]
then
	p_err "Something went wrong with adduser command"
	p_err "Exit status ${RC}"
	exit ${RC}
fi

echo "User '${SERVICE_USER}' added successfully"
