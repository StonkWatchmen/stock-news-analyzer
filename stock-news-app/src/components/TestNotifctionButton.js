import { useState } from 'react';
import { Loader2 } from 'lucide-react';

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
        <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
            <div className="max-w-2xl mx-auto">
                <div className="bg-white rounded-lg shadow-lg p-8">
                    <h1 className="text-3xl font-bold text-gray-800 mb-6">
                        AWS API Gateway Caller
                    </h1>

                    <button
                        onClick={callApi}
                        disabled={loading}
                        className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:bg-gray-400 text-white font-semibold py-3 px-6 rounded-lg transition-colors duration-200 flex items-center justify-center gap-2"
                    >
                        {loading ? (
                            <>
                                <Loader2 className="animate-spin" size={20} />
                                Calling API...
                            </>
                        ) : (
                            'Call API Endpoint'
                        )}
                    </button>

                    {response && (
                        <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
                            <h2 className="text-lg font-semibold text-green-800 mb-2">
                                Response:
                            </h2>
                            <pre className="text-sm text-gray-700 overflow-auto">
                                {JSON.stringify(response, null, 2)}
                            </pre>
                        </div>
                    )}

                    {error && (
                        <div className="mt-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                            <h2 className="text-lg font-semibold text-red-800 mb-2">
                                Error:
                            </h2>
                            <p className="text-sm text-red-700">{error}</p>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}