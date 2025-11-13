import {useEffect, useState} from "react";
import {getWatchlist, saveWatchlist } from "../utils/storage";
import "./Watchlist.css"

const TICKER_REGEX = /^[A-Z.-]{1,10}$/;    // Allows ticker patterns like BRK.B, RDS.A, etc.
const API_BASE = process.env.REACT_APP_API_BASE;
const USER_ID = 1; // until Cognito is hooked up

// Keep tickers consistent: trim whitespace and uppercase
function normalizeTicker(t) {
    return t.trim().toUpperCase();
}

export default function Watchlist() {
    // Track ticker list, input value, and user error message. 
    const [items, setItems] = useState([]);
    const [input, setInput] = useState("");
    const [error, setError] = useState("");
    const [quotes, setQuotes] = useState([]);
    const count = items.length;
    const isDisabled = !input.trim();

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
            } catch (err) {
                console.warn("Backend watchlist fetch failed, falling back to local:", err);
                const local = getWatchlist();
                setItems(local);
                await fetchQuotesFor(local);
            }
        };
        fetchWatchlist();    
    }, []);

    async function syncAdd(ticker) {
        if (!API_BASE) {
            return;
        }
        await fetch(`${API_BASE}/watchlist`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ user_id: USER_ID, ticker }),
        }); 
    }

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






           
    async function handleAdd(e) {
        e.preventDefault();

        // Validation chain -> normalize, check format, check duplicates, check limit
        const symbol = normalizeTicker(input);
        if (!symbol) {
            setError("Enter a ticker symbol.");
            return;
        }
        if (!TICKER_REGEX.test(symbol)) {
            setError("Only letters, dots, or hyphens (max 10).");
            return;
        }
        if (items.includes(symbol)) {
            setError("That ticker is already in your watchlist.");
            return;
        }
        if (items.length >= 50) {
            setError("You've reached the 50 ticker limit.");
            return;
        }
        
        // Updates local state and localStorage
        const next = [...items, symbol].sort();
        setItems(next);
        saveWatchlist(next);

        // Reset form + clear errors
        setInput("");
        setError("");

        // syncAdd(symbol).catch((err) => console.error(err));
        try { await syncAdd(symbol); } catch (err) { console.error(err); }
        await fetchQuotesFor(next);
    }

    // Remove single ticker
    async function handleRemove(symbol) {
        const next = items.filter((t) => t !== symbol);
        setItems(next);
        saveWatchlist(next);
        // syncRemove(symbol).catch((err) => console.error(err));
        try { await syncRemove(symbol); } catch (err) { console.error(err); }
        await fetchQuotesFor(next);
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
    }

    return (
        <div className="watchlist-container">
            <h1 className="watchlist-title">Your Watchlist</h1>

            <form className="watchlist-form" onSubmit={handleAdd}>
                <input 
                    aria-label="Add ticker"
                    className="watchlist-input"
                    placeholder="e.g. AAPL"
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    maxLength={12}    
                />
                <button className="watchlist-add" disabled={isDisabled} type="submit">
                    Add
                </button>
            </form>

            {error ? <div className="watchlist-error">{error}</div> : null}

            <div className="watchlist-meta">
                <span>{count} {count === 1 ? "ticker" : "tickers"}</span>
                {count > 0 && (
                    <button className="watchlist-clear" onClick={handleClearAll}>
                        Clear All
                    </button>
                )}
            </div>

            <ul className="watchlist-items">
            {items.map((t) => {
                const q = quotes.find((x) => x.ticker === t) || {};

                const score = q.sentiment_score;              // number, -1 to 1
                const label = q.sentiment_label || null;      // "Bullish", "Bearish", etc.
                const errorMsg = q.error;

                const sentimentLabel = label || (errorMsg ? "Error" : "—");
                const sentimentPct =
                typeof score === "number" ? `${(score * 100).toFixed(1)}%` : "—";

                // Determine CSS class based on sentiment label
                const sentimentClass =
                label === "Bullish" || label === "Somewhat-Bullish"
                    ? "up"
                    : label === "Bearish" || label === "Somewhat-Bearish"
                    ? "down"
                    : "";

                return (
                <li key={t} className="watchlist-item">
                    <span className="ticker">{t}</span>

                    <div className="watchlist-values">
                    {/* Left column: sentiment label */}
                    <span className="price">
                        {sentimentLabel}
                    </span>

                    {/* Right column: sentiment score as % */}
                    <span className={`pct ${sentimentClass}`}>
                        {errorMsg ? "—" : sentimentPct}
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

