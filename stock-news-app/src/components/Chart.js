import React, { useEffect, useState } from "react";
import { CognitoUserPool } from "amazon-cognito-identity-js";
import "./Watchlist.css";

const API_BASE = process.env.REACT_APP_API_BASE_URL;

const userPool = new CognitoUserPool({
  UserPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
  ClientId: process.env.REACT_APP_COGNITO_CLIENT_ID,
});

export default function Watchlist() {
  const [allStocks, setAllStocks] = useState([]);
  const [watchlist, setWatchlist] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Get the current user's ID token
  function getIdToken() {
    return new Promise((resolve, reject) => {
      const currentUser = userPool.getCurrentUser();
      if (!currentUser) {
        reject(new Error("No user logged in"));
        return;
      }

      currentUser.getSession((err, session) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(session.getIdToken().getJwtToken());
      });
    });
  }

  // Fetch all available stocks from the backend
  useEffect(() => {
    async function fetchStocks() {
      setLoading(true);
      setError(null);
      try {
        const token = await getIdToken();
        
        const res = await fetch(`${API_BASE}/stocks`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();
        setAllStocks(json.stocks || []);
      } catch (err) {
        setError("Failed to load stock list");
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    fetchStocks();
  }, []);

  // Add stock to watchlist
  function addToWatchlist(stock) {
    if (!watchlist.some((s) => s.ticker === stock.ticker)) {
      setWatchlist((prev) => [...prev, stock]);
    }
  }

  // Remove stock from watchlist
  function removeFromWatchlist(stock) {
    setWatchlist((prev) => prev.filter((s) => s.ticker !== stock.ticker));
  }

  return (
    <div className="watchlist-container">
      <h3 className="watchlist-title">Your Watchlist</h3>

      {error && <div className="watchlist-error">{error}</div>}
      {loading && <div className="watchlist-loading">Loading stocks...</div>}

      {!loading && !error && (
        <div className="watchlist-content">
          <div className="available-stocks">
            <h4>Available Stocks</h4>
            {allStocks.length === 0 && <p>No stocks available</p>}
            <ul>
              {allStocks.map((stock) => (
                <li key={stock.id}>
                  {stock.ticker} - {stock.name || stock.ticker}
                  <button
                    className="watchlist-add-btn"
                    onClick={() => addToWatchlist(stock)}
                    disabled={watchlist.some((s) => s.ticker === stock.ticker)}
                  >
                    Add
                  </button>
                </li>
              ))}
            </ul>
          </div>

          <div className="current-watchlist">
            <h4>Current Watchlist</h4>
            {watchlist.length === 0 && <p>No stocks in watchlist</p>}
            <ul>
              {watchlist.map((stock) => (
                <li key={stock.id}>
                  {stock.ticker} - {stock.name || stock.ticker}
                  <button
                    className="watchlist-remove-btn"
                    onClick={() => removeFromWatchlist(stock)}
                  >
                    Remove
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}