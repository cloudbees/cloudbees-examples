### Create an EKS cluster for CloudBees CD installation in `demo` mode

All the steps to create an environment are not a recommendation for production use.
All the steps below are optional and are for informational purposes only and are provided as an example for quickly setting up an infrastructure to install CD on k8s.
Be sure to follow the security policies and rules of your organization.

- Create EKS cluster by following the [eksctl documentation](https://eksctl.io/getting-started/)
```bash
# Download the EKS demo.yaml file
EKS_FILE_URL=https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/eks/cd-cluster-eks.yaml
curl -fsSL -o cd-cluster-eks.yaml $EKS_FILE_URL

# Set the cluster name and region
CLUSTER=cd-cluster
REGION=us-east-1

# Replace the cluster name and region in the demo.yaml file
sed "s/<CLUSTER>/$CLUSTER/g; s/<REGION>/$REGION/g" < cd-cluster-eks.yaml > $CLUSTER-$REGION-eks.yaml

# Create the EKS cluster using eksctl
eksctl create cluster -f $CLUSTER-$REGION-eks.yaml
```
- Create and connect EFS
```bash
# Set EFS Security Group Name and Description
VPC_ID=$(aws eks describe-cluster \
    --name $CLUSTER \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
CIDR_BLOCK=$(aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[].CidrBlock" \
    --output text)
EFS_SG_NAME="$CLUSTER-eks-efs-sg"
EFS_SG_DESC="NFS access to EFS from $CLUSTER EKS worker nodes"

# Create EFS Security Group
aws ec2 create-security-group \
    --group-name $EFS_SG_NAME \
    --description "$EFS_SG_DESC" \
    --vpc-id $VPC_ID

# Get EFS Security Group ID
EFS_SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=$EFS_SG_NAME \
    --query "SecurityGroups[*].{ID:GroupId}" --output text)

# Set EFS Security Group rules
aws ec2 authorize-security-group-ingress \
    --group-id $EFS_SG_ID \
    --protocol tcp \
    --port 2049 \
    --cidr $CIDR_BLOCK

# Set EFS Name and Description
EFS_NAME="$CLUSTER-eks-efs";
EFS_DESC="EFS for $CLUSTER EKS";

# Get Subnet IDs
SUBNET_ID1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" \
    --query 'Subnets[0].{ID:SubnetId}' \
    --output text)
SUBNET_ID2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" \
    --query 'Subnets[1].{ID:SubnetId}' \
    --output text)

# Create EFS
EFS_ID=$(aws efs create-file-system \
    --creation-token $EFS_NAME \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --tags Key=Name,Value=$EFS_NAME \
    --encrypted \
    --query "FileSystemId" \
    --output text)

# Create EFS Mount Target
EFS_MOUNT_TARGET_ID=$(aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $SUBNET_ID1 \
    --security-group $EFS_SG_ID \
    --query "MountTargetId" \
    --output text)

# Get EFS IP
EFS_MOUNT_TARGET_IP=$(aws efs describe-mount-targets \
    --mount-target-id $EFS_MOUNT_TARGET_ID \
    --query "MountTargets[*].{DNS:IpAddress}" \
    --output text)

# Install nfs-subdir-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update

STORAGE_CLASS=efs-sc
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace storage \
    --create-namespace \
    --set nfs.server=$EFS_MOUNT_TARGET_IP \
    --set nfs.path=/ \
    --set storageClass.name=$STORAGE_CLASS
```
- Create and connect RDS
```bash
# Set RDS Security Group Name and Description
RDS_SG_NAME="$CLUSTER-eks-rds-sg";
RDS_SG_DESC="RDS access to $CLUSTER EKS worker nodes"

# Create RDS Security Group
aws ec2 create-security-group \
    --group-name $RDS_SG_NAME \
    --description "$RDS_SG_DESC" \
    --vpc-id $VPC_ID
    
# Get RDS Security Group ID
RDS_SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=$RDS_SG_NAME \
    --query "SecurityGroups[*].{ID:GroupId}" \
    --output text)

# Set RDS Security Group rules
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --cidr $CIDR_BLOCK

# Create RDS Subnet Group
aws rds create-db-subnet-group \
    --db-subnet-group-name $CLUSTER-eks-rds-subnet-group \
    --db-subnet-group-description "Subnet group for $CLUSTER EKS RDS" \
    --subnet-ids $SUBNET_ID1 $SUBNET_ID2 \
    --tags Key=Name,Value=$CLUSTER-eks-rds-subnet-group \
    --no-cli-pager

# Create RDS
DB_PASSWORD=<DB_PASSWORD>
DB_USER=postgres

aws rds create-db-instance \
    --db-instance-identifier $CLUSTER-eks-rds \
    --db-instance-class db.t3.medium \
    --engine postgres \
    --allocated-storage 20 \
    --db-subnet-group-name $CLUSTER-eks-rds-subnet-group \
    --master-username $DB_USER \
    --master-user-password $DB_PASSWORD \
    --vpc-security-group-ids $RDS_SG_ID \
    --backup-retention-period 0 \
    --no-publicly-accessible \
    --no-multi-az \
    --no-auto-minor-version-upgrade \
    --no-copy-tags-to-snapshot \
    --tags Key=Name,Value=$CLUSTER-eks-rds \
    --no-cli-pager

# Wait for RDS to be available
aws rds wait db-instance-available \
    --db-instance-identifier $CLUSTER-eks-rds

# Get RDS Endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $CLUSTER-eks-rds \
    --query "DBInstances[*].{Endpoint:Endpoint.Address}" \
    --output text)

# Create Database
DB_NAME=flow
DB_PORT=5432
kubectl run postgresql-client \
    --rm --tty -i --restart='Never' \
    --namespace default \
    --image bitnami/postgresql \
    --env="PGPASSWORD=$DB_PASSWORD" \
    --command -- psql -h $RDS_ENDPOINT -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"
```
### CloudBees CD installation

- Download production values file
```bash
curl -fsSL -o cd-cluster-helm-values.yaml https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-prod.yaml
  ```
- Create k8s namespace
```bash
NAMESPACE=cd-cluster
kubectl create namespace $NAMESPACE
  ```
- Create db credentials secret
```bash
kubectl create secret generic flow-db-secret \
    --namespace $NAMESPACE \
    --from-literal=DB_USER=$DB_USER \
    --from-literal=DB_PASSWORD=$DB_PASSWORD
  ```
- Set db connection parameters in the cd-cluster-helm-values.yaml file
```yaml
database:
  dbType: postgresql
  externalEndpoint: <RDS_ENDPOINT>
  dbName: <DB_NAME>
  dbPort: 5432
  existingSecret: flow-db-secret
```
- Create server admin secret
```bash
CD_SERVER_ADMIN_PASSWORD=<your-password-for-admin-user>
HELM_RELEASE=cd-cluster
kubectl create secret generic $HELM_RELEASE-cloudbees-flow-credentials \
    --namespace $NAMESPACE \
    --from-literal=CBF_SERVER_ADMIN_PASSWORD=$CD_SERVER_ADMIN_PASSWORD
```
- Install CD from cloudbees CD Helm repo
```bash 
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo update
                           
LICENSE=<relative-or-absolute-path-to-license-file>  # e.g LICENSE=~/cd/cloudbees-flow-license.xml

# Install CD Server
helm install $HELM_RELEASE cloudbees/cloudbees-flow \
    --namespace $NAMESPACE \
    --values cd-cluster-helm-values.yaml \
    --set flowCredentials.existingSecret=$HELM_RELEASE-cloudbees-flow-credentials \
    --set boundAgent.flowCredentials.existingSecret=$HELM_RELEASE-cloudbees-flow-credentials \
    --set storage.volumes.serverPlugins.storageClass=$STORAGE_CLASS \
    --set-file flowLicense.licenseData=$LICENSE \
    --timeout 4200s
```
- Get the URL of the CD server and the generated password for `admin` user
  ```bash
  LB_HOST=$(kubectl get service $HELM_RELEASE-ingress-nginx-controller \
    -n $NAMESPACE \
    -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
  echo "Available at: https://$LB_HOST/flow/"
  ``` 

[Example of installation CD agent helm charts](../common/agents.md)

### Cleanup

- Delete CD Server
```bash
helm uninstall $HELM_RELEASE -n $NAMESPACE
``` 
- Delete RDS
```bash
# Delete RDS
aws rds delete-db-instance --db-instance-identifier $CLUSTER-eks-rds --skip-final-snapshot --no-cli-pager

# Wait for RDS to be deleted
aws rds wait db-instance-deleted --db-instance-identifier $CLUSTER-eks-rds

# Delete RDS Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name $CLUSTER-eks-rds-subnet-group

# Delete RDS Security Group
aws ec2 delete-security-group --group-id $RDS_SG_ID
```  

- Delete EFS
```bash
aws efs delete-mount-target --mount-target-id $EFS_MOUNT_TARGET_ID
aws efs delete-file-system --file-system-id $EFS_ID

aws ec2 delete-security-group --group-id $EFS_SG_ID
```
- Delete EKS cluster
   ```bash
   eksctl delete cluster --name $CLUSTER --disable-nodegroup-eviction
  ```