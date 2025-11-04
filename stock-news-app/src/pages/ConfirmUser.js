import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { confirmUser, resendConfirmation } from "../Cognito";
import "./Auth.css";

function ConfirmSignUp() {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  const handleConfirm = (e) => {
    e.preventDefault();

    confirmUser(email, code)
      .then(() => {
        setMessage("Account confirmed successfully! You can now sign in.");
        setTimeout(() => navigate("/"), 2000);
      })
      .catch((err) => {
        setMessage(err.message || JSON.stringify(err));
      });
  };

  const handleResend = () => {
    resendConfirmation(email)
      .then(() => setMessage("A new confirmation code has been sent to your email."))
      .catch((err) => setMessage(err.message || JSON.stringify(err)));
  };

  return (
    <div className="auth-container">
      <h1 className="auth-title">Confirm Your Account</h1>

      <form className="auth-form" onSubmit={handleConfirm}>
        <input
          type="email"
          placeholder="Email"
          className="auth-input"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />

        <input
          type="text"
          placeholder="Confirmation Code"
          className="auth-input"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          required
        />

        <button type="submit" className="auth-btn">
          Confirm Account
        </button>
      </form>

      <button onClick={handleResend} className="auth-link-btn">
        Resend Confirmation Code
      </button>

      {message && <div className="auth-message">{message}</div>}
    </div>
  );
}

export default ConfirmSignUp;
