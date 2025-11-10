const API_BASE = process.env.REACT_APP_API_BASE; 

export async function fetchWatchlist(userId) {
  const r = await fetch(`${API_BASE}/watchlist?user_id=${encodeURIComponent(userId)}`);
  if (!r.ok) throw new Error(`watchlist failed: ${r.status}`);
  return r.json(); // { user_id, tickers: [...] }
}

export async function addToWatchlist(userId, ticker) {
  const r = await fetch(`${API_BASE}/watchlist`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: userId, ticker })
  });
  if (!r.ok) throw new Error(`add failed: ${r.status}`);
  return r.json();
}

export async function removeFromWatchlist(userId, ticker) {
  const r = await fetch(`${API_BASE}/watchlist`, {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: userId, ticker })
  });
  if (!r.ok) throw new Error(`remove failed: ${r.status}`);
  return r.json();
}

export async function fetchQuotes(tickers) {
  const qs = encodeURIComponent(tickers.join(","));
  const r = await fetch(`${API_BASE}/quotes?tickers=${qs}`);
  if (!r.ok) throw new Error(`quotes failed: ${r.status}`);
  return r.json(); // { quotes: [{ticker, price, change_pct, updated_at?}] }
}
