import { useState } from 'react';

export default function ApiGatewayCaller() {
    const [loading, setLoading] = useState(false);

    // API endpoint injected at build time from environment variable
    const API_ENDPOINT = process.env.REACT_APP_API_BASE_URL

    const callApi = async () => {
        setLoading(true);

        try {
            const res = await fetch(`${API_ENDPOINT}/notify`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: 'Hello from React!'
                })
            });

            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`);
            }

            const data = await res.json();
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', alignItems: 'flex-end' }}>
            <button
                onClick={callApi}
                disabled={loading}
                style={{
                    padding: '10px 20px',
                    borderRadius: '6px',
                    border: '1px solid var(--accent)',
                    background: loading ? 'var(--surface-hover)' : 'var(--accent)',
                    color: '#fff',
                    fontWeight: '600',
                    fontSize: '14px',
                    cursor: loading ? 'not-allowed' : 'pointer',
                    opacity: loading ? 0.7 : 1,
                    transition: 'all 0.2s'
                }}
            >
                {loading ? 'Sending...' : 'Send Notification'}
            </button>
        </div>
    );
}