# Restore Master from Backup
This script is designed to perform a restoration of a Master instance in CloudBees Core modern.
It follows the process outlined in documentation: https://docs.cloudbees.com/docs/admin-resources/latest/backup-restore/restoring-manually


## Pre-Requistes
- By default the ownership ID of the jenkins user inside of the cjoc container is 1000. This script assumes this remains the same.
- This script assumes backups are saved in tar.gz format.
- The local environment which this script is executed in must have aws and kubectl commands available and authorized.
- AWS access from the local command line must have access to download from the associated/configured S3 bucket containing the backup file.
- The rescue container must have the tar command tool installed.
- The rescue container must have privileges to change ownership and permissions of files in the /tmp directory.
- The rescue container must be able to mount the team master persistent volume.

## Run
Configure the config file and run this script using `bash masterRestore.sh`.
Alternatively run the script using the parameters `bash masterRestore.sh $namespace $masterStatefulsetName $s3Bucket $backupFilePath $rescueContainerImage`.
