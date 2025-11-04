import React, { useState } from "react";
import { signIn } from "../Cognito";
import { useNavigate, Link } from "react-router-dom";
import "./Auth.css";

function SignIn() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleSignIn = (e) => {
    e.preventDefault();

    signIn(email, password)
      .then((result) => {
        localStorage.setItem("cognitoToken", result.getIdToken().getJwtToken());
        navigate("/dashboard");
      })
      .catch((err) => {
        if (err.code === "UserNotConfirmedException") {
          setMessage("Please confirm your email before signing in.");
        } else if (err.code === "NotAuthorizedException") {
          setMessage("Incorrect email or password. Please try again.");
        } else {
          setMessage(err.message || JSON.stringify(err));
        }
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
