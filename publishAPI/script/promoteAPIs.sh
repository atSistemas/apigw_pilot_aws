#! /bin/sh

######################################################### START CHECK ENVIRONMENT ##################################################
checkVersionAWSCLI=$(aws --version | grep aws-cli/2 | wc -l)
if [ "$checkVersionAWSCLI" -eq "0" ]; then
   echo "Version de AWS CLI no valida, instale version 2.X:";
   echo "https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
   exit;
fi

if ! type jq > /dev/null; then
    echo "No existe el comando jq, por favor instale la libreria."
    echo "Ubuntu: sudo apt install jq"
    exit;
fi

if ! type tr > /dev/null; then
    echo "No existe el comando tr, por favor instale la libreria."
    exit;
fi

if [ -z "$1" ]
then
      echo "El entorno sobre el que se ejecuta la solución no ha sido informado como parámetro de entrada"
      exit;
fi 

if ! [ -f "environment/env-$1.json" ]; then
    echo "No existe el fichero para el entorno: $1"
    exit;
fi
######################################################### END CHECK ENVIRONMENT ##################################################

######################################################### START PUBLISH API ##################################################
echo "\n\n\nEnvironment: $1 \n"

echo "1. Se crea directorio temporal."
rm -rf "tmp/"
mkdir tmp
echo "$PWD/tmp \n"

echo "2. Se copia fichero fuente openapi para el reemplazo de variables."
cp api-model/openapi.json tmp/openapi-$1.json
echo "$PWD/tmp/openapi-$1.json \n"

echo "3. Se obtienen las configuraciones de entorno:"
userPoolId=$(jq -r '.userPoolId' environment/env-$1.json)
region=$(jq -r '.region' environment/env-$1.json)
stageName=$(jq -r '.stageName' environment/env-$1.json)
lambdaRouter=$(jq -r '.lambdaRouter' environment/env-$1.json)
resourceServerName=$(jq -r '.resourceServerName' environment/env-$1.json)
urlEndpoint=$(jq -r '.url' environment/env-$1.json)

if [ -z $userPoolId ]
then
      echo "El campo userPoolId no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

if [ -z $region ]
then
      echo "El campo region no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

if [ -z $stageName ]
then
      echo "El campo stageName no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

if [ -z $lambdaRouter ]
then
      echo "El campo lambdaRouter no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

if [ -z $resourceServerName ]
then
      echo "El campo resourceServerName no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

if [ -z $urlEndpoint ]
then
      echo "El campo url no ha sido infomado en el fichero de configuración env-$1.json"
      exit;
fi 

echo "userPoolId: $userPoolId"
echo "region: $region"
echo "stageName: $stageName"
echo "lambdaRouter: $lambdaRouter"
echo "resourceServerName: $resourceServerName"
echo "url: $urlEndpoint"

#Se obtiene el userPoolARN de cognito
aws cognito-idp describe-user-pool --user-pool-id $userPoolId --profile ama-$1 --region $region > "tmp/cognito-idp-describe-user-pool-$1-tmp.json"
userPoolARN=$(jq -r '.UserPool.Arn' "tmp/cognito-idp-describe-user-pool-$1-tmp.json")
echo "userPoolARN: $userPoolARN"

#Se compone la URI para la Lambda proxy integrations
aws lambda get-function --function-name $lambdaRouter --profile ama-$1 --region $region > "tmp/lambda-get-function-$1-tmp.json"
lambdaRouterArn=$(jq -r '.Configuration.FunctionArn' "tmp/lambda-get-function-$1-tmp.json")
lambdaProxyUri="arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/"$lambdaRouterArn"/invocations"
echo "lambdaProxyUri: $lambdaProxyUri"

#Obtenermos el account ID.
aws sts get-caller-identity --profile ama-$1 --region $region > "tmp/aws-sts-get-caller-identity-$1-tmp.json"
accountId=$(jq -r '.Account' "tmp/aws-sts-get-caller-identity-$1-tmp.json")
echo "accountId: $accountId"

#Obtenemos el nombre del API."
apiname=$(jq -r '.info.title' tmp/openapi-$1.json)

if [ -z "$apiname" ]
then
      echo "El campo info.title no ha sido infomado en el fichero openapi.json"
      exit;
fi

echo "Name: $apiname \n"

#Se crea fichero para los scopes
rm -rf "tmp/resourceScopes-$1-tmp.json"
touch "tmp/resourceScopes-$1-tmp.json"
echo "[]" >> "tmp/resourceScopes-$1-tmp.json"

#Se crea fichero para los permissions
rm -rf "tmp/arrayMethodsPaths-$1.txt"
touch "tmp/arrayMethodsPaths-$1.txt"

echo "4. Se reemplaza lambdaProxyUri en el fichero openapi-$1.json para las operaciones get post put y delete."
for path in $(jq '.paths' tmp/openapi-$1.json | jq -r 'keys[]'); 
do 
  for method in $(jq --arg path "$path" ".paths."\"$path\""" tmp/openapi-$1.json | jq -r 'keys[]'); 
  do  
    for chkmethod in get post put delete patch
    do 
      if [ $chkmethod = $method ]
      then
        $(jq --arg path,method,lambdaProxyUri "$path","$method","$lambdaProxyUri" ".paths."\"$path\"".$method."\"x-amazon-apigateway-integration"\".uri=\"$lambdaProxyUri\"" tmp/openapi-$1.json > "openapi-$1-temp.json" && mv "openapi-$1-temp.json" tmp/openapi-$1.json);
        echo "$path | $chkmethod:"
        echo "$(jq --arg path,method "$path","$method" ".paths."\"$path\"".$method."\"x-amazon-apigateway-integration"\"" tmp/openapi-$1.json)";
        #Se compone fichero json con los scopes a dar de alta en el servidor de recursos punto 10.
        resourceScopes="$(jq --arg path,method "$path","$method" ".paths."\"$path\"".$method | [{ScopeName : .security[].\"cognito-integration-authorizer\"[] | split(\"/\")[1], ScopeDescription: .description}]" "tmp/openapi-$1.json")";
        $(jq --argjson resourceScopes "$resourceScopes" '. + $resourceScopes' "tmp/resourceScopes-$1-tmp.json" > "tmp/resourceScopes-$1.json" && mv "tmp/resourceScopes-$1.json" "tmp/resourceScopes-$1-tmp.json")
        #Se compone array con los metodos y path necesarios para conceder permisos en el punto 11.
        chkmethodUpper=$(echo $chkmethod | tr '[:lower:]' '[:upper:]')
        echo "$chkmethodUpper$path" >> "tmp/arrayMethodsPaths-$1.txt"
        echo "\n"
      fi
    done
  done;
done

echo " 4.1 Se genera fichero resourceScopes-$1-tmp.json con los scopes a crear en el resource server:"
echo "$PWD/tmp/resourceScopes-$1-tmp.json"

echo " 4.2 Se genera fichero arrayMethodsPaths-$1.txt con los methods y paths para darles permisos:"
echo "$PWD/tmp/arrayMethodsPaths-$1.txt"
echo "\n"

echo "5. Se configura url en el fichero openapi-$1.json."
jq --arg urlEndpoint "$urlEndpoint" '.servers[0].url=$urlEndpoint' tmp/openapi-$1.json > "openapi-$1-temp.json" && mv "openapi-$1-temp.json" tmp/openapi-$1.json
echo "$(jq '.servers[0].url' tmp/openapi-$1.json) \n"

echo "6. Se reemplaza userPoolARN en el fichero openapi-$1.json."
jq --arg userPoolARN "$userPoolARN" '.components.securitySchemes."cognito-integration-authorizer"."x-amazon-apigateway-authorizer".providerARNs=[$userPoolARN]' tmp/openapi-$1.json > "openapi-$1-temp.json" && mv "openapi-$1-temp.json" tmp/openapi-$1.json
echo "$(jq '.components.securitySchemes."cognito-integration-authorizer"."x-amazon-apigateway-authorizer"' tmp/openapi-$1.json) \n"

echo "7. Se codifica el fichero openapi-$1.json en base64:"
jq -c '.' "tmp/openapi-$1.json" | base64 > "tmp/openapi-$1-base64.txt"
echo "$PWD/tmp/openapi-$1-base64.txt \n"

echo "8. Se descarga de AWS los APIs publicados en el API Gateway."
aws apigateway get-rest-apis --profile ama-$1 --region $region > "tmp/aws-apigateway-get-rest-apis-$1-tmp.json"
echo "$PWD/tmp/aws-apigateway-get-rest-apis-$1-tmp.json \n"

echo "9. Se comprueba si el API a publicar existe o no en AWS API Gateway."
api_id=$(jq -r --arg apiname "$apiname" '.items[] | select(.name==$apiname).id' "tmp/aws-apigateway-get-rest-apis-$1-tmp.json")

if [ -z "$api_id" ]
then
    echo " 9.1 No se ha encontrado ningún api publicado en API Gateway bajo el nombre: $apiname."
    echo " 9.2 Se procede a importar el nuevo api: $apiname, a partir del fichero openapi-'$1'-base64.txt."
    aws apigateway import-rest-api --fail-on-warnings --body 'file://./tmp/openapi-'$1'-base64.txt' --profile ama-$1 --region $region > "tmp/aws-apigateway-import-rest-api-$1-tmp.json"
    echo " 9.3 Se obtiene el identificador del API importado."
    api_id=$(jq -r '.id' "tmp/aws-apigateway-import-rest-api-$1-tmp.json")
    echo " rest-api-id: $api_id"
    echo " 9.4 Se procede a desplegar el API y a crear un stage."
    aws apigateway create-deployment --rest-api-id $api_id --stage-name $stageName --stage-description "$apiname" --description "$apiname" --region $region --profile ama-$1 > "tmp/aws-apigateway-create-deployment-$1-tmp.json"
    deployment_id=$(jq -r '.id' "tmp/aws-apigateway-create-deployment-$1-tmp.json")
    echo " rest-api-deployment-id: $deployment_id"
else
    echo " 9.1 Se ha encontrado el identificador: $api_id para el $apiname."
    echo " 9.2 Se procede a subir los cambios al API ya existente a partir del fichero openapi-'$1'-base64.txt."
    aws apigateway put-rest-api --rest-api-id $api_id --no-fail-on-warnings --mode overwrite --body 'file://./tmp/openapi-'$1'-base64.txt' --profile ama-$1 --region $region > "tmp/aws-apigateway-put-rest-api-$1-tmp.json"
    echo " $PWD/tmp/aws-apigateway-put-rest-api-$1-tmp.json"
    echo " 9.3 Se procede a desplegar el API y actualizar stage."
    aws apigateway create-deployment --rest-api-id $api_id --stage-name $stageName --stage-description "$apiname" --description "$apiname" --region $region --profile ama-$1 > "tmp/aws-apigateway-create-deployment-$1-tmp.json"
    echo " $PWD/tmp/aws-apigateway-create-deployment-$1-tmp.json"
    newDeploymentId=$(jq -r '.id' "tmp/aws-apigateway-create-deployment-$1-tmp.json")
    echo " 9.4 Se recogen los id de despliegues."
    aws apigateway get-deployments --rest-api-id $api_id --region $region --profile ama-$1 > "tmp/aws-apigateway-get-deployments-$1-tmp.json"
    echo " $PWD/tmp/aws-apigateway-get-deployments-$1-tmp.json"
    echo " 9.5 Se eliminan los despliegues previos:"
    for deploymentId in $(jq -r --arg apiname "$apiname" '.items[] | select(.description==$apiname).id' "tmp/aws-apigateway-get-deployments-$1-tmp.json")
    do
      if [ $deploymentId != $newDeploymentId ]
      then
        echo " Remove: $deploymentId."
        aws apigateway delete-deployment --rest-api-id $api_id --deployment-id $deploymentId --profile ama-$1 --region $region
      fi
    done
fi
echo "\n"
echo "Waiting to publish-rest-api 10s..." && sleep 10s
echo "\n"
######################################################### END PUBLISH API ##################################################

######################################################### START COGNITO RESOURCE SERVER ##################################################
echo "10. Se comprueba si existe el servidor de recursos:"
aws cognito-idp describe-resource-server --user-pool-id $userPoolId --identifier $resourceServerName --profile ama-$1 --region $region > "tmp/cognito-idp-describe-resource-server-$1-tmp.json"
existResourceServer=$(jq -r --arg resourceServerName "$resourceServerName" '.ResourceServer.Name == $resourceServerName' "tmp/cognito-idp-describe-resource-server-$1-tmp.json")

if [ "$existResourceServer" = true ]
then
    echo " 10.1 Se ha encontrado servidor de recursos en Cognito bajo el nombre: $resourceServerName."
    echo " 10.2 Se procede a actualizar los scopes del servidor de recursos: $resourceServerName."
    aws cognito-idp update-resource-server --user-pool-id $userPoolId --identifier $resourceServerName --name $resourceServerName --scopes 'file://./tmp/resourceScopes-'$1'-tmp.json' --profile ama-$1 --region $region > "tmp/cognito-idp-update-resource-server-$1-tmp.json"
    echo " $PWD/tmp/cognito-idp-update-resource-server-$1-tmp.json"
else
    echo " 10.1 No se ha encontrado ningún servidor de recursos en Cognito bajo el nombre: $resourceServerName."
    echo " 10.2 Se procede a crear nuevo servidor de recursos: $resourceServerName."
    aws cognito-idp create-resource-server --user-pool-id $userPoolId --identifier $resourceServerName --name $resourceServerName --scopes 'file://./tmp/resourceScopes-'$1'-tmp.json' --profile ama-$1 --region $region > "tmp/cognito-idp-create-resource-server-$1-tmp.json"
    echo " $PWD/tmp/cognito-idp-create-resource-server-$1-tmp.json"
fi
echo "\n"
######################################################### END COGNITO RESOURCE SERVER ##################################################

######################################################### START PERMISSION LAMBDA PROXY ##################################################
echo "11. Se procede a conceder permisos para invocar a la lambda proxy:"

aws lambda get-policy --function-name $lambdaRouter  --profile ama-$1 --region $region | jq -rc '.Policy' | jq '.Statement' > "tmp/lambda-get-policy-statement-$1-tmp.json"
listStatementId=$(jq -r '.[].Sid' tmp/lambda-get-policy-statement-$1-tmp.json)

if [ ! -z "$listStatementId" ]
then
    echo " Existen permisos previos, se proceden a eliminar:"
    for statementId in $listStatementId
    do
	    echo " Remove: $statementId."
      aws lambda remove-permission --function-name $lambdaRouter --statement-id $statementId --profile ama-$1 --region $region
    done
    echo " Se procede a conceder los nuevos permisos:"
fi

for methodPath in $(cat "tmp/arrayMethodsPaths-$1.txt")
do
  timeMillis=$(date +%s%N)
  addPermissionArn="arn:aws:execute-api:$region:$accountId:$api_id/*/$methodPath"
  echo " Add permission: $addPermissionArn."
  aws lambda add-permission --function-name $lambdaRouter --action lambda:InvokeFunction --statement-id APIGatewayInvokePermission$timeMillis --principal apigateway.amazonaws.com --source-arn $addPermissionArn --profile ama-$1 --region $region > "tmp/lambda-add-permission-$1-$timeMillis-tmp.json"
  echo " $PWD/tmp/lambda-add-permission-$1-$timeMillis-tmp.json"
done
######################################################### START PERMISSION LAMBDA PROXY ##################################################