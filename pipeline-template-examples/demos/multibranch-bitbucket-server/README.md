# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for a Bitbucket Server

This example shows how to add authentication to a Bitbucket server. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core, and Pipeline Templates then use the developer's value to replace the placeholder variable in the Jenkinsfile.

````
multibranch:
  branchSource:
    bitbucket:
      serverUrl: https://bitbucket.example.com
      repoOwner: myCompany
      repository: ${repoName}
      credentialsId: my-team-bitbucket-credentials
````
