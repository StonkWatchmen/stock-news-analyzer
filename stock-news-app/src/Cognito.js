import {
    CognitoUserPool,
    CognitoUser,
    AuthenticationDetails,
    CognitoUserAttribute
  } from "amazon-cognito-identity-js";
  
  const poolData = {
    UserPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
    ClientId: process.env.REACT_APP_COGNITO_CLIENT_ID
  };
  
  export const userPool = new CognitoUserPool(poolData);
 
  export function signUp(email, password) {
    return new Promise((resolve, reject) => {
      const attributeList = [
        new CognitoUserAttribute({
          Name: "email",
          Value: email
        })
      ];
      
      userPool.signUp(email, password, attributeList, null, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  }
  
  export function signIn(email, password) {
    return new Promise((resolve, reject) => {
      const user = new CognitoUser({ Username: email, Pool: userPool });
      const authDetails = new AuthenticationDetails({ Username: email, Password: password });
      
      user.authenticateUser(authDetails, {
        onSuccess: resolve,
        onFailure: reject
      });
    });
  }

  export function confirmUser(email, code) {
    return new Promise((resolve, reject) => {
      const user = new CognitoUser({ Username: email, Pool: userPool });

      user.confirmRegistration(code, true, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  }

  export function resendConfirmation(email) {
    return new Promise((resolve, reject) => {
      const user = new CognitoUser({ Username: email, Pool: userPool });
  
      user.resendConfirmationCode((err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  }  
  
