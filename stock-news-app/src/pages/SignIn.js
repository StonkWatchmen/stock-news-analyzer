import React, { useState } from "react";
import { CognitoUser, AuthenticationDetails } from "amazon-cognito-identity-js";
import { userPool } from "../Cognito";
import { useNavigate, Link } from "react-router-dom";
import "./Auth.css";

function SignIn() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleSignIn = (e) => {
    e.preventDefault();

    const user = new CognitoUser({ Username: email, Pool: userPool });
    const authDetails = new AuthenticationDetails({
      Username: email,
      Password: password,
    });

    user.authenticateUser(authDetails, {
      onSuccess: (result) => {
        localStorage.setItem("cognitoToken", result.getIdToken().getJwtToken());
        navigate("/dashboard");
      },
      onFailure: (err) => setMessage(err.message || JSON.stringify(err)),
    });
  };

  return (
    <div className="auth-container">
      <h1 className="auth-title">Welcome Back</h1>

      <form className="auth-form" onSubmit={handleSignIn}>
        <input
          type="email"
          placeholder="Email"
          className="auth-input"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />

        <input
          type="password"
          placeholder="Password"
          className="auth-input"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />

        <button type="submit" className="auth-btn">
          Sign In
        </button>
      </form>

      <p className="auth-link-text">
        Don’t have an account?{" "}
        <Link to="/signup" className="auth-link">
          Sign Up
        </Link>
      </p>

      {message && <div className="auth-message">{message}</div>}
    </div>
  );
}

export default SignIn;
