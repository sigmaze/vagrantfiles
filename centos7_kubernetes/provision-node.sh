#!/bin/bash
# Author: sigmaze

###################
##General Functions and Varaibles:


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
LOG_DIR="${HOME}/${SCRIPT_NAME%%.sh}.log"
SAVE_DIR="/root/k8sinfo"
MASTER_API_HOST="192.168.99.100"
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

function repoprint () {

cat <<EOF 
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-$(uname -m)
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
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

function getMasterApiFiles() {
   
 mkdir -p ${SAVE_DIR}
     
 scp $MASTER_API_HOST:${SAVE_DIR}/k8s_api_token ${SAVE_DIR}
 scp $MASTER_API_HOST:${SAVE_DIR}/k8s_api_port ${SAVE_DIR}
 scp $MASTER_API_HOST:${SAVE_DIR}/k8s_config ${SAVE_DIR}
 scp $MASTER_API_HOST:${SAVE_DIR}/k8s_sha256 ${SAVE_DIR}


}
function SSHecho(){
    ssh -o StrictHostKeyChecking=no $MASTER_API_HOST echo "Added host"
}

function joinNode() {
SSHecho
getMasterApiFiles
token=$(cat ${SAVE_DIR}/k8s_api_token)
master_api_port=$(cat ${SAVE_DIR}/k8s_api_port)
hash_master_api=$(cat ${SAVE_DIR}/k8s_sha256)

# kubeadm join 192.168.1.74:6443 --token u8m859.m3fn39kzxnhtd3no --discovery-token-ca-cert-hash sha256:eb04995e8e4798b5cfc6b2195ff6c91e04eb398f56b4465c73e5d26ee6e027d7
log "start kubeadm join"
log "kubeadm join $MASTER_API_HOST:$master_api_port --token $token --discovery-token-ca-cert-hash sha256:$hash_master_api"
kubeadm join $MASTER_API_HOST:$master_api_port --token $token --discovery-token-ca-cert-hash sha256:$hash_master_api  
}



function startProvisioning() {
    log Started script on $(whoami)
    InstallTools || return 1
    fixingIssueOnVagrant
    
    log installing docker and kubernetes necessery components
    yum install -y docker
    systemctl enable docker && systemctl start docker 
    repoprint > /etc/yum.repos.d/kubernetes.repo
    setenforce 0
    yum install -y kubelet kubeadm kubectl
    systemctl enable kubelet && systemctl start kubelet
    # yum update -y
    
    
    log Getting k8s masterapi files
    joinNode
    
    
    

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

