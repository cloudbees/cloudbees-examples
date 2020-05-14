#!/bin/bash
bold="$(tput bold)"
normal="$(tput sgr0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"
magenta="$(tput setaf 5)"
underline="$(tput smul)"
function main {
    _parse_args "$@"

    if [[ ! -z $ACTION ]]
    then
        if [[ $ACTION == "create" ]]; then
            _create
        elif [[ $ACTION == "delete" ]]; then
            _delete
        fi
    else
        echo "Provide valid action"
        _usage
    fi

}

function _create {
    _parse_args "$@" 

    echo "" > ./vars.tfvars
    echo "project = \"$PROJECT\"" >> ./vars.tfvars
    echo "location = \"$LOCATION\"" >> ./vars.tfvars
    echo "fs-name = \"$FS_NAME\"" >> ./vars.tfvars
    if [[ -z $TIER ]]; then
        echo "tier = \"STANDARD\"" >> ./vars.tfvars
    else
        echo "tier = \"$TIER\"" >> ./vars.tfvars
    fi
    if [[ -z $CAPACITY ]]; then
        echo "capacity = 1024" >> ./vars.tfvars
    else
        echo "capacity = $CAPACITY" >> ./vars.tfvars
    fi
    echo "fs-network = \"$FS_NETWORK\"" >> ./vars.tfvars
    if [[ -z $MOUNT_PATH ]]; then
        echo "filestore = \"filestore\"" >> ./vars.tfvars
    else
        echo "filestore = \"$MOUNT_PATH\"" >> ./vars.tfvars
    fi

    if [[ -z $PROJECT ]] && [[ -z $LOCATION ]] && [[ -z $FS_NAME ]] && [[ -z $FS_NETWORK ]]
    then
        echo "Provide valid values"
        _usage
    else 
        terraform init
        terraform apply --var-file="vars.tfvars" --auto-approve 
        FS_IP=$(terraform output fs_ip)
        echo "${bold}+++++++++Use below information to deploy helm chart+++++++++${normal}"
        echo "${bold}2) File System IP ====> ${green}${underline}$FS_IP${normal}"
        echo "+++++++++Deployment through helm+++++++++"
        echo "${bold}1) helm repo add stable https://kubernetes-charts.storage.googleapis.com/${normal}"
        echo "${bold}2) helm repo update${normal}"
        echo "${bold}3) helm install nfs-provisioner stable/nfs-client-provisioner --namespace kube-system --set nfs.server=$FS_IP --set nfs.path=/filestore${normal}"
    fi
}

function _delete {
    _parse_args "$@"
    echo "" > ./vars.tfvars
    echo "project = \"$PROJECT\"" >> ./vars.tfvars
    echo "location = \"$LOCATION\"" >> ./vars.tfvars
    echo "fs-name = \"$FS_NAME\"" >> ./vars.tfvars
    if [[ -z $TIER ]]; then
        echo "tier = \"STANDARD\"" >> ./vars.tfvars
    else
        echo "tier = \"$TIER\"" >> ./vars.tfvars
    fi
    if [[ -z $CAPACITY ]]; then
        echo "capacity = 1024" >> ./vars.tfvars
    else
        echo "capacity = $CAPACITY" >> ./vars.tfvars
    fi
    echo "fs-network = \"$FS_NETWORK\"" >> ./vars.tfvars
    if [[ -z $MOUNT_PATH ]]; then
        echo "filestore = \"filestore\"" >> ./vars.tfvars
    else
        echo "filestore = \"$MOUNT_PATH\"" >> ./vars.tfvars
    fi


    if [[ -z $PROJECT ]] && [[ -z $LOCATION ]] && [[ -z $FS_NAME ]] && [[ -z $FS_NETWORK ]]
    then
        echo "Provide valid values"
        _usage
    else 
        terraform init
        terraform destroy --var-file="vars.tfvars" --auto-approve 
        STATUS=$(echo $?)
    fi
}

function _usage {

    printf "Script will be used to provision filestore instance.\n
    usage:
        ./filestore.sh --action <create|delete> --project <project name> --location <location like us-east1> --fs-name <filestore name> --fs-network <network name like default>"
}

_parse_args() {
    if [ $# != 0 ]; then
        while true ; do
        case "$1" in
            --help)
                _usage
                exit 0
            ;;
            --action)
                ACTION=$2
                shift 2
            ;;
            --project)
                PROJECT=$2
                shift 2
            ;;
            --location)
                LOCATION=$2
                shift 2
            ;;
            --fs-name)
                FS_NAME=$2
                shift 2
            ;;
            --tier)
                TIER=$2
                shift 2
            ;;
            --capacity)
                CAPACITY=$2
                shift 2
            ;;
            --fs-network)
                FS_NETWORK=$2
                shift 2
            ;;
            --path)
                MOUNT_PATH=$2
                shift 2
            ;;
            *)
                echo "unrecognized or invalid option %s" "$1"
                break
            ;;
        esac
        done
    fi
}

main "$@"