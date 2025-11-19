import React from "react";
import { useNavigate } from "react-router-dom";
import { userPool } from "../Cognito";
import "./Auth.css";

export default function SignOut() {
    const navigate = useNavigate();

    function handleSignOut() {
        try {
            const user = userPool && userPool.getCurrentUser && userPool.getCurrentUser();
            if (user && user.signOut) {
                user.signOut();
            }
        } catch (err) {
            console.error("Sign out error:", err);
        }
        
        navigate("/");
    }

    return (
        <div className="auth-container" style={{ maxWidth: "200px", margin: "100px auto", textAlign: "center" }}>
            <button
                className="auth-btn"
                onClick={handleSignOut}
                title="Sign Out"
            >
                Sign Out
            </button>
        </div>
    );
}
