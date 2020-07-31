#!/bin/bash
set -e

namespace=$1 #Kubernetes namespace where master is deployed.
masterStatefulsetName=$2 #The statefulset name of the master deployment.
s3Bucket=$3 #S3 bucketname containing backups.
backupFilePath=$4 #Path of the tar.qz file within the S3 bucket.
rescueContainerImage=$5 #Container with version if required, to use for the rescue pod.

if [ -z $namespace ] || [ -z $masterStatefulsetName ] || [ -z $s3Bucket ] || [ -z $backupFilePath ] || [ -z $rescueContainerImage ]
then
  echo "Execution parameters missing. Loading variables from config file."
  source config
fi

echo "Scale down Master pods to 0 replicas"
kubectl --namespace=$namespace scale statefulset/$masterStatefulsetName --replicas=0

#Launch rescue pod attaching the pvc
persistentVolumeClaim=$(kubectl -n $namespace get statefulset $masterStatefulsetName -o jsonpath="{.spec.volumeClaimTemplates[0].metadata.name}")-${masterStatefulsetName}-0
echo "Launching rescue-pod with pvc $persistentVolumeClaim attached"

cat <<EOF | kubectl --namespace=$namespace create -f -

kind: Pod
apiVersion: v1
metadata:
  name: rescue-pod
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  volumes:
    - name: rescue-storage
      persistentVolumeClaim:
        claimName: $persistentVolumeClaim
  containers:
    - name: rescue-container
      image: $rescueContainerImage
      command: ['sh', '-c', 'echo The app is running! && sleep 100000' ]
      volumeMounts:
        - mountPath: "/tmp/jenkins-home"
          name: rescue-storage
EOF

echo "Downloading the backup file from S3 into local /tmp directory"
aws s3 cp s3://${s3Bucket}/${backupFilePath} /tmp/backup.tar.gz

echo "Waiting for the rescue-pod to enter Ready state"
kubectl wait --namespace=$namespace --for=condition=Ready --timeout=600s pod/rescue-pod

echo "Moving the backup file into the rescue-pod"
kubectl cp --namespace=$namespace /tmp/backup.tar.gz rescue-pod:/tmp/

echo "Empty /tmp/jenkins-home of all files and folders on pvc $persistentVolumeClaim"
kubectl exec --namespace=$namespace rescue-pod -- find /tmp/jenkins-home -type f -name "*.*" -delete || echo "Files deleted in jenkins-home"
kubectl exec --namespace=$namespace rescue-pod -- find /tmp/jenkins-home -type f -name "*" -delete || echo "Files deleted in jenkins-home"
kubectl exec --namespace=$namespace rescue-pod -- find /tmp/jenkins-home/ -mindepth 1 -type d -name "*" -exec rm -rf {} \; || echo "Folders deleted in jenkins-home"

echo "Uncompress the backup file into /tmp/jenkins-home"
kubectl exec --namespace=$namespace rescue-pod -- tar -xzf /tmp/backup.tar.gz --directory /tmp/jenkins-home

echo "Update ownership permissions recursively"
kubectl exec --namespace=$namespace rescue-pod -- chown -R 1000:1000 /tmp/jenkins-home

echo "Deleting the rescue-pod"
kubectl --namespace=$namespace delete pod rescue-pod

echo "Scale up pods to 1 replica"
kubectl --namespace=$namespace scale statefulset/$masterStatefulsetName --replicas=1
