#!/bin/bash
# Author: sigmaze

###################
##General Functions and Varaibles:


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
LOG_DIR="/root/${SCRIPT_NAME%%.sh}.log"
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
}

function creatingMaster() {
    #master node part only if wrong dirver is used for docker
    # docker info | grep -i cgroup
    # cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    # sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    # systemctl daemon-reload
    # systemctl restart kubelet

    #master 
    fixingIssueOnVagrant 

    swapoff -a
    #pod-network-cidr required for flanel
    log Starting kubeadm init
    kubeadm init --apiserver-advertise-address=$(ifconfig eth2|grep 'inet '|awk '{print $2}') --pod-network-cidr='10.244.0.0/16'
   
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
     # deplying flannel
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    
}
function startProvisioning() {
    log Started script on $(whoami)
    InstallTools || return 1
    
    log installing docker and kubernetes necessery components
    yum install -y docker
    systemctl enable docker && systemctl start docker 
    repoprint > /etc/yum.repos.d/kubernetes.repo
    setenforce 0
    yum install -y kubelet kubeadm kubectl
    systemctl enable kubelet && systemctl start kubelet
    yum update
    

    log joining node node

    
    
    # kubeadm token list|head -n 2|tail -n 1|awk {'print $1'}
    # netstat -lnp|grep kube-apiserver|awk -F':' {'print $4'}



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
	
fi

