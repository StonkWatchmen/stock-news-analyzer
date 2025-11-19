import React, { useEffect, useState } from "react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import "./Chart.css";

const API_BASE = process.env.REACT_APP_API_BASE_URL;

export default function Chart() {
  const [data, setData] = useState([]);
  const [ticker, setTicker] = useState("AAPL");
  const [timeRange, setTimeRange] = useState("7d");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadStockHistory() {
      if (!API_BASE) return;

      setLoading(true);
      setError(null);

      try {
        const res = await fetch(`${API_BASE}/stock-history?ticker=${ticker}&range=${timeRange}`);
        if (!res.ok) throw new Error(`API error: ${res.status}`);
        const json = await res.json();
        const history = json.history || [];

        const chartData = history.map((record) => {
          const recordDate = new Date(record.recorded_at);
          let dateLabel;
          if (timeRange === '24h') {
            dateLabel = recordDate.toLocaleString("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
          } else if (timeRange === '7d' || timeRange === '30d' || timeRange === '90d') {
            dateLabel = recordDate.toLocaleDateString("en-US", { month: "short", day: "numeric" });
          } else {
            dateLabel = recordDate.toLocaleDateString("en-US", { month: "short", year: "numeric" });
          }

          return {
            date: dateLabel,
            price: parseFloat(record.price) || 0,
            sentiment: record.avg_sentiment !== null ? parseFloat(record.avg_sentiment) : null,
            timestamp: record.recorded_at,
          };
        });

        setData(chartData.filter(d => new Date(d.timestamp) <= new Date()));
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    loadStockHistory();
  }, [ticker, timeRange]);

  const validSentimentData = data.filter(d => d.sentiment !== null);
  const latestSentiment = validSentimentData[validSentimentData.length - 1]?.sentiment ?? 0;
  const avgSentiment = validSentimentData.length
    ? validSentimentData.reduce((sum, d) => sum + d.sentiment, 0) / validSentimentData.length
    : 0;

  return (
    <div className="chart-container">
      <div className="chart-header">
        <h2>Stock Sentiment & Price Analysis</h2>
        <div className="chart-controls">
          <div className="control-group">
            <label htmlFor="ticker-select">Stock:</label>
            <select id="ticker-select" value={ticker} onChange={(e) => setTicker(e.target.value)}>
              {["AAPL","NFLX","AMZN","NVDA","META","MSFT","AMD"].map(t => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>
          <div className="control-group">
            <label htmlFor="range-select">Time Range:</label>
            <select id="range-select" value={timeRange} onChange={(e) => setTimeRange(e.target.value)}>
              <option value="24h">Last 24 Hours</option>
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
              <option value="90d">Last 90 Days</option>
              <option value="1y">Last Year</option>
              <option value="all">All Time</option>
            </select>
          </div>
        </div>
      </div>

      {error && <div className="chart-error">Error loading data: {error}</div>}
      {loading && <div className="chart-loading">Loading stock data...</div>}
      {!loading && !error && data.length === 0 && <div>No data available for {ticker}</div>}

      {!loading && !error && data.length > 0 && (
        <>
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={data}>
              <defs>
                <linearGradient id="sentimentGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#ff9900" stopOpacity={0.5} />
                  <stop offset="100%" stopColor="#ff9900" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" angle={-45} textAnchor="end" />
              <YAxis domain={[-1, 1]} />
              <Tooltip formatter={v => [`Sentiment: ${v?.toFixed(3)}`, ""]} />
              <Area type="monotone" dataKey="sentiment" stroke="#ff9900" fill="url(#sentimentGradient)" />
            </AreaChart>
          </ResponsiveContainer>

          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={data}>
              <defs>
                <linearGradient id="priceGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#10b981" stopOpacity={0.5} />
                  <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" angle={-45} textAnchor="end" />
              <YAxis tickFormatter={v => `$${v?.toFixed(2)}`} />
              <Tooltip formatter={v => [`Price: $${v?.toFixed(2)}`, ""]} />
              <Area type="monotone" dataKey="price" stroke="#10b981" fill="url(#priceGradient)" />
            </AreaChart>
          </ResponsiveContainer>
        </>
      )}

      {data.length > 0 && (
        <div className="chart-stats">
          <div>Data Points: {data.length}</div>
          <div>Latest Price: ${data[data.length - 1]?.price.toFixed(2)}</div>
          <div>Latest Sentiment: {latestSentiment.toFixed(3)}</div>
          <div>Avg Sentiment: {avgSentiment.toFixed(3)}</div>
        </div>
      )}
    </div>
  );
}
