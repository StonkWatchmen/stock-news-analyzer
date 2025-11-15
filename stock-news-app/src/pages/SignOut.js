import React from "react";
import { useNavigate } from "react-router-dom";
import { userPool } from "../Cognito";

export default function SignOut() {
    const navigate = useNavigate();

    function handleSignOut() {
        try {
            const user = userPool && userPool.getCurrentUser && userPool.getCurrentUser();
            if (user && user.signOut) {
                user.signOut();
            }
        } catch (err) {}
        
        navigate("/");
    }

    return (
        <button className="signout-btn" onClick={handleSignOut} title="Sign Out">
            SignOut
        </button>
    );
}