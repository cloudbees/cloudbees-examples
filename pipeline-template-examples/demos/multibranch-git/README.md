# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for a Git Server

This example shows how to add authentication to your Git server. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core, and Pipeline Templates then use the developer's value to replace the placeholder variable in the Jenkinsfile.

````
multibranch:
  branchSource:
    git:
      remote: ${repoUrl}
      credentialsId: my-team-git-credentials
````