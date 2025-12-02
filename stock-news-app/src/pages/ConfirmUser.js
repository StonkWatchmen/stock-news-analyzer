import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { confirmUser, resendConfirmation } from "../Cognito";
import "./Auth.css";

function ConfirmSignUp() {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState("error"); // 'error' or 'success'
  const navigate = useNavigate();

  const handleConfirm = (e) => {
    e.preventDefault();

    confirmUser(email, code)
      .then(() => {
        setMessageType("success");
        setMessage("Account confirmed successfully! Redirecting to sign in...");
        setTimeout(() => navigate("/"), 2000);
      })
      .catch((err) => {
        setMessageType("error");
        // Handle specific Cognito errors
        if (err.code === "NotAuthorizedException" && err.message.includes("already confirmed")) {
          setMessage("This account has already been confirmed. You can sign in now.");
          setTimeout(() => navigate("/"), 3000);
        } else if (err.code === "CodeMismatchException") {
          setMessage("Invalid confirmation code. Please check your email and try again.");
        } else if (err.code === "ExpiredCodeException") {
          setMessage("Confirmation code has expired. Please request a new one.");
        } else {
          setMessage(err.message || "An error occurred during confirmation. Please try again.");
        }
      });
  };

  const handleResend = () => {
    resendConfirmation(email)
      .then(() => {
        setMessageType("success");
        setMessage("A new confirmation code has been sent to your email.");
      })
      .catch((err) => {
        setMessageType("error");
        if (err.code === "NotAuthorizedException" && err.message.includes("already confirmed")) {
          setMessage("This account has already been confirmed. You can sign in now.");
          setTimeout(() => navigate("/"), 3000);
        } else {
          setMessage(err.message || "Failed to resend confirmation code.");
        }
      });
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

      {message && (
        <div className={`auth-message ${messageType === "success" ? "auth-message-success" : "auth-message-error"}`}>
          {message}
        </div>
      )}
    </div>
  );
}

export default ConfirmSignUp;
