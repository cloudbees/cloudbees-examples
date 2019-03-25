# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for Bitbucket.org

This example shows how to add authentication to Bitbucket.org. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core.

````
type: MULTIBRANCH
...

multibranch:
  branchSource:
    bitbucket:
      remote: https://bitbucket.org
      repoOwner: myCompany
      repository: ${repoName}
      credentialsId: my-team-bitbucket-credentials
````