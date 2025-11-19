import React, { useEffect, useState } from "react";
import "./Watchlist.css";

const API_BASE = process.env.REACT_APP_API_BASE_URL;

export default function Watchlist({ userId }) {
  const [allStocks, setAllStocks] = useState([]);
  const [watchlist, setWatchlist] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Fetch all available stocks
  useEffect(() => {
    async function fetchStocks() {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch(`${API_BASE}/stocks`);
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();
        setAllStocks(json.stocks || []);
      } catch (err) {
        console.error(err);
        setError("Failed to load stocks");
      } finally {
        setLoading(false);
      }
    }
    fetchStocks();
  }, []);

  // Load user watchlist
  useEffect(() => {
    async function loadWatchlist() {
      if (!userId) return;
      try {
        const res = await fetch(`${API_BASE}/watchlist?user_id=${userId}`);
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();
        // Map tickers to stock objects
        const watchlistStocks = allStocks.filter((stock) =>
          (json.tickers || []).includes(stock.ticker)
        );
        setWatchlist(watchlistStocks);
      } catch (err) {
        console.error("Failed to load watchlist:", err);
        setError("Failed to load watchlist");
      }
    }
    if (allStocks.length > 0) loadWatchlist();
  }, [allStocks, userId]);

  // Add stock to watchlist
  async function addToWatchlist(stock) {
    if (!userId) return setError("User not logged in");
    if (watchlist.some((s) => s.ticker === stock.ticker)) return;

    try {
      const res = await fetch(`${API_BASE}/watchlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_id: userId, ticker: stock.ticker }),
      });
      if (!res.ok) throw new Error(`API error: ${res.status}`);
      setWatchlist((prev) => [...prev, stock]);
    } catch (err) {
      console.error(err);
      setError("Failed to add to watchlist");
    }
  }

  // Remove stock from watchlist
  async function removeFromWatchlist(stock) {
    if (!userId) return setError("User not logged in");

    try {
      const res = await fetch(`${API_BASE}/watchlist`, {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_id: userId, ticker: stock.ticker }),
      });
      if (!res.ok) throw new Error(`API error: ${res.status}`);
      setWatchlist((prev) => prev.filter((s) => s.ticker !== stock.ticker));
    } catch (err) {
      console.error(err);
      setError("Failed to remove from watchlist");
    }
  }

  return (
    <div className="watchlist-container">
      <h3>Your Watchlist</h3>
      {error && <div className="watchlist-error">{error}</div>}
      {loading && <div>Loading stocks...</div>}

      {!loading && !error && (
        <div className="watchlist-content">
          <div className="available-stocks">
            <h4>Available Stocks</h4>
            <ul>
              {allStocks.map((stock) => (
                <li key={stock.id}>
                  {stock.ticker}
                  <button
                    onClick={() => addToWatchlist(stock)}
                    disabled={watchlist.some((s) => s.ticker === stock.ticker)}
                  >
                    {watchlist.some((s) => s.ticker === stock.ticker)
                      ? "Added"
                      : "Add"}
                  </button>
                </li>
              ))}
            </ul>
          </div>

          <div className="current-watchlist">
            <h4>Current Watchlist ({watchlist.length})</h4>
            <ul>
              {watchlist.map((stock) => (
                <li key={stock.id}>
                  {stock.ticker}
                  <button onClick={() => removeFromWatchlist(stock)}>Remove</button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}
