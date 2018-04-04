#!/bin/bash
# Author: sigmaze

###################
##General Functions and Varaibles:


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
LOG_DIR="${HOME}/${SCRIPT_NAME%%.sh}.log"
SAVE_DIR="/root/k8sinfo"
# set -e
# set -o pipefail     

#Logging handling 
function log (){
	now=$(date)
	
	if [[ "$1" == "[DEBUG]" ]] ; then
		# echo -e "${now} - $@" 1>&2 | tee -a $LOG_DIR	
		if [[ "${DEBUG}" == "true" ]]; then
			echo "${now} - $@" 1>&2 > >(tee -a $LOG_DIR) 2> >(tee -a $LOG_DIR >&2)
		fi
	elif [[ "$1" == "[ERROR]" ]] ; then
		echo "${now} - $@" 1>&2 > >(tee -a $LOG_DIR) 2> >(tee -a $LOG_DIR >&2)
	else
		echo "${now} [INFO] - $@" > >(tee -a $LOG_DIR) 2> >(tee -a $LOG_DIR >&2)
	fi

}

function usage() {	
cat << EOF
USAGE: ${SCRIPT_NAME} --debug --help
EOF

}

function helptext() {

	local tab=$(echo -e "\t")
cat << EOF
$(usage)
Simple scripts to prepare environement
EOF

}

function etchosts () {

cat <<EOF 
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

192.168.3.101   centos7mb1.locald centos7mb1
192.168.3.102   centos7mb2.locald centos7mb2
192.168.3.103   centos7mb3.locald centos7mb3
192.168.3.104   centos7mb4.locald centos7mb4
192.168.3.105   centos7mb5.locald centos7mb5
192.168.3.105   centos7mb5.locald centos7mb5
192.168.3.106   centos7mb6.locald centos7mb6

EOF
}

function InstallTools() {

    log Instaling General tools
    yum install wget curl net-tools vim -y

}

function fixingIssueOnVagrant(){
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

    sysctl --system
    swapoff -a
    mkdir -p /root/.ssh/
    cp /home/vagrant/.ssh/id_rsa_root /root/.ssh/id_rsa
    cp /home/vagrant/.ssh/id_rsa.pub_root /root/.ssh/id_rsa.pub
    echo #{ssh_insecure_key_public} >> /root/.ssh/authorized_keys
    chown root /root/.ssh/*
    chmod 400 /root/.ssh/*
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart sshd

}




function startProvisioning() {
    log Started script on $(whoami)
    InstallTools || return 1
    fixingIssueOnVagrant 
    etchosts > /etc/hosts


}

# argument handling to 
function arg_handler(){

log [DEBUG] "Number of argumts passed" $#



while [ $# -ge 1 ] ; do
	log [DEBUG] "Proccessing argument $1"

	case $1 in
		--debug)
			DEBUG="true"
		;;
		--help)
			helptext
			exit 0
		;;
		*)
		log [ERROR] "not supported arg"
		helptext
		exit 1
		;;
	
	esac


shift
done

}
#argument handling execution this way I never lose arguments from main if shift is used 
arg_handler "$@"

log [DEBUG] "DEBUG enabled"
log [DEBUG] " main variables set-
	SCRIPT_DIR=$SCRIPT_DIR
	SCRIPT_NAME=$SCRIPT_NAME
	LOG_DIR=$LOG_DIR"
#MAIN PROGRAM and functions
if [ $# -eq 0 ];then
	 startProvisioning 1>&2 > >(tee -a $LOG_DIR) 2> >(tee -a $LOG_DIR >&2)
	# InstallTools 1>&2 > >(tee -a $LOG_DIR) 2> >(tee -a $LOG_DIR >&2)
	
fi

