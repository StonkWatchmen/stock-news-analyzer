DROP TABLE IF EXISTS article_history;
DROP TABLE IF EXISTS stock_history;
DROP TABLE IF EXISTS watchlist;
DROP TABLE IF EXISTS prices;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS stocks;

CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY NOT NULL,
    email VARCHAR(64) NOT NULL,
    password VARCHAR(64) DEFAULT NULL,
    watchlist JSON DEFAULT '[]'
);

CREATE TABLE stocks (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    ticker VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE prices (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    stock_id INT NOT NULL,
    price DECIMAL(10, 2),
    change_pct DECIMAL(5, 2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(id),
    UNIQUE KEY unique_stock_price (stock_id)
);

-- Article history: individual articles with sentiment and keywords
CREATE TABLE article_history (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    stock_id INT NOT NULL,
    title VARCHAR(500) NOT NULL,
    keywords TEXT,
    sentiment_score DECIMAL(10, 6),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(id)
);

-- Stock history: price and average sentiment at a point in time
CREATE TABLE stock_history (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    stock_id INT NOT NULL,
    price DECIMAL(10, 2),
    avg_sentiment DECIMAL(10, 6),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(id)
);