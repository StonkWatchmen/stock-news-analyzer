import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { userPool } from "../cognito";

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
        // Optionally, redirect to SignIn page
        navigate("/");
      }
    });
  };

  return (
    <form onSubmit={handleSignUp}>
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <button type="submit">Sign Up</button>
      {message && <p>{message}</p>}
    </form>
  );
}

export default SignUp;
