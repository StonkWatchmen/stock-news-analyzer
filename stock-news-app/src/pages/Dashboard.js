import React from "react";
import Watchlist from "../components/Watchlist";
import Chart from "../components/Chart";
import SignOut from "./SignOut";
import "./Dashboard.css";

function Dashboard() {
  return (
    <div className="dashboard">
      <div className="dashboard-bar">
        <h2>Your Dashboard</h2>
        <SignOut />
      </div>
      <div>
        <Chart />
        <Watchlist />
      </div>
    </div>    
  );
}

export default Dashboard;
