
# Simple Log Utility to fetch/copy Logs for CBCD components from deployed kubernetes/openshift namespaces. 

## Prerequisite:
    1. CD/RO or Software Delivery Automation deployed on Kubernetes platform.
    2. Install kubectl https://kubernetes.io/docs/tasks/tools/ 


## How it works

    $> bash get-logs.sh -help
    
        Usage:
            -n Namespace: The name of the Kubernetes namespace/project where CD/RO or Software Delivery Automation is deployed
            -c (Optional) Component: The name of component to fetch logs. defaults to all
                  all, flow-server, flow-web, flow-devopsinsight, flow-bound-agent, flow-agent
            -o (Optional)Output path to copy logs. default is /tmp.
            -k (Optional)Kubeconfig file path to connect to k8s cluster.
    
 ##  Examples:
        ./get-logs.sh -n <namespace> -c <Component>  -o <output-path> -k <kube-config path>
        ./get-logs.sh -n flow-demo -c all -o /tmp/flow-logs
        ./get-logs.sh -n flow-demo -c flow-server -o /tmp/flow-logs
        ./get-logs.sh -n flow-demo -c flow-server -k /home/foo/kubeconfigfile
