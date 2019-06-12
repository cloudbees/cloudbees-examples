# CloudBees Pipeline Templates Example
## Multibranch Pipeline Authentication for Github.com

This example shows how to add authentication to Github.com. The developer will supply the value for the ${repoName} parameter when they create their pipeline job in CloudBees Core, and Pipeline Templates then use the developer's value to replace the placeholder variable in the Jenkinsfile.

````
multibranch:
  branchSource:
    github:
      repoOwner: myCompany
      repository: ${repoName}
      credentialsId: my-team-github-credentials
````