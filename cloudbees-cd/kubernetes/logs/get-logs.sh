#! /bin/bash


kctl() {
   if [ ! -z $KUBE_CONFIG_PATH ] ; then
    kubectl --kubeconfig $KUBE_CONFIG_PATH  -n $NAMESPACE "$@"
   else
    kubectl -n $NAMESPACE "$@"
   fi
}

function get_logs
{
  C_FETCH="flow"
  if [ $COMPONENT == "all" ] ; then
    C_FETCH="flow"
  else
    C_FETCH=$COMPONENT
  fi
  for i in $(kctl get po|awk '{print $1}'|awk 'NR!=1'|grep $C_FETCH)
   do
   echo "Fetching logs for $i"
   echo "Creating Directory $OUTPUT/$i/logs"
   mkdir -p $OUTPUT/$i/logs
   echo "Copying logs from $i to  $OUTPUT/$i/logs"
   kctl cp $i:/opt/cbflow/logs $OUTPUT/$i/logs
   done

}
function initScript
{
    NAMESPACE=""
    COMPONENT="all"
    OUTPUT="/tmp"
    KUBE_CONFIG_PATH=""
    while getopts h:n:c:o:k: opt
        do
           case "$opt" in
              h) usage "";exit 1;;
              n) NAMESPACE=$OPTARG;;
              c) COMPONENT=$OPTARG;;
              o) OUTPUT=$OPTARG;;
              k) KUBE_CONFIG_PATH=$OPTARG;;
              \?) usage "";exit 1;;
           esac
        done
    if  [ -z $NAMESPACE ] ;
        then
            echo "$(date) Make sure you provide valid -n NAMESPACE"
            usage ""
            exit 1;
    fi

}

function usage
{
    cat <<EOF

    Usage:
        ./get-logs.sh -n <Namespace> -c <Component>  -o <Output> -k <kubeconfig-file-path>

    Options:
        -n Namespace: The name of the Kubernetes namespace/project where CD/RO or Software Delievery Automation is deployed
        -c (Optional) Component: The name of component to fetch logs. defaults to all
              all, flow-server, flow-web, flow-devopsinsight, flow-bound-agent, flow-agent
        -o (Optional)Output path to copy logs. default is /tmp.
        -k (Optional)kubeconfig  file path to connect to k8s cluster.

    Examples:
        ./get-logs.sh -n flow-demo
        ./get-logs.sh -n flow-demo -c all -o /tmp/flow-logs
        ./get-logs.sh -n flow-demo -c flow-server -o /tmp/flow-logs
        ./get-logs.sh -n flow-demo -c flow-server -k /home/foo/kubeconfigfile
EOF
}

function main
{
  initScript "$@"
  kctl get ns $NAMESPACE
  exit_code=$?
  if  [ $exit_code != 0 ];
      then
          echo "$(date) Please set valid namespace "
          echo "$(date) Please check kubectl configuration is set correctly. Logging utility not able to reach to k8s cluster"
          echo "$(date) Please set valid kubeconfig file if exist "
          exit 1;
  fi
  get_logs "$@"
}

main "$@"
