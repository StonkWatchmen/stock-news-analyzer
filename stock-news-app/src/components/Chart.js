import React, { useEffect, useState } from "react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
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
      if (!API_BASE) {
        console.error("Missing REACT_APP_API_BASE_URL");
        return;
      }

      setLoading(true);
      setError(null);

      try {
        const res = await fetch(
          `${API_BASE}/stock-history?ticker=${ticker}&range=${timeRange}`
        );
        
        if (!res.ok) {
          throw new Error(`API error: ${res.status}`);
        }

        const json = await res.json();
        const history = json.history || [];

        // Transform data for the chart
        const chartData = history.map((record) => ({
          // Format date for display
          date: new Date(record.recorded_at).toLocaleString("en-US", {
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          }),
          // Price data
          price: parseFloat(record.price) || 0,
          // Sentiment data (scale -1 to 1)
          sentiment: parseFloat(record.avg_sentiment) || 0,
          // Keep timestamp for tooltip
          timestamp: record.recorded_at,
        }));

        setData(chartData);
      } catch (err) {
        console.error("Failed to load stock history:", err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    loadStockHistory();
  }, [ticker, timeRange]);

  return (
    <div className="chart-container">
      <div className="chart-header">
        <h2 className="chart-title">Stock Sentiment & Price Analysis</h2>
        
        <div className="chart-controls">
          {/* Stock Ticker Selector */}
          <div className="control-group">
            <label htmlFor="ticker-select">Stock:</label>
            <select
              id="ticker-select"
              value={ticker}
              onChange={(e) => setTicker(e.target.value)}
              className="select-input"
            >
              <option value="AAPL">Apple (AAPL)</option>
              <option value="MSFT">Microsoft (MSFT)</option>
              <option value="GOOGL">Google (GOOGL)</option>
              <option value="AMZN">Amazon (AMZN)</option>
              <option value="TSLA">Tesla (TSLA)</option>
              <option value="META">Meta (META)</option>
              <option value="NVDA">NVIDIA (NVDA)</option>
            </select>
          </div>

          {/* Time Range Selector */}
          <div className="control-group">
            <label htmlFor="range-select">Time Range:</label>
            <select
              id="range-select"
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value)}
              className="select-input"
            >
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

      {error && (
        <div className="chart-error">
          Error loading data: {error}
        </div>
      )}

      {loading && (
        <div className="chart-loading">
          Loading stock data...
        </div>
      )}

      {!loading && !error && data.length === 0 && (
        <div className="chart-empty">
          No data available for {ticker} in this time range.
        </div>
      )}

      {!loading && !error && data.length > 0 && (
        <div className="chart-wrapper">
          {/* Sentiment Chart */}
          <div className="chart-section">
            <h3 className="chart-subtitle">Sentiment Score</h3>
            <ResponsiveContainer width="100%" height={250}>
              <AreaChart data={data} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
                <defs>
                  <linearGradient id="sentimentGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--accent)" stopOpacity={0.5} />
                    <stop offset="100%" stopColor="var(--accent)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis 
                  dataKey="date" 
                  stroke="var(--muted)" 
                  tick={{ fontSize: 11 }}
                  angle={-45}
                  textAnchor="end"
                  height={80}
                />
                <YAxis
                  domain={[-1, 1]}
                  stroke="var(--muted)"
                  tick={{ fontSize: 12 }}
                  tickFormatter={(v) => v.toFixed(1)}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "var(--surface-hover)",
                    border: "1px solid var(--border)",
                    borderRadius: "8px",
                    color: "var(--text)",
                    fontSize: "14px",
                  }}
                  labelStyle={{ color: "var(--muted)" }}
                  formatter={(value) => [
                    `Sentiment: ${value.toFixed(3)}`,
                    ""
                  ]}
                />
                <Area
                  type="monotone"
                  dataKey="sentiment"
                  stroke="var(--accent)"
                  fill="url(#sentimentGradient)"
                  strokeWidth={2}
                  dot={{ r: 2 }}
                  activeDot={{ r: 5 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          {/* Price Chart */}
          <div className="chart-section">
            <h3 className="chart-subtitle">Stock Price ($)</h3>
            <ResponsiveContainer width="100%" height={250}>
              <AreaChart data={data} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
                <defs>
                  <linearGradient id="priceGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#10b981" stopOpacity={0.5} />
                    <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis 
                  dataKey="date" 
                  stroke="var(--muted)" 
                  tick={{ fontSize: 11 }}
                  angle={-45}
                  textAnchor="end"
                  height={80}
                />
                <YAxis
                  stroke="var(--muted)"
                  tick={{ fontSize: 12 }}
                  tickFormatter={(v) => `$${v.toFixed(2)}`}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "var(--surface-hover)",
                    border: "1px solid var(--border)",
                    borderRadius: "8px",
                    color: "var(--text)",
                    fontSize: "14px",
                  }}
                  labelStyle={{ color: "var(--muted)" }}
                  formatter={(value) => [
                    `Price: $${value.toFixed(2)}`,
                    ""
                  ]}
                />
                <Area
                  type="monotone"
                  dataKey="price"
                  stroke="#10b981"
                  fill="url(#priceGradient)"
                  strokeWidth={2}
                  dot={{ r: 2 }}
                  activeDot={{ r: 5 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          {/* Stats Summary */}
          <div className="chart-stats">
            <div className="stat-card">
              <span className="stat-label">Data Points</span>
              <span className="stat-value">{data.length}</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">Latest Price</span>
              <span className="stat-value">
                ${data[data.length - 1]?.price.toFixed(2)}
              </span>
            </div>
            <div className="stat-card">
              <span className="stat-label">Latest Sentiment</span>
              <span className="stat-value">
                {data[data.length - 1]?.sentiment.toFixed(3)}
              </span>
            </div>
            <div className="stat-card">
              <span className="stat-label">Avg Sentiment</span>
              <span className="stat-value">
                {(
                  data.reduce((sum, d) => sum + d.sentiment, 0) / data.length
                ).toFixed(3)}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}