import React, { useState, useEffect } from "react";
import Watchlist from "../components/Watchlist";
import Chart from "../components/Chart";
import SignOut from "./SignOut";
import "./Dashboard.css";

const API_BASE = process.env.REACT_APP_API_BASE_URL;
const USER_ID = 1; // until Cognito is hooked up

function Dashboard() {
  const [availableStocks, setAvailableStocks] = useState([]);
  const [watchlistTickers, setWatchlistTickers] = useState([]);
  const [loading, setLoading] = useState(true);

  // Fetch available stocks
  useEffect(() => {
    async function fetchStocks() {
      if (!API_BASE) {
        setLoading(false);
        return;
      }
      try {
        const res = await fetch(`${API_BASE}/stocks`);
        if (res.ok) {
          const data = await res.json();
          setAvailableStocks(data.stocks || []);
        }
      } catch (err) {
        console.error("Failed to fetch stocks:", err);
      } finally {
        setLoading(false);
      }
    }
    fetchStocks();
  }, []);

  // Fetch watchlist to know which stocks are already added
  useEffect(() => {
    async function fetchWatchlist() {
      if (!API_BASE) return;
      try {
        const res = await fetch(`${API_BASE}/watchlist?user_id=${encodeURIComponent(USER_ID)}`);
        if (res.ok) {
          const data = await res.json();
          setWatchlistTickers(data.tickers || []);
        }
      } catch (err) {
        console.error("Failed to fetch watchlist:", err);
      }
    }
    fetchWatchlist();
  }, []);

  // Add stock to watchlist
  async function handleAddToWatchlist(ticker) {
    if (!API_BASE) return;
    try {
      const res = await fetch(`${API_BASE}/watchlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_id: USER_ID, ticker }),
      });
      if (res.ok) {
        setWatchlistTickers([...watchlistTickers, ticker].sort());
        // Trigger watchlist refresh by updating a key or using a callback
        window.dispatchEvent(new Event('watchlist-updated'));
      }
    } catch (err) {
      console.error("Failed to add to watchlist:", err);
    }
  }

  return (
    <div className="dashboard">
      <div className="dashboard-bar">
        <h2>Your Dashboard</h2>
        <SignOut />
      </div>
      
      {/* Available Stocks Section */}
      <div className="available-stocks-section">
        <h3 className="available-stocks-title">Available Stocks</h3>
        {loading ? (
          <div className="loading-text">Loading stocks...</div>
        ) : (
          <div className="stocks-grid">
            {availableStocks.map((stock) => {
              const isInWatchlist = watchlistTickers.includes(stock.ticker);
              return (
                <div key={stock.id} className="stock-card">
                  <span className="stock-ticker">{stock.ticker}</span>
                  <button
                    className={`add-to-watchlist-btn ${isInWatchlist ? 'in-watchlist' : ''}`}
                    onClick={() => !isInWatchlist && handleAddToWatchlist(stock.ticker)}
                    disabled={isInWatchlist}
                  >
                    {isInWatchlist ? '✓ In Watchlist' : '+ Add to Watchlist'}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div>
        <Chart />
        <Watchlist onWatchlistChange={setWatchlistTickers} />
      </div>
    </div>    
  );
}

export default Dashboard;
