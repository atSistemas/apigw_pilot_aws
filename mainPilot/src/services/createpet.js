'use strict';

const AWS = require("aws-sdk");

module.exports.create = async (pet) => {

    console.log("Pet created " + JSON.stringify(pet))
    return true;    
}    