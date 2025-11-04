import {
    CognitoUserPool,
    CognitoUser,
    AuthenticationDetails
  } from "amazon-cognito-identity-js";
  
  const poolData = {
    UserPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
    ClientId: process.env.REACT_APP_COGNITO_CLIENT_ID
  };
  
  const userPool = new CognitoUserPool(poolData);
  
  export function signUp(email, password) {
    return new Promise((resolve, reject) => {
      userPool.signUp(email, password, [], null, (err, result) => {
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
  