import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { signUp } from "../Cognito";
import "./Auth.css";

function SignUp() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleSignUp = (e) => {
    e.preventDefault();
  
    signUp(email, password)
      .then(() => {
        setMessage("Sign-up successful! Please check your email to confirm.");
        navigate("/confirm");
      })
      .catch((err) => {
        setMessage(err.message || JSON.stringify(err));
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

      <p className="auth-link-text">
        Have an account already?{" "}
        <Link to="/" className="auth-link">
          Sign In
        </Link>
      </p>

      {message && <div className="auth-message">{message}</div>}
    </div>
  );
}

export default SignUp;
