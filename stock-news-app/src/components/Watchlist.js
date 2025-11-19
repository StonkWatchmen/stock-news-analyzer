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
  const [userId, setUserId] = useState(null);
  const [token, setToken] = useState(null);

  // Get current Cognito user, token, and sub
  async function getCurrentUser() {
    return new Promise((resolve, reject) => {
      const currentUser = userPool.getCurrentUser();
      if (!currentUser) return reject(new Error("No user logged in"));

      currentUser.getSession((err, session) => {
        if (err) return reject(err);

        currentUser.getUserAttributes((err, attrs) => {
          if (err) return reject(err);

          const subAttr = attrs.find((a) => a.Name === "sub");
          resolve({
            token: session.getIdToken().getJwtToken(),
            userId: subAttr?.Value,
          });
        });
      });
    });
  }

  // Fetch all stocks and get user info
  useEffect(() => {
    async function fetchStocksAndUser() {
      setLoading(true);
      setError(null);
      try {
        const { token, userId } = await getCurrentUser();
        if (!userId) throw new Error("Failed to get user ID");
        setUserId(userId);
        setToken(token);

        const res = await fetch(`${API_BASE}/stocks`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();
        setAllStocks(json.stocks || []);
      } catch (err) {
        console.error(err);
        setError("Failed to load stocks or user info");
      } finally {
        setLoading(false);
      }
    }

    fetchStocksAndUser();
  }, []);

  // Load watchlist from backend
  useEffect(() => {
    async function loadWatchlist() {
      if (!userId || !token) return;

      try {
        const res = await fetch(`${API_BASE}/watchlist?user_id=${userId}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();

        const watchlistStocks = allStocks.filter((stock) =>
          (json.tickers || []).includes(stock.ticker)
        );
        setWatchlist(watchlistStocks);
      } catch (err) {
        console.error("Failed to load watchlist:", err);
      }
    }

    if (allStocks.length > 0 && userId && token) loadWatchlist();
  }, [allStocks, userId, token]);

  // Add stock to watchlist
  async function addToWatchlist(stock) {
    if (!userId || !token) return setError("User not logged in");

    if (watchlist.some((s) => s.ticker === stock.ticker)) return;

    try {
      const res = await fetch(`${API_BASE}/watchlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
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
    if (!userId || !token) return setError("User not logged in");

    try {
      const res = await fetch(`${API_BASE}/watchlist`, {
        method: "DELETE",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
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
                  {stock.ticker} - {stock.name || stock.ticker}
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
                  {stock.ticker} - {stock.name || stock.ticker}
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
