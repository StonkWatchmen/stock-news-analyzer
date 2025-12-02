DROP TABLE IF EXISTS article_history;
DROP TABLE IF EXISTS stock_history;
DROP TABLE IF EXISTS watchlist;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS stocks;

CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY NOT NULL,  -- Changed to VARCHAR to store Cognito sub (UUID)
    email VARCHAR(64) NOT NULL UNIQUE      -- Added UNIQUE constraint
);

CREATE TABLE stocks (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    ticker VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE watchlist (
    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    user_id VARCHAR(255) NOT NULL,  -- Changed to VARCHAR to match users.id
    stock_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (stock_id) REFERENCES stocks(id),
    UNIQUE KEY unique_user_stock (user_id, stock_id)
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