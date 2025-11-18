const API_BASE = process.env.REACT_APP_API_BASE;

export async function apiGetWatchlist(userId) {
  const r = await fetch(`${API_BASE}/watchlist?user_id=${encodeURIComponent(userId)}`);
  if (!r.ok) throw new Error(`watchlist failed: ${r.status}`);
  return r.json();
}

export async function apiAddTicker(userId, ticker) {
  const r = await fetch(`${API_BASE}/watchlist`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: userId, ticker })
  });
  if (!r.ok) throw new Error(`add failed: ${r.status}`);
  return r.json();
}

export async function apiRemoveTicker(userId, ticker) {
  const r = await fetch(`${API_BASE}/watchlist`, {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: userId, ticker })
  });
  if (!r.ok) throw new Error(`remove failed: ${r.status}`);
  return r.json();
}

export async function apiGetQuotes(tickers) {
  const qs = encodeURIComponent(tickers.join(","));
  const r = await fetch(`${API_BASE}/quotes?tickers=${qs}`);
  if (!r.ok) throw new Error(`quotes failed: ${r.status}`);
  return r.json(); // { quotes: [...] }
}
