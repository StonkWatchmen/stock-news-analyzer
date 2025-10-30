import {useEffect, useMemo, useState} from "react";
import {getWatchlist, saveWatchlist } from "../utils/storage";

const TICKER_REGEX = /^[A-Z.-]{1,10}$/;    // Allows patterns like BRK.B, RDS.A, etc.

export default function Watchlist() {
    // Track ticker list, input value, and user error message. 
    const [items, setItems] = useState([]);
    const [input, setInput] = useState("");
    const [error, setError] = useState("");

    // On load -> fetch saved watchlist from localStorage
    useEffect(() => {
        setItems(getWatchlist());
    }, []);

    const count = items.length;

    // Disable "Add" button if input is empty or whitespace
    const isDisabled = useMemo(() => !input.trim(), [input]);

    // Keep tickers consistent: trim whitespace and uppercase
    function normalizeTicker(ticker) {
        return ticker.trim().toUpperCase();
    }
    
    function handleAdd(e) {
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
    }

    // Remove single ticker
    function handleRemove(symbol) {
        const next = items.filter((t) => t !== symbol);
        setItems(next);
        saveWatchlist(next);
    }

    // Clear all tickers (with confirmation)
    function handleClearAll() {
        if (!window.confirm("Clear all tickers from your watchlist?")) {
            return;
        }
        setItems([]);
        saveWatchlist([]);
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
                {items.map((t) => (
                    <li key={t} className="watchlist-item">
                        <span className="ticker">{t}</span>
                        <button
                            className="remove-btn"
                            onClick={() => handleRemove(t)}
                            title="Remove this ticker"
                        >
                            x
                        </button>
                    </li>
                ))}
            </ul> 
        </div>
    );
}

