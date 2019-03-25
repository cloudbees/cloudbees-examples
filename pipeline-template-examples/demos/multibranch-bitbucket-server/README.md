# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for a Bitbucket Server

This example shows how to add authentication to your organization's Bitbucket server. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core.

````
type: MULTIBRANCH
...

multibranch:
  branchSource:
    bitbucket:
      remote: https://bitbucket.beescloud.com
      repoOwner: myCompany
      repository: ${repoName}
      credentialsId: my-team-bitbucket-credentials
````