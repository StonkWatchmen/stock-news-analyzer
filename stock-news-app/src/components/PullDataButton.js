import { useState } from 'react';

export default function PullDownCaller() {
    const [loading, setLoading] = useState(false);
    const [response, setResponse] = useState(null);
    const [error, setError] = useState(null);

    // API endpoint injected at build time from environment variable
    const API_ENDPOINT = process.env.REACT_APP_API_BASE_URL

    const callApi = async () => {
        setLoading(true);
        setError(null);
        setResponse(null);

        try {
            const res = await fetch(`${API_ENDPOINT}/pulldown`, {
                method: 'GET',
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
            setResponse(data);
        } catch (err) {
            setError(err.message);
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

            {response && (
                <div style={{
                    padding: '12px',
                    background: 'var(--surface-hover)',
                    border: '1px solid var(--border)',
                    borderRadius: '6px',
                    fontSize: '12px',
                    maxWidth: '300px',
                    wordBreak: 'break-word'
                }}>
                    <strong>Response:</strong>
                    <pre style={{ margin: '8px 0 0 0', fontSize: '11px', color: 'var(--muted)' }}>
                        {JSON.stringify(response, null, 2)}
                    </pre>
                </div>
            )}

            {error && (
                <div style={{
                    padding: '12px',
                    background: 'rgba(248, 81, 73, 0.1)',
                    border: '1px solid var(--danger)',
                    borderRadius: '6px',
                    fontSize: '12px',
                    color: 'var(--danger)',
                    maxWidth: '300px',
                    wordBreak: 'break-word'
                }}>
                    <strong>Error:</strong>
                    <p style={{ margin: '8px 0 0 0' }}>{error}</p>
                </div>
            )}
        </div>
    );
}