import {useEffect, useState} from "react";
import {getWatchlist, saveWatchlist } from "../utils/storage";
import "./Watchlist.css"

// const API_BASE = process.env.REACT_APP_API_BASE;
const API_BASE = process.env.REACT_APP_API_BASE_URL;

const USER_ID = 1; // until Cognito is hooked up

export default function Watchlist({ onWatchlistChange }) {
    // Track ticker list, input value, and user error message. 
    const [items, setItems] = useState([]);
    const [quotes, setQuotes] = useState([]);
    const count = items.length;

    // load from backend on mount
    useEffect(() => {
        const fetchWatchlist = async () => {
            if (!API_BASE) {
                const local = getWatchlist();
                setItems(local);
                await fetchQuotesFor(local);
                return;
            }
            try {
                const res = await fetch(`${API_BASE}/watchlist?user_id=${encodeURIComponent(USER_ID)}`);
                if (!res.ok) {
                    throw new Error("bad status");
                }
                const data = await res.json();
                const tickers = data.tickers || [];
                setItems(tickers);
                saveWatchlist(tickers);
                await fetchQuotesFor(tickers);
                if (onWatchlistChange) {
                    onWatchlistChange(tickers);
                }
            } catch (err) {
                console.warn("Backend watchlist fetch failed, falling back to local:", err);
                const local = getWatchlist();
                setItems(local);
                await fetchQuotesFor(local);
            }
        };
        fetchWatchlist();

        // Listen for watchlist updates from Dashboard
        const handleUpdate = () => {
            fetchWatchlist();
        };
        window.addEventListener('watchlist-updated', handleUpdate);
        return () => window.removeEventListener('watchlist-updated', handleUpdate);
    }, [onWatchlistChange]);

    async function syncRemove(ticker) {
        if (!API_BASE) {
            return;
        }
        await fetch(`${API_BASE}/watchlist`, {
            method: "DELETE",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ user_id: USER_ID, ticker }),
        });
    }     

    // Fetch quotes for a list of tickers and update state
    async function fetchQuotesFor(list) {
        if(!list.length){
            setQuotes([]);
            return;
        }
        if(!API_BASE){
            console.error("Missing REACT_APP_API_BASE. Prices cannnot be loaded");
            return;
        }
        const qs = encodeURIComponent(list.join(","));
        try {
            const res = await fetch(`${API_BASE}/quotes?tickers=${qs}`);
            if (!res.ok) throw new Error(`quotes ${res.status}`);
            const data = await res.json();
            setQuotes(data.quotes || []);
        } catch (e) {
            console.warn("Fetching quotes failed:", e);
            setQuotes([]);
        }
    }

    // Remove single ticker
    async function handleRemove(symbol) {
        const next = items.filter((t) => t !== symbol);
        setItems(next);
        saveWatchlist(next);
        try { await syncRemove(symbol); } catch (err) { console.error(err); }
        await fetchQuotesFor(next);
        if (onWatchlistChange) {
            onWatchlistChange(next);
        }
        // Notify Dashboard of change
        window.dispatchEvent(new Event('watchlist-updated'));
    }

    // Clear all tickers (with confirmation)
    function handleClearAll() {
        if (!window.confirm("Clear all tickers from your watchlist?")) {
            return;
        }

        // best effort clear on backend
        items.forEach((t) => syncRemove(t).catch(() => {}));
        setItems([]);
        saveWatchlist([]);
        setQuotes([]);
        if (onWatchlistChange) {
            onWatchlistChange([]);
        }
        window.dispatchEvent(new Event('watchlist-updated'));
    }

    return (
        <div className="watchlist-container">
            <h1 className="watchlist-title">Your Watchlist</h1>

            <div className="watchlist-meta">
                <span>{count} {count === 1 ? "ticker" : "tickers"}</span>
                {count > 0 && (
                    <button className="watchlist-clear" onClick={handleClearAll}>
                        Clear All
                    </button>
                )}
            </div>

            {count === 0 && (
                <div className="watchlist-empty">
                    Your watchlist is empty. Add stocks from the "Available Stocks" section above.
                </div>
            )}

            <ul className="watchlist-items">
            {items.map((t) => {
                const q = quotes.find((x) => x.ticker === t) || {};

                const score =
                    typeof q.sentiment_score === "number" ? q.sentiment_score : null;
                const label = q.sentiment_label || null;      // "Bullish", "Bearish", etc.
                const errorMsg = q.error;

                const scoreDisplay = score !== null ? score.toFixed(3) : "—";

                const sentimentLabel = label || (errorMsg ? "Error" : "—");

                const sentimentClass =
                    score > 0 ? "up" :
                    score < 0 ? "down" :
                    "";

                return (
                    <li key={t} className="watchlist-item">
                        <span className="ticker">{t}</span>

                        <div className="watchlist-values">
                            {/* Sentiment numeric score */}
                            <span className={`sentiment-score ${sentimentClass}`}>
                                {scoreDisplay}
                            </span>

                            {/* Sentiment label */}
                            <span className={`sentiment ${sentimentClass}`}>
                                {sentimentLabel}
                            </span>
                        </div>

                        <button
                            className="remove-btn"
                            onClick={() => handleRemove(t)}
                            title="Remove this ticker"
                        >
                            x
                        </button>
                    </li>
                );
            })}

            </ul> 
        </div>
    );
}