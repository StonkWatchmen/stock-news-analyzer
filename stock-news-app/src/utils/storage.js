const KEY =  "watchlist:v1";    // Storage key for future migrations
export function getWatchlist() { /* ... */ }
export function saveWatchlist(list) { /* ... */ }
export function getWatchlist() {
    try {
        const raw = localStorage.getItem(KEY);
        return raw ? JSON.parse(raw) : [];
    } catch {
        // Silently ignore parse errors
        return [];
    }
}

export function saveWatchlist(items) {
    try {
        localStorage.setItem(KEY, JSON.stringify(items));
    } catch {
        // Ignore if storage quota exceeded or unavailable
    }    
} 
