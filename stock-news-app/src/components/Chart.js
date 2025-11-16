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


export default function Chart() {
  const [data, setData] = useState([]);

  useEffect(() => {
    async function load() {
      if (!API_BASE) {
        console.error("Missing REACT_APP_API_BASE");
        return;
      }

      try {
        // For now, just pull AAPL sentiment.
  
        const res = await fetch(`${API_BASE}/quotes?tickers=AAPL`);
        const json = await res.json();
        const quotes = json.quotes || [];

        const chartData = quotes.map((q) => ({
          // x-axis label; 
          date: q.ticker,
          // y-axis value from Lambda's sentiment_score
          sentiment:
            typeof q.sentiment_score === "number" ? q.sentiment_score : 0,
        }));

        setData(chartData);
      } catch (err) {
        console.error("Failed to load sentiment", err);
      }
    }

    load();
  }, []);
  return (
    <div className="chart-container">
      <h2 className="chart-title">Stock Sentiment Over Time</h2>
      <div className="chart-wrapper">
        <ResponsiveContainer width="100%" height={350}>
          <AreaChart data={data} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
            <defs>
              <linearGradient id="sentimentGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--accent)" stopOpacity={0.5} />
                <stop offset="100%" stopColor="var(--accent)" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis dataKey="date" stroke="var(--muted)" tick={{ fontSize: 12 }} />
            <YAxis
              domain={[-1, 1]}
              stroke="var(--muted)"
              tick={{ fontSize: 12 }}
              tickFormatter={(v) => `${v.toFixed(1)}`}
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
              formatter={(value) => [`Sentiment: ${value.toFixed(2)}`, ""]}
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
    </div>
  );
}
