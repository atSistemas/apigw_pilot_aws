#! /bin/bash
echo "Environment Main: $1"
if [ -z "$1" ]
then
      echo "El entorno sobre el que se ejecuta la solución no ha sido informado como parámetro de entrada"
      exit;
fi
# 1º Paso que despliega la lambda management y los recursos dynamo y permisos
#serverless deploy --stage $1 --aws-profile ama-$1
# 2º Paso para publicar las API's
cd ../publishAPI
sh script/promoteAPIs.sh $1
#serverless deploy --stage $1 --aws-profile ama-$1
# 3º Descargar openAPI y publicar en bucket S3
cd ../deploydocOpenAPI
sh script/exportdocOpenAPI.sh
#serverless deploy --stage $1 --aws-profile ama-$1
