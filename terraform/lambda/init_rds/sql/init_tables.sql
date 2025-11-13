DROP TABLE IF EXISTS watchlist;
    DROP TABLE IF EXISTS users;
    DROP TABLE IF EXISTS stocks;
    DROP TABLE IF EXISTS prices;

    CREATE TABLE users (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
        email VARCHAR(64) NOT NULL,
        password VARCHAR(64) NOT NULL
    );

    CREATE TABLE stocks (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        ticker VARCHAR(5) NOT NULL
    );

    CREATE TABLE watchlist (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        user_id INTEGER NOT NULL,
        stock_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
    );

    CREATE TABLE prices (
      id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
      stock_id INT NOT NULL,
      price DECIMAL(12,4),
      change_pct DECIMAL(6,2),
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (stock_id) REFERENCES stocks(id)
    );