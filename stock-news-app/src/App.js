import React, { useState } from "react";
import { signUp, signIn } from "./cognito";

export default function App() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSignUp = async () => {
    try {
      await signUp(email, password);
      alert("Check your email to verify your account!");
    } catch (err) {
      alert(err.message);
    }
  };

  const handleSignIn = async () => {
    try {
      const result = await signIn(email, password);
      alert("Sign in successful!");
      console.log("Session:", result);
    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", width: 300, margin: "100px auto" }}>
      <input placeholder="Email" onChange={(e) => setEmail(e.target.value)} />
      <input placeholder="Password" type="password" onChange={(e) => setPassword(e.target.value)} />
      <button onClick={handleSignUp}>Sign Up</button>
      <button onClick={handleSignIn}>Sign In</button>
    </div>
  );
}