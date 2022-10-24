'use strict';

const AWS = require("aws-sdk");

module.exports.delete = async (pet) => {

    console.log("Pet deleted " + pet.id)
    if(pet.id !== undefined)
    {
        console.log("Objeto inicializado ")
        return true;
    }    
    else
    {
        console.log("Objeto no inicializado ")
        return false;    
    }    

} 