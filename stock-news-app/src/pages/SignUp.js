import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { userPool } from "../cognito";
import "./Auth.css";

function SignUp() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleSignUp = (e) => {
    e.preventDefault();

    userPool.signUp(email, password, [], null, (err, result) => {
      if (err) {
        setMessage(err.message || JSON.stringify(err));
      } else {
        setMessage("Sign-up successful! Please check your email to confirm.");
        navigate("/");
      }
    });
  };

  return (
    <div className="auth-container">
      <h1 className="auth-title">Create Account</h1>

      <form className="auth-form" onSubmit={handleSignUp}>
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
          Sign Up
        </button>
      </form>

      {message && <div className="auth-message">{message}</div>}
    </div>
  );
}

export default SignUp;
