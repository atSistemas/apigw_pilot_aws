# **apigw_pilot_aws**
Demo Create APIs on APIGateway AWS

## **Project Structure.**  ##

```
  .apigw_pilot_aws
    |
    |__ deploydocOpenAPI
    |
    |__ mainPilot
    |
    |__ publishAPI
    

```

### **mainPilot** ###

Subdirectory that will contain a serverless project, where all the source code that will accommodate the functional core of each of our APIs will be contemplated.

The mainPilot directory will be the main subdirectory of the project that will handle the full deployment of the solution. It will be comprised of three subdirectories:

   - **environment**: Directory that will contain the configuration files with information depending on the environment
   - **script**: Directory that it will have the sh file in charge of orchestrating the execution of all the components that can be deployed in the cloud
   - **src**: Directory where the different lambda functions will be collected with the implementation of the source code

**Serverless.yml**: Serverless project descriptor file, where the project definition will be collected, along with each of the lambda functions that will contain the source code to cover each of the API operations.
  



### **publishAPI** ###

Subdirectory that will have the openapi.json template file with the definition of the contract for all the operations to be published within the API that we want to create.
The creation of the openapi file and the publication of the API from the file is managed from the “publishAPI” subdirectory, which is comprised of the following directories:

 - **api-model**: Directory that will contain the openapi.json template file from which the final resulting openapi file will be generated for the publication of the API on the AWS API Gateway.
 - **environment**: Directory containing environment-dependent configuration files.
 - **script**: It contains the sh scripts that come to cover the association of the scopes of the cognito scope for the api operations, the association of permissions on the lambdas functions on which the requests will be delegated and the publication and deployment of the api from the resulting openapi file. final .

#### **deploydocOpenAPI** ###

The final openapi.json file will be generated on the indicated subdirectory, for publication on a web server, accessible by API consumer clients.
The publication of the openapi file with the operations contract is included in the deploydocOpenAPI directory. This directory is dissected into three subdirectories:

  - **environment**: Directory that includes the configuration files dependent on the environment. URL getToken
  - **script**: sh script that obtains the final resulting openapi file to feed it with the url to generate and obtain the token, ready for publication of the document in the s3 bucket
  - **static**:  Directory on which the final openapi document will be deposited

The root level directory initializes a serverless project to allow for publishing and deploying the openapi file to an s3 bucket.


## **Environment Variable**  ##

  - userPoolId: Identifier userPool that will be used to secure the API.
  - region: Region in aws on which the API will be deployed.
  - lambdaRouter: Name of the router lambda to which all API input requests will be delegated and which will be hooked up with the API Gateway service for our API.
  - stageName: Name of the stage used to publish our API.
  - resourceServerName: Name of the server resource used in Cognito.
  - tokenUrl: Url to create cognito token auth to operation api. 
