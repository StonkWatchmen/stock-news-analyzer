import { useState } from 'react';

export default function ApiGatewayCaller() {
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
            setResponse(data);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div>
            <button
                onClick={callApi}
                disabled={loading}
            >
                Send Notification
            </button>

            {response && (
                <div>
                    <h2>
                        Response:
                    </h2>
                    <pre>
                        {JSON.stringify(response, null, 2)}
                    </pre>
                </div>
            )}

            {error && (
                <div>
                    <h2>
                        Error:
                    </h2>
                    <p>{error}</p>
                </div>
            )}
        </div>
    );
}