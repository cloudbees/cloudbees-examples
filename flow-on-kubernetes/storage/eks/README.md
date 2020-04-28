## Provision Shared Storage Service (EFS) on AWS

After running the script successfully, the terminal displays commands to deploy the Helm chart,

### Prerequisite

Python 2 version 2.7+ or Python 3 version 3.4+

1. Install the AWS cli:

    ```shell
    pip3 install awscli
    ```

2. Configure the AWS cli:

    ```shell
    aws configure
        AWS Access Key ID: <AWS Access Key ID>
        AWS Secret Access Key: <AWS Secret Access Key>
        Default region name: <region>
        Default output format: <text|table|json>
    ```

3. Run the script:

    ```shell
    ./efs-provision.sh --action <create|delete> \
        --efs-name <name> \
        --vpc-id <vpc-id> \
        --region <region>
    ```
where:

`action`              =   create | delete

`efs-name`            =   efs name

`vpc-id`              =   vpc id

`region`              =   region

`performance-mode`    =   generalPurpose | `maxIO` (Optional)

`throughput-mode`     =   provisioned | `bursting` (Optional)

`throughput`          =   in mbps, Only if `--throughput` is provisioned
                                                                   
4. Deploy helm chart

    ```shell
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    helm repo update
    helm install <name> stable/efs-provisioner \
                --set efsProvisioner.efsFileSystemId=<file system id> \
                --set efsProvisioner.awsRegion=<region> \
                --set efsProvisioner.dnsName=<filesystem ip>
```

