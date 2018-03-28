#!/bin/bash
# Author: sigmaze

###################
##General Functions and Varaibles:


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
LOG_DIR="${SCRIPT_DIR}/${SCRIPT_NAME%%.sh}.log"


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

function startProvisioning() {
    log Started script on $(whoami)
    log installing docker
    yum install -y docker
    systemctl enable docker && systemctl start docker
 
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
	startProvisioning && exit 0
	
fi

