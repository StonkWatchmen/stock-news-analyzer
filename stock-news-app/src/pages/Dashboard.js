import React, { useState, useEffect, useCallback } from "react";
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
  const [stocksError, setStocksError] = useState(null);

  // Fetch available stocks
  useEffect(() => {
    async function fetchStocks() {
      if (!API_BASE) {
        setLoading(false);
        setStocksError("API_BASE_URL not configured");
        return;
      }
      try {
        const res = await fetch(`${API_BASE}/stocks`);
        if (!res.ok) {
          throw new Error(`Failed to fetch stocks: ${res.status} ${res.statusText}`);
        }
        const data = await res.json();
        const stocks = data.stocks || [];
        setAvailableStocks(stocks);
        if (stocks.length === 0) {
          setStocksError("No stocks found in database");
        } else {
          setStocksError(null);
        }
      } catch (err) {
        console.error("Failed to fetch stocks:", err);
        setStocksError(err.message || "Failed to load stocks");
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

  // Stable callback for watchlist changes
  const handleWatchlistChange = useCallback((tickers) => {
    setWatchlistTickers(tickers);
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
        ) : stocksError ? (
          <div className="stocks-error">
            <p>Error: {stocksError}</p>
            <p style={{ fontSize: '14px', color: 'var(--muted)', marginTop: '8px' }}>
              Make sure the database has been initialized with stocks. Check the browser console for more details.
            </p>
          </div>
        ) : availableStocks.length === 0 ? (
          <div className="stocks-empty">
            No stocks available. Please ensure stocks have been seeded in the database.
          </div>
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
                    {isInWatchlist ? 'In Watchlist' : '+ Add to Watchlist'}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div>
        <Chart />
        <Watchlist onWatchlistChange={handleWatchlistChange} />
      </div>
    </div>    
  );
}

export default Dashboard;
