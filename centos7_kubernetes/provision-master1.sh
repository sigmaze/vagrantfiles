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


function creatingMaster() {
    # docker info | grep -i cgroup
    #master node part only if wrong dirver is used for docker
    # cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    # sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    # systemctl daemon-reload
    # systemctl restart kubelet

    #master 
    fixingIssueOnVagrant 

    
    #pod-network-cidr required for flanel
    log Starting kubeadm init
    kubeadm init --apiserver-advertise-address=$(ifconfig eth2|grep 'inet '|awk '{print $2}') --apiserver-cert-extra-sans $(ifconfig eth1|grep 'inet '|awk '{print $2}') $(ifconfig eth0|grep 'inet '|awk '{print $2}') --pod-network-cidr='10.244.0.0/16'
    # kubeadm init --apiserver-cert-extra-sans $(ifconfig eth1|grep 'inet '|awk '{print $2}') $(ifconfig eth0|grep 'inet '|awk '{print $2}') --pod-network-cidr='10.244.0.0/16'
   
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
     # deplying flannel
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    
}

function SaveK8Sfiles() {

 mkdir -p ${SAVE_DIR}
 while : ; do
    log "waiting for token ..."
    kubeadm token list|head -n 2|tail -n 1|awk {'print $1'} > ${SAVE_DIR}/k8s_api_token
    [[ -s "${SAVE_DIR}/k8s_api_token" ]] && break;
 done
 while : ; do
    log "waiting for port ..."
    netstat -lnp|grep kube-apiserver|awk -F':' {'print $4'} > ${SAVE_DIR}/k8s_api_port
    [[ -s "${SAVE_DIR}/k8s_api_port" ]] && break
 done
 
 
while : ; do
    log "waiting for k8s_sha256 ..."
    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //' > ${SAVE_DIR}/k8s_sha256
    [[ -s "${SAVE_DIR}/k8s_sha256" ]] && break
 done
 
 
 
 cp -f /root/.kube/config ${SAVE_DIR}/k8s_config
}


function GetFiles(){
ssh -o StrictHostKeyChecking=no  192.168.99.100 "echo $(whoami)"

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
    # yum update -y
    
    
    
    
    log Initializing your master

    creatingMaster || return 1
    log saving k8s files 
    SaveK8Sfiles

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

