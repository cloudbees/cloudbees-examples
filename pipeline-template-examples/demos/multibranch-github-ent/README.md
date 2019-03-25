# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for Github Enterprise

This example shows how to add authentication to your Github Enterprise repository. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core.

````
type: MULTIBRANCH
...

multibranch:
  branchSource:
    github:
      apiUrl: https://github.beescloud.com/api/v3
      repoOwner: myCompany
      repository: ${repoName}
      scanCredentialsId: my-team-github-credentials
````