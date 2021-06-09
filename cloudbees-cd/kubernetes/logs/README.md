Simple Log Utility to fetch/copy Logs from CBCD components from deployed namespaces. 
Pre-Requisite:
    kubectl installed and configured.


    ➜  logs git:(master) ✗ ./get-logs.sh -help
    
        Usage:
            -n Namespace: The name of the kubernetes namespace/project where CBCD/SDA is deployed
            -c (Optional) Component: The name of component to fetch logs. defaults to all
                  all, flow-server, flow-web, flow-devopsinsight, flow-bound-agent, flow-agent
            -o (Optional)Output path to copy logs. default is /tmp.
            -k (Optional)Kubeconfig file path to connect to k8s cluster.
    
        Examples:
            ./get-logs.sh -n flow-demo
            ./get-logs.sh -n flow-demo -c all -o /tmp/flow-logs
            ./get-logs.sh -n flow-demo -c flow-server -o /tmp/flow-logs
            ./get-logs.sh -n flow-demo -c flow-server -k /home/foo/kubeconfigfile