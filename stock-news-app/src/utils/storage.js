const KEY =  "watchlist:v1";

export function getWatchlist() {
    try {
        const raw = localStorage.getItem(KEY);
        return raw ? JSON.parse(raw) : [];
    } catch {
        return [];
    }
}

export function saveWatchlist(items) {
    try {
        localStorage.setItem(KEY, JSON.stringify(items));
    } catch {}    
} 
