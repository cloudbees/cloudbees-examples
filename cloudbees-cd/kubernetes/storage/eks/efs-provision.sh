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
        else 
            echo "provide valid action"
            _usage
        fi
    else
        echo "Provide valid action"
        _usage
    fi

}

function _create {
    _parse_args "$@" 

    echo "" > ./vars.tfvars
    echo "efs_name = \"$EFS_NAME\"" >> ./vars.tfvars
    echo "vpc_id = \"$VPC_ID\"" >> ./vars.tfvars
    echo "region = \"$REGION\"" >> ./vars.tfvars
    if [[ -z $PERFORMANCE_MODE ]]; then
        echo "performance_mode = \"generalPurpose\"" >> ./vars.tfvars
    else
        echo "performance_mode = \"$PERFORMANCE_MODE\"" >> ./vars.tfvars
    fi
    if [[ -z $THROUGHPUT_MODE ]]; then
        echo "throughput_mode = \"bursting\"" >> ./vars.tfvars
    else
        echo "throughput_mode = \"$THROUGHPUT_MODE\"" >> ./vars.tfvars
    fi
    echo "throughput = \"$THROUGHPUT\"" >> ./vars.tfvars

    if [[ -z $EFS_NAME ]] && [[ -z $VPC_ID ]] && [[ -z $REGION ]] && [[ -z $THROUGHPUT ]]
    then
        echo "Provide valid values"
        _usage
    else 
        terraform init
        terraform apply --var-file="vars.tfvars" --auto-approve 
        echo "${bold}+++++++++Use below information to deploy helm chart+++++++++${normal}"
        FS_IP=$(terraform output mount_target_ips)
        FS_ID=$(terraform output filesystem-id)
        echo "${bold}1) File System ID ====> ${green}${underline}$FS_ID${normal}"
        echo "${bold}2) File System IP ====> ${green}${underline}$FS_IP${normal}"
        echo "${bold}3) Region         ====> ${green}${underline}$REGION${normal}"
        echo "+++++++++Deployment through helm+++++++++"
        echo "${bold}1) helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
        echo "${bold}2) helm repo update${normal}"
        echo "${bold}3) helm install efs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace kube-system --set efsProvisioner.efsFileSystemId=$FS_ID --set efsProvisioner.awsRegion=$REGION --set efsProvisioner.dnsName=$FS_IP${normal}"
    fi
}



function _delete {
    _parse_args "$@"

    echo "" > ./vars.tfvars
    echo "efs_name = \"$EFS_NAME\"" >> ./vars.tfvars
    echo "vpc_id = \"$VPC_ID\"" >> ./vars.tfvars
    echo "region = \"$REGION\"" >> ./vars.tfvars
    if [[ -z $PERFORMANCE_MODE ]]; then
        echo "performance_mode = \"generalPurpose\"" >> ./vars.tfvars
    else
        echo "performance_mode = \"$PERFORMANCE_MODE\"" >> ./vars.tfvars
    fi
    if [[ -z $THROUGHPUT_MODE ]]; then
        echo "throughput_mode = \"bursting\"" >> ./vars.tfvars
    else
        echo "throughput_mode = \"$THROUGHPUT_MODE\"" >> ./vars.tfvars
    fi
    echo "throughput = \"$THROUGHPUT\"" >> ./vars.tfvars

    if [[ -z $EFS_NAME ]] && [[ -z $VPC_ID ]] && [[ -z $REGION ]] && [[ -z $THROUGHPUT ]]
    then
        echo "Provide valid values"
        _usage
    else 
            terraform init
            terraform apply --var-file="vars.tfvars" --auto-approve
    fi
}

function _usage {

    printf "Script will be used to provision efs. \nIt will use aws secret key and secret access key stored in machine.\n
    usage:
        ./efs-provision.sh --action <create|delete> --efs-name <name> --vpc-id <vpc-xxxxx> --region <region> --throughput <in mbps, Only of --throughput is provisioned> "
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
            --vpc-id)
                VPC_ID=$2
                shift 2
            ;;
            --region)
                REGION=$2
                shift 2
            ;;
            --performance-mode)
                PERFORMANCE_MODE=$2
                shift 2
            ;;
            --throughput-mode)
                THROUGHPUT_MODE=$2
                shift 2
            ;;
            --throughput)
                THROUGHPUT=$2
                shift 2
            ;;
            --efs-name)
                EFS_NAME=$2
                shift 2
            ;;
            --chart-name)
                EFS_PROVISIONER=$2
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