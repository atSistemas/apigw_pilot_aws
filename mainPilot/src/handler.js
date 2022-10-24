'use strict';

const AWS = require("aws-sdk");
const cognito = new AWS.CognitoIdentityServiceProvider({ apiVersion: '2016-04-18' });
let simplecachePet = [];
const lambda = new AWS.Lambda({
  region: process.env.region  
});


module.exports.pilot = async (event) => {

  
  //Get user from cognito
  const resp = await cognito.describeUserPoolClient({
    UserPoolId: process.env.USER_POOL_ID,
    ClientId: event.requestContext.authorizer.claims.client_id
  }).promise();
  // Comprueba si la lista de scopes recibida en el token es igual a la lista de scopes recogida de Cognito
  console.log("Contenido de event: " + JSON.stringify(event))
  console.log("scopes to client : " + resp.UserPoolClient.AllowedOAuthScopes);
  const checklistScopes = await checkListScopes(resp.UserPoolClient.AllowedOAuthScopes, event.requestContext.authorizer.claims.scope);
  if (!checklistScopes)
    return validationMessage("Forbidden, the user config has changed, you must create other access token.", 403)

  if (event.resource === "/pet") {
      console.log("Add a new pet");

      let bodyObject = JSON.parse(event.body)
      console.log("bodyObject: " + bodyObject);

      let result = await executeOperations("api-pilot-" + process.env.myStage + "-create", bodyObject);
      console.log("valor de la respuesta: " + JSON.stringify(result))
      if(result.Payload == "true")
      {        
        simplecachePet.push(bodyObject)
        return buildresponse(null, 200)
      }
      else
      {
        
        return buildresponse(JSON.stringify({ "message": "Error pet created" }), 500)
        
      }
      
  }
  else if(event.resource === "/pet/{petId}" && event.httpMethod === "GET") {
    console.log("Get a pet");
    const petId = event.pathParameters.petId
    let pet = await findObjectCachePet(petId)

    console.log("pet: " + JSON.stringify(pet))
    let result = await executeOperations("api-pilot-" + process.env.myStage + "-get", pet);
    console.log("valor de la respuesta: " + JSON.stringify(result))
    if(result.Payload == "true")
    {
      return buildresponse(JSON.stringify(pet), 200)      
    }
    else
    {
      return buildresponse(JSON.stringify(pet), 204)      
    }  
    
  }
  else if(event.resource === "/pet/{petId}" && event.httpMethod === "DELETE") {
    console.log("Delete a pet");    
    const petId = event.pathParameters.petId
    const pet = await findObjectCachePet(petId)
    let result = await executeOperations("api-pilot-" + process.env.myStage + "-delete", pet);
    if(result.Payload == "true")
    {
      deleteObjectCachePet(petId)
      return buildresponse(null, 200)

    }
    else
    {
      return buildresponse(JSON.stringify({"message": "pet not found to delete"}), 498)
    }
    
  }

};

async function findObjectCachePet(id) {  
  console.log("objetos cacheados " + JSON.stringify(simplecachePet));
  console.log("identificador de mascota " + id)
  
  let found = simplecachePet.find(element => {
    console.log("petId " + id) 
    console.log("element.id " + element.id) 
    if (element.id == id) {
        return element;
    }
  });
  console.log("the pet found: " + JSON.stringify(found))
  
  return found;

}

/**
 * Mensaje para las validaciones en caso de que no tenga permisos.
 * 
 * @param {*} message 
 * @param {*} statusCode 
 */
function buildresponse(body, statusCode) {
  let response = {"isBase64Encoded": false,
                  "statusCode": statusCode,  
  "headers": { "Content-Type": "application/json",
               "Access-Control-Allow-Origin":"*"}}
  if(body)
  {
    response['body']= body
  } 
  return response; 
}  

async function checkListScopes(allowedOAuthScopes, claimsScopes) {
  let responsescopes = true;
  const arrayclaimScopes = claimsScopes.split(" ");

  await arrayclaimScopes.forEach(scope => {
    if (!allowedOAuthScopes.includes(scope))
      responsescopes = false;
  })

  return responsescopes;

}

async function executeOperations(functionName, body) {

  const params = {
    FunctionName: functionName,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify(body)
  };

  return new Promise((resolve, reject) => {
    lambda.invoke(params, function (error, data) {
      if (error) {
        console.error(JSON.stringify(error));
        reject(error);
      } else if (data) {
        resolve(data);
      }
    })
  });
  
}
async function deleteObjectCachePet(id)
{
  let index = -1;
  const isContain = (element) => element.id === id;
  index = simplecacheClient.findIndex(isContain)

  if (index !== -1) {
    console.log("El objeto en posición " + index + " va a ser eliminado");
    simplecacheClient.splice(index, 1);
  }

}

