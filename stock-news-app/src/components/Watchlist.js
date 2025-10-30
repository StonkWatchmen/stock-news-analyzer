import React, {useEffect, useMemo, useState} from "react";
import {getWatchlist, saveWatchlist } from "../utils/storage";

const TICKER_REGEX = /^[A-Z.\-]{1,10}$/;

export default function Watchlist() {
    const [items, setItems] = useState([]);
    const [input, setInput] = useState("");
    const [error, setError] = useState("");

    useEffect(() => {
        setItems(getWatchlist());
    }, []);

    const count = items.length;
    const isDisabled = useMemo(() => !input.trim(), [input]);

    function normalizeTicker(ticker) {
        return ticker.trim().toUpperCase();
    }
    
    function handleAdd(e) {
        e.preventDefault();

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
        
        const next = [...items, symbol].sort();
        setItems(next);
        saveWatchlist(next);
        setInput("");
        setError("");
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
            </div>

            <ul className="watchlist-items">
                {items.map((t) => (
                    <li key={t} className="watchlist-item">
                        <span className="ticker">{t}</span>
                    </li>
                ))}
            </ul> 
        </div>
    );
}

