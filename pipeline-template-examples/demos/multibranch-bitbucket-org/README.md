# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for Bitbucket.org

This example shows how to add authentication to Bitbucket.org. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core, and Pipeline Templates then use the developer's value to replace the placeholder variable in the Jenkinsfile.

````
multibranch:
  branchSource:
    bitbucket:
      serverUrl: https://bitbucket.org
      repoOwner: myCompany
      repository: ${repoName}
      credentialsId: my-team-bitbucket-credentials
````