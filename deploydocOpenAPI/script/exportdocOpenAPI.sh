#! /bin/bash

echo "1. Se crean directorios temporales."
rm -rf "static/"
mkdir static
rm -rf "tmp/"
mkdir tmp
echo "$PWD/tmp \n"
echo "$PWD/static \n"

echo "2. Se copia fichero openapi-$1.json al directorio temporal."
cp ../publishAPI/tmp/openapi-$1.json static/openAPIPilot-$1-tmp.json
echo "$PWD/static/openAPIPilot-$1-tmp.json \n"

echo "3. Se obtienen las configuraciones de entorno:"

tokenUrl=$(jq -r '.tokenUrl' environment/env-$1.json)

region=$(jq -r '.region' environment/env-$1.json)

stage=$(jq -r '.stageName' environment/env-$1.json)

if [ -z $tokenUrl ]
then
      echo "El campo tokenUrl no ha sido infomado en el fichero de configuracion env-$1.json"
      exit;
fi 

echo "tokenUrl: $tokenUrl \n"

if [ -z $region ]
then
      echo "El campo region no ha sido infomado en el fichero de configuracion env-$1.json"
      exit;
fi 

echo "region: $region \n"

if [ -z $stage ]
then
      echo "El campo stage no ha sido infomado en el fichero de configuracion env-$1.json"
      exit;
fi 

echo "stage: $stage \n"

echo "4. Se procede a recoger el identificador del api publicado en AWS"

titleAPI=$(jq '.info.title' static/openAPIPilot-$1-tmp.json)
echo "titulo del API: $titleAPI"
aws apigateway get-rest-apis --profile pilot-$1 --region $region > tmp/apigateway-restapi-$1-tmp.json        
api=$(jq '.items[]  | select(.name == "API Pilot") | .id' tmp/apigateway-restapi-$1-tmp.json)
apiId=$(echo "$api" | tr -d '"')   
urlEndpoint="https://$apiId.execute-api.eu-west-1.amazonaws.com/$stage"
echo "urlEndpoint: $urlEndpoint"

echo "4.a Sustituimos la url en la que es publicado el servicio"
jq --arg urlEndpoint "$urlEndpoint" '.servers[0].url=$urlEndpoint' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-url.json" && mv "static/openAPIPilot-$1-url.json" "static/openAPIPilot-$1-tmp.json"
echo "$(jq '.servers[0].url' static/openAPIPilot-$1-tmp.json) \n"



echo "4. Se eliminan los metodos options:"
#Se recorre el fichero origen para eliminar los metodos options
for path in $(jq '.paths' static/openAPIPilot-$1-tmp.json | jq -r 'keys[]'); 
do 
  for method in $(jq --arg path "$path" ".paths."\"$path\""" static/openAPIPilot-$1-tmp.json | jq -r 'keys[]'); 
  do  
    for chkmethod in options
    do 
      if [ $chkmethod = $method ]
      then
        echo "Removed: .paths.$path.$method"
        $(jq --arg path,method "$path","$method" 'del(.paths."'"$path"'"."'"$method"'")' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json")
      fi
    done
  done;
done
echo "\n"

echo "5. Se configura securitySchemes oauth2 openAPIPilot-$1.json."
jq '.components.securitySchemes."cognito-integration-authorizer".type="oauth2"' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json"
jq 'del(.components.securitySchemes."cognito-integration-authorizer".name)' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json"
jq 'del(.components.securitySchemes."cognito-integration-authorizer".in)' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json"
jq '.components.securitySchemes."cognito-integration-authorizer" += {"flows":{"clientCredentials":{"tokenUrl":"", "scopes": {}}}}' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json"
jq --arg tokenUrl "$tokenUrl" '.components.securitySchemes."cognito-integration-authorizer".flows.clientCredentials.tokenUrl=$tokenUrl' static/openAPIPilot-$1-tmp.json > "static/openAPIPilot-$1-replaced.json" && mv "static/openAPIPilot-$1-replaced.json" "static/openAPIPilot-$1-tmp.json"
echo "$(jq '.components.securitySchemes."cognito-integration-authorizer"' static/openAPIPilot-$1-tmp.json) \n"

echo "6. Se renombra fichero openAPIPilot-$1-tmp.json por openAPIPilot-$1.json:"
mv "static/openAPIPilot-$1-tmp.json" "static/openAPIPilot-$1.json"
echo "$PWD/static/openAPIPilot-$1.json \n"